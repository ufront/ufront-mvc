package ufront.web.session;

import haxe.io.Path;
import ufront.web.context.HttpContext;
import ufront.web.HttpCookie;
import ufront.web.session.UFHttpSession;
import haxe.ds.StringMap;
import haxe.Serializer;
import haxe.Unserializer;
import tink.CoreApi;
import ufront.web.HttpError;
import ufront.core.Uuid;
#if sys
	import sys.FileSystem;
	import sys.io.File;
#elseif nodejs
	import js.node.Fs;
#end
using ufront.core.AsyncTools;
using StringTools;
using haxe.io.Path;

/**
A session implementation using flat files.

Files are saved to the folder `savePath`, with one file per session.
The folder must be writeable by the web server.

Each session has a unique ID, which is randomly generated and used as the file name.

The contents of the file are a serialized `StringMap` representing the current session.
The serialization is done using `haxe.Serializer` and `haxe.Unserializer`.

The session ID is sent to the client as a `HttpCookie`.
When reading the session ID, `HttpRequest.cookies` is checked first, followed by `HttpRequest.params`.

When searching the parameters or cookies for the session ID, the name to search for is defined by the `this.sessionName` property.
**/
class FileSession implements UFHttpSession {
	// Statics

	/**
	The default session name to use if none is provided.

	The default value is `UfrontSessionID`.
	You can change this static variable to set a new default.
	**/
	public static var defaultSessionName:String = "UfrontSessionID";

	/**
	The default savePath.

	This should be relative to the `HttpContext.contentDirectory`, or absolute.
	The default value is `sessions/`.
	You can change this static value to set a new default.
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
	It will be read from the cookies, or failing that, the request parameters.
	This cannot be set manually, please see `regenerateID` for a way to change the session ID.
	**/
	public var id(get,never):Null<String>;

	/** The current HttpContext, should be supplied by injection. **/
	@inject public var context:HttpContext;

	/**
	Construct a new session object.

	This does not create the session file or commit any data, rather, it sets up the object so that read or writes can then happen.

	Data is read during `this.init()` and written during `this.commit()`.

	A new session object should be created for each request, and it will then associate itself with the correct session file for the given user.

	In general you should create your object using dependency injections, so that everything is initialized correctly.
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
	Use the current injector to check for configuration for this session: `this.sessionName`, `this.expiry` and `this.savePath`.
	If no values are available in the injector, the defaults will be used.
	**/
	@inject public function injectConfig( context:HttpContext ) {
		this.sessionName =
			if ( context.injector.hasMapping(String,"sessionName") )
				context.injector.getValue( String, "sessionName" )
			else defaultSessionName;
		this.expiry =
			if ( context.injector.hasMapping(Int,"sessionExpiry") )
				context.injector.getValue( Int, "sessionExpiry" );
			else defaultExpiry;
		this.savePath =
			if ( context.injector.hasMapping(String,"sessionSavePath") )
				context.injector.getValue( String, "sessionSavePath" )
			else defaultSavePath;

		// Sanitize the savePath, make it absolute if it was specified relative to the content directory.
		savePath = Path.addTrailingSlash( savePath );
		if ( !savePath.startsWith("/") )
			savePath = context.contentDirectory + savePath;
	}

	/**
	The variable name to reference the session ID.

	This will be the name set in the cookie sent to the client, or the name to search for in the parameters or cookies.

	This is set by injecting a String named `sessionName`, otherwise the default `FileSession.defaultSessionName` value is used.
	**/
	public var sessionName(default,null):String;

	/**
	The lifetime/expiry of the cookie, in seconds.

	- A positive value sets the cookie to expire that many seconds from the current time.
	- A value of 0 represents expiry when the browser window is closed.
	- A negative value expires the cookie immediately.

	This is set by injecting an `Int` named `sessionExpiry`, otherwise the default `FileSession.defaultExpiry` value is used.
	**/
	public var expiry(default,null):Null<Int>;

	/**
	The save path for the session files.

	This should be absolute, or relative to the `HttpContext.contentDirectory`

	Relative paths should not have a leading slash.
	If a trailing slash is not included, it will be added.

	This is set by injecting a `String` named `sessionSavePath`, otherwise the default `FileSession.defaultSavePath` value is used.
	**/
	public var savePath(default,null):String;

	/**
	Set the number of seconds the session should last before expiring.

	Note in this implementation only the cookie expiry is affected - the file is not deleted from the server.
	The user could manually override this or send the session variable in the request parameters, and the session would still work.
	**/
	public function setExpiry( e:Int ) {
		expiry = e;
	}

	/**
	Initiate the session.

	This will check for an existing session ID.
	If one exists, it will read and unserialize the session data from that session's file.

	If a session does not exist, one will be created, including generating and reserving a new session ID.

	This must be called before any other operations which require access to the current session.
	**/
	public function init():Surprise<Noise,Error> {
		if ( !started ) {
			get_id();
			this.sessionData = new StringMap();

			return
				doCreateSessionDirectory() >>
				doReadSessionFile >>
				doUnserializeSessionData >>
				function(n:Noise) { this.started = true; return Noise; };
		}
		else return SurpriseTools.success();
	}

	function doCreateSessionDirectory():Surprise<Noise,Error> {
		var dir = savePath.removeTrailingSlashes();
		#if sys
			return SurpriseTools.tryCatchSurprise(function() {
				if ( FileSystem.exists(dir)==false ) {
					FileSystem.createDirectory( dir );
				}
				return Noise;
			}, 'Failed to create directory $dir');
		#elseif nodejs
			var t = Future.trigger();
			Fs.mkdir( savePath.removeTrailingSlashes(), function(err) {
				if ( err==null || (untyped err.code:String)=='EEXIST' ) {
					t.trigger( Success(Noise) );
				}
				else t.trigger( Failure(HttpError.internalServerError('Failed to create directory $dir',err)) );
			});
			return t.asFuture();
		#else
			return notImplemented();
		#end
	}

	function doReadSessionFile(_):Surprise<Null<String>,Error> {
		if ( testValidId(sessionID) ) {
			var filename = getSessionFilePath( this.sessionID );
			#if sys
				return
					try File.getContent( filename ).asGoodSurprise()
					catch ( e:Dynamic ) SurpriseTools.asGoodSurprise( null );
			#elseif nodejs
				return
					Fs.readFile.bind( filename, { encoding: "utf-8" } ).asSurprise().map(function(o) {
						return switch o {
							case Failure(_): Success(null);
							default: o;
						}
					});
			#else
				return notImplemented();
			#end
		}
		else {
			context.ufWarn( 'Session ID $sessionID was invalid, resetting session.' );
			sessionID = null;
			return SurpriseTools.asGoodSurprise( null );
		}
	}

	function doUnserializeSessionData( content:Null<String> ):Noise {
		if ( content!=null ) {
			try {
				sessionData = cast( Unserializer.run(content), StringMap<Dynamic> );
			} catch ( e:Dynamic ) {
				// If this fails, we'll give a warning but not trigger a failure.
				// This might happen if the session was from a previous compilation and one of the types serializes differently, etc.
				context.ufWarn( 'Failed to unserialize session data: $e' );
			}
		}
		return Noise;
	}

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

	Returns a `Surprise`, which is a Failure if the commit failed, usually because of not having permission to write to disk.
	**/
	public function commit():Surprise<Noise,Error> {
		// If no session ID has been set yet, make sure we set one during the process.
		if ( sessionID==null && sessionData!=null )
			this.regenerateID();

		return
			doRegenerateID() >>
			doSaveSessionContent >>
			doSetExpiry >>
			doCloseSession;
	}

	function doRegenerateID():Surprise<Noise,Error> {
		if ( regenerateFlag ) {
			var oldSessionID = sessionID;
			#if sys
				return SurpriseTools.tryCatchSurprise(function () {
					var file:String;
					do {
						sessionID = generateSessionID();
						file = getSessionFilePath( sessionID );
					} while( FileSystem.exists(file) );

					// Either rename the old file, or create a blank file, to make sure we reserve our name.
					setCookie( sessionID, expiry );
					if ( oldSessionID!=null )
						FileSystem.rename( getSessionFilePath(oldSessionID), file );
					else
						File.saveContent( file, "" );
					return Noise;
				});
			#elseif nodejs
				function tryNewID( cb:js.Error->Void ) {
					sessionID = generateSessionID();
					var file = getSessionFilePath( sessionID );
					Fs.exists( file, function(exists) {
						if ( exists==false ) {
							// Either rename the old file, or create a blank file, to make sure we reserve our name.
							if ( oldSessionID!=null )
								Fs.rename( getSessionFilePath(oldSessionID), file, cb );
							else
								Fs.writeFile( file, "", cb );
						}
						else tryNewID( cb );
					});
				}
				return tryNewID.asVoidSurprise();
			#else
				return notImplemented();
			#end
		}
		else return SurpriseTools.success();
	}

	function doSaveSessionContent(_:Noise):Surprise<Noise,Error> {
		if ( commitFlag && sessionData!=null ) {
			var filePath = getSessionFilePath( sessionID );
			var content:String;

			try
				content = Serializer.run(sessionData)
			catch ( e:Dynamic )
				return e.asSurpriseError( 'Failed to serialize session content' );

			#if sys
				return SurpriseTools.tryCatchSurprise(function() {
					File.saveContent( filePath, content );
					return Noise;
				});
			#elseif nodejs
				return Fs.writeFile.bind( filePath, content, {} ).asVoidSurprise();
			#else
				return notImplemented();
			#end
		}
		else return SurpriseTools.success();
	}

	function doSetExpiry(_:Noise):Surprise<Noise,Error> {
		if ( expiryFlag ) {
			setCookie( sessionID, expiry );
		}
		return SurpriseTools.success();
	}

	function doCloseSession(_:Noise):Surprise<Noise,Error> {
		if ( closeFlag ) {
			setCookie( "", -1 );
			var filename = getSessionFilePath( sessionID );
			#if sys
				return SurpriseTools.tryCatchSurprise(function() {
					FileSystem.deleteFile( filename );
					return Noise;
				});
			#elseif nodejs
				return Fs.unlink.bind( filename ).asVoidSurprise();
			#else
				return notImplemented();
			#end
		}
		else return SurpriseTools.success();
	}

	/**
	Retrieve an item from the session data.

	This will throw an error if `this.init()` has not already been called.
	**/
	public inline function get( name:String ):Dynamic {
		checkStarted();
		return sessionData!=null ? sessionData.get( name ) : null;
	}

	/**
	Set an item in the session data.

	Note this will not commit the value to a file until `this.commit()` is called (generally at the end of a request).

	This will throw an error if `this.init()` has not already been called.
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

	This will throw an error if `this.init()` has not already been called.
	**/
	public inline function exists( name:String ):Bool {
		checkStarted();
		return sessionData!=null && sessionData.exists( name );
	}

	/**
	Remove an item from the session.

	Note this will not commit the value to a file until `this.commit()` is called (generally at the end of a request).

	This will throw an error if `this.init()` has not already been called.
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
	Trigger a regeneration of the session ID when `this.commit()` is called.
	**/
	public function regenerateID():Void {
		regenerateFlag = true;
	}

	/** Return whether or not the session is active, meaning it has been initialised either in this request or in a previous request. **/
	public inline function isActive():Bool {
		return started || get_id()!=null;
	}

	/**
	Return the current ID, either one that has been set during `this.init()`, or one found in either `HttpRequest.cookies` or `HttpRequest.params`.
	**/
	function get_id():String {
		if ( sessionID==null ) sessionID = context.request.cookies[sessionName];
		if ( sessionID==null ) sessionID = context.request.params[sessionName];
		return sessionID;
	}

	/**
	Close the session.

	The sessionData and sessionID will be set to null, and the session will be flagged for deletion (when `this.commit()` is called)
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
		return Uuid.create();
	}

	inline function checkStarted( ?pos:haxe.PosInfos ) {
		if ( !started )
			throw HttpError.internalServerError( "Trying to access session data before init() has been run" );
	}

	static inline function testValidId( id:String ):Bool {
		return ( id!=null && Uuid.isValid(id) );
	}

	static inline function notImplemented<T>( ?p:haxe.PosInfos ):Surprise<T,Error> {
		return 'FileSession is not implemented on this platform'.asSurpriseError( p );
	}
}
