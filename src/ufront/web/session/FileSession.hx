package ufront.web.session;

import haxe.io.Path;
import ufront.core.InjectionRef;
import ufront.web.context.HttpContext;
import ufront.web.HttpCookie;
import ufront.web.session.UFHttpSession;
import thx.core.error.NotImplemented;
import haxe.ds.StringMap;
import haxe.Serializer;
import haxe.Unserializer;
import thx.core.error.NullArgument;
import tink.CoreApi;
#if sys
	import sys.FileSystem;
	import sys.io.File;
	import ufront.sys.SysUtil;
#end
using StringTools;
using haxe.io.Path;

/**
	A session implementation using flat files.

	Files are saved to the folder `savePath`, with one file per session.  The folder must be writeable by the web server.

	Each session has a unique ID, which is randomly generated and used as the file.

	The contents of the file are a serialized StringMap representing the current session.  The serialization is done using `haxe.Serializer` and `haxe.Unserializer`.

	The session ID is sent to the client as a Cookie.  When reading the SessionID, Cookies are checked first, followed by GET/POST parameters.

	When searching the parameters or cookies for the Session ID, the name to search for is defined by the `sessionName` property.
**/
class FileSession implements UFHttpSession
{
	// Statics

	/**
		The default session name to use if none is provided.
		The default value is "UfrontSessionID".
		You can change this static variable to set a new default.
	**/
	public static var defaultSessionName:String = "UfrontSessionID";

	/**
		The default savePath.
		This should be relative to the `HttpContext.contentDirectory`, or absolute.
		The default value is "sessions/".  You can change this static value to set a new default.
	**/
	public static var defaultSavePath:String = "sessions/";

	/**
		The default expiry value.
		The default value is 0 (expire when window is closed).
		You can change the default by changing this static variable.
	**/
	public static var defaultExpiry:Int = 0;

	// Private variables

	var started:Bool;
	var commitFlag:Bool;
	var closeFlag:Bool;
	var regenerateFlag:Bool;
	var expiryFlag:Bool;
	var sessionID:String;
	var sessionData:StringMap<Dynamic>;

	// Public members

	/**
	The current session ID.
	If not set, it will be read from the cookies, or failing that, the request parameters.
	This cannot be set manually, please see `regenerateID` for a way to change the session ID.
	**/
	public var id(get,never):Null<String>;

	/** The current HttpContext, should be supplied by injection. **/
	@inject public var context:HttpContext;

	/**
		Construct a new session object.

		This does not create the session file or commit any data, rather, it sets up the object so that read or writes can then happen.

		Data is read during `init` and written during `commit`.

		A new session object should be created for each request, and it will then associate itself with the correct session file for the given user.

		In general you should create your object using `injector.instantiate( FileSession )`, so that the HttpContext is made available and various the `injectConfig` initializations take place.
	**/
	public function new() {
		started = false;
		commitFlag = false;
		closeFlag = false;
		regenerateFlag = false;
		expiryFlag = false;
		sessionData = null;
		sessionID = null;
	}

	/**
		Use the current injector to check for configuration for this session: sessionName, expiry and savePath.
		If no values are available in the injector, the defaults will be used.
		This will be called automatically after `context` has been injected.
	**/
	@post public function injectConfig() {
		// Manually check for these injections, because if they're not provided we have defaults - we don't want minject to throw an error.
		this.sessionName =
			if ( context.injector.hasMapping(String,"sessionName") )
				context.injector.getInstance( String, "sessionName" )
			else defaultSessionName;
		this.expiry =
			if ( context.injector.hasMapping(InjectionRef,"sessionExpiry") )
				context.injector.getInstance( InjectionRef, "sessionExpiry" ).get()
			else defaultExpiry;
		this.savePath =
			if ( context.injector.hasMapping(String,"sessionSavePath") )
				context.injector.getInstance( String, "sessionSavePath" )
			else defaultSavePath;

		// Sanitize the savePath, make it absolute if it was specified relative to the content directory.
		savePath = Path.addTrailingSlash( savePath );
		if ( !savePath.startsWith("/") )
			savePath = context.contentDirectory + savePath;
	}

	/**
		The variable name to reference the session ID.

		This will be the name set in the Cookie sent to the client, or the name to search for in the parameters or cookies.

		This is set by injecting a String named "sessionName", otherwise the default `defaultSessionName` value is used.
	**/
	public var sessionName(default,null):String;

	/**
		The lifetime/expiry of the cookie, in seconds.

		- A positive value sets the cookie to expire that many seconds from the current time.
		- A value of 0 represents expiry when the browser window is closed.
		- A negative value expires the cookie immediately.

		This is set by injecting a `InjectionRef<Int> named "sessionExpiry", otherwise the default `defaultExpiry` value is used.
	**/
	public var expiry(default,null):Null<Int>;

	/**
		The save path for the session files.

		This should be absolute, or relative to the `HttpContext.contentDirectory`

		Relative paths should not have a leading slash.
		If a trailing slash is not included, it will be added.

		This is set by injecting a String named "sessionSavePath", otherwise the default `defaultSavePath` value is used.
	**/
	public var savePath(default,null):String;

	/**
		Set the number of seconds the session should last

		Note in this implementation only the cookie expiry is affected - the user could manually override this or send the session variable in the request parameters, and the session would still work.
	**/
	public function setExpiry( e:Int ) {
		expiry = e;
	}

	/**
		Initiate the session.

		This will check for an existing session ID.  If one exists, it will read and unserialize the session data from that session's file.

		If a session does not exist, one will be created.

		This is called before any other operations which require access to the current session.
	**/
	public function init():Surprise<Noise,Error> {
		var t = Future.trigger();
		#if sys
			if ( !started ) {
				try {
					SysUtil.mkdir( savePath.removeTrailingSlashes() );

					var file : String;
					var fileData : String;

					// Try to restore an existing session
					get_id();
					if ( sessionID!=null ) {
						testValidId( id );
						file = getSessionFilePath( id );
						if ( !FileSystem.exists(file) ) {
							sessionID = null;
						}
						else {
							fileData = try File.getContent( file ) catch ( e:Dynamic ) null;
							if ( fileData!=null ) {
								try
									sessionData = cast( Unserializer.run(fileData), StringMap<Dynamic> )
								catch ( e:Dynamic ) {
									context.ufWarn('Failed to unserialize session data, resetting session: $e');
									fileData = null; // invalid data
								}
							}
							if ( fileData==null ) {
								// delete file and start new session
								sessionID = null;
								try FileSystem.deleteFile( file ) catch( e:Dynamic ) {};
							}
						}
					}

					// No session existed, or it was invalid - start a new one
					if( sessionID==null ) {
						sessionData = new StringMap<Dynamic>();
						sessionID = reserveNewSessionID();
						setCookie( sessionID, expiry );
					}
					started = true;
					t.trigger( Success(Noise) );
				}
				catch( e:Dynamic ) t.trigger( Failure(new Error('Unable to save session: $e')) );
			}
			else t.trigger( Success(Noise) );

		#else
			t.trigger( Failure(new Error('FileSession not implemented on this platform.')) );
		#end
		return t.asFuture();
	}

	#if sys
		function reserveNewSessionID():String {
			var tryID = null;
			var file:String;
			do {
				tryID = generateSessionID();
				file = savePath + tryID + ".sess";
			} while( FileSystem.exists(file) );
			// Create the file so no one else takes it
			File.saveContent( file, "" );

			return tryID;
		}
	#end

	function setCookie( id:String, expiryLength:Int ) {
		var expireAt = ( expiryLength<=0 ) ? null : DateTools.delta( Date.now(), 1000.0*expiryLength );
		var path = '/'; // TODO: Set cookie path to application path, right now it's global.
		var domain = null;
		var secure = false;

		var sessionCookie = new HttpCookie( sessionName, id, expireAt, domain, path, secure );
		if ( expiryLength<0 )
			sessionCookie.expireNow();
		context.response.setCookie( sessionCookie );
	}

	/**
		Commit if required.

		Returns an Outcome, which is a Failure if the commit failed, usually because of not having permission to write to disk.
	**/
	public function commit():Surprise<Noise,Error> {
		var t = Future.trigger();
		#if sys
			var handled = false;

			try {
				if ( regenerateFlag ) {
					handled = true;
					var oldSessionID = sessionID;
					sessionID = reserveNewSessionID();
					FileSystem.rename( getSessionFilePath(oldSessionID), getSessionFilePath(sessionID) );
					setCookie( sessionID, expiry );
					t.trigger( Success(Noise) );
				}
				if ( commitFlag && sessionData!=null ) {
					handled = true;
					var filePath = getSessionFilePath(sessionID);
					var content = Serializer.run(sessionData);
					File.saveContent(filePath, content);
					t.trigger( Success(Noise) );
				}
				if ( closeFlag ) {
					handled = true;
					// Because Date.now() on the server is in local time, but the cookie header is in GMT,
					setCookie( "", -1 );
					FileSystem.deleteFile( getSessionFilePath(sessionID) );
					t.trigger( Success(Noise) );
				}
				if ( expiryFlag ) {
					handled = true;
					setCookie( sessionID, expiry );
					t.trigger( Success(Noise) );
				}
				if ( !handled ) t.trigger( Success(Noise) );
			}
			catch( e:Dynamic ) t.trigger( Failure(new Error('Unable to save session: $e')) );
		#else
			t.trigger( Failure(new Error('FileSession not implemented on this platform.')) );
		#end
		return t.asFuture();
	}

	/**
		Retrieve an item from the session data
	**/
	public inline function get( name:String ):Dynamic {
		checkStarted();
		return sessionData!=null ? sessionData.get( name ) : null;
	}

	/**
		Set an item in the session data.
		Note this will not commit the value to a file until `this.commit()` is called (generally at the end of a request).
		This will throw an error if `init()` has not already been called.
	**/
	public inline function set( name:String, value:Dynamic ):Void {
		checkStarted();
		if ( sessionData!=null ) {
			sessionData.set( name, value );
			commitFlag = true;
		}
	}

	/**
		Check if a session has the specified item.
		This will throw an error if `init()` has not already been called.
	**/
	public inline function exists( name:String ):Bool {
		checkStarted();
		return sessionData!=null && sessionData.exists( name );
	}

	/**
		Remove an item from the session.
		Note this will not commit the value to a file until `this.commit()` is called (generally at the end of a request).
		This will throw an error if `init()` has not already been called.
	**/
	public inline function remove( name:String ):Void {
		checkStarted();
		if ( sessionData!=null ) {
			sessionData.remove(name);
			commitFlag = true;
		}
	}

	/**
		Empty all items from the current session data without closing the session.
	**/
	public inline function clear():Void {
		if ( sessionData!=null && isActive() ) {
			sessionData = new StringMap<Dynamic>();
			commitFlag = true;
		}
	}

	/**
		Force the session to be committed at the end of this request
	**/
	public inline function triggerCommit():Void {
		commitFlag = true;
	}

	/**
		Trigger a regeneration of the session ID when `commit` is called.
	**/
	public function regenerateID():Void {
		regenerateFlag = true;
	}

	/**
		Whether or not the current session is active.

		This is determined by if a sessionID exists, which will happen if init() has been called or if a SessionID was provided in the request context (via Cookie or GET/POST parameter etc).

	**/
	public inline function isActive():Bool {
		return started && get_id()!=null;
	}

	/**
		Return the current ID
	**/
	function get_id():String {
		if ( sessionID==null ) sessionID = context.request.cookies[sessionName];
		if ( sessionID==null ) sessionID = context.request.params[sessionName];
		return sessionID;
	}

	/**
		Close the session.

		The sessionData and sessionID will be set to null, and the session will be flagged for deletion (when `commit` is called)
	**/
	public function close():Void {
		checkStarted();
		sessionData = null;
		closeFlag = true;
	}

	public function toString():String {
		return sessionData!=null ? sessionData.toString() : "{}";
	}

	// Private methods

	inline function getSessionFilePath( id:String ) {
		return '$savePath$id.sess';
	}

	inline function generateSessionID() {
		return Random.string(40);
	}

	inline function checkStarted() {
		if ( !started )
			throw "Trying to access session data before init() has been run";
	}

	static var validID = ~/^[a-zA-Z0-9]+$/;
	static inline function testValidId( id:String ):Void {
		if( id!=null )
			if(!validID.match(id))
				throw "Invalid session ID.";
	}
}
