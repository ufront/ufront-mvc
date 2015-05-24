package ufront.web.session;

import ufront.web.context.HttpContext;
import ufront.web.HttpCookie;
import ufront.web.session.UFHttpSession;
import ufront.cache.UFCache;
import haxe.ds.StringMap;
import tink.CoreApi;
using haxe.io.Path;
using ufront.core.AsyncTools;

/**
A session implementation that works with any `UFCache` implementation.

A `UFCache` can store data in memory, a database, a cache mechanism such as Redis, flat-files, or anything.
So `CacheSession` is a versatile way for you to have a session implementation with any cache engine.

A `UFCacheConnection` is injected, and we use the `this.savePath` variable as the cache namespace.
The session ID is used as the cache item ID.

The contents of the session are saved to the cache, and restored from the cache, for each request.
This will change depending on the `UFCache` implementation used.
For example, `MemoryCache` will merely store the session data in a `Map` in memory, and access it directly.
A `DBCache` on the other hand will save the session data to a database table using `SData` type, and so the data must serialize easily.

The session ID is sent to the client as a `HttpCookie`.
When reading the session ID, `HttpRequest.cookies` is checked first, followed by `HttpRequest.params`.

When searching the parameters or cookies for the Session ID, the name to search for is defined by the `this.sessionName` property.
**/
class CacheSession implements UFHttpSession {
	// Statics

	/**
	The default session name to use if none is provided by the injector.

	The default value is `UfrontSessionID`.
	You can change this static variable to set a new default.
	**/
	public static var defaultSessionName:String = "UfrontSessionID";

	/**
	The default savePath to use if none is provided by the injector.

	This name will be used as the namespace for the `UFCacheConnection`.
	The default value is "sessions".
	You can change this static value to set a new default.
	**/
	public static var defaultSavePath:String = "sessions";

	/**
	The default expiry value.

	The default value is 0 (meaning the session will expire when the window is closed).
	You can change the default by changing this static variable.
	**/
	public static var defaultExpiry:Int = 0;

	static var validID = ~/^[a-zA-Z0-9]+$/;
	static inline function isValidID( id:String ):Bool {
		return ( id!=null && validID.match(id) );
	}

	// Private variables

	var started:Bool;
	var commitFlag:Bool;
	var closeFlag:Bool;
	var regenerateFlag:Bool;
	var expiryFlag:Bool;
	var sessionID:String;
	var oldSessionID:Null<String>;
	var sessionData:StringMap<Dynamic>;
	var cache:UFCache;

	// Public variables

	/**
	The current session ID.

	If not set, it will be read from the cookies, or failing that, the request parameters.
	This cannot be set manually, please see `this.regenerateID()` for a way to change the session ID.
	**/
	public var id(get,never):Null<String>;

	/**
	The current `HttpContext`.
	Supplied by dependency injection.
	**/
	@inject
	public var context:HttpContext;

	/**
	The `UFCacheConnection` to use.
	Supplied by dependency injection.
	**/
	@inject
	public var cacheConnection:UFCacheConnection;

	/**
	The name of the cookie (or request parameter) that holds the session ID.

	This is set by injecting a `String` named `sessionName`, otherwise the default `CacheSession.defaultSessionName` value is used.
	**/
	public var sessionName(default,null):String;

	/**
	The lifetime / expiry of the cookie, in seconds.

	- A positive value sets the cookie to expire that many seconds from the current time.
	- A value of 0 represents expiry when the browser window is closed.
	- A negative value expires the cookie immediately.

	This is set by injecting an `Int` named `sessionExpiry`, otherwise the default `CacheSession.defaultExpiry` value is used.
	**/
	public var expiry(default,null):Null<Int>;

	/**
	The save path for the session files.

	This is used with `UFCacheConnection.getNamespace()` to retrieve the appropriate cache.

	This is set by injecting a `String` named `sessionSavePath`, otherwise the default `CacheSession.defaultSavePath` value is used.
	**/
	public var savePath(default,null):String;

	// Public functions

	/**
	Construct a new session object.

	This does not initialize the cache or read any data.
	Data is read during `this.init()` and written during `this.commit()`, both of which require asynchronous handling.

	A new session object should be created for each request, and it will then associate itself with the correct session entry for the given client.

	In general you should create your object using dependency injection to make sure it is initialised correctly.
	**/
	public function new() {
		started = false;
		commitFlag = false;
		closeFlag = false;
		regenerateFlag = false;
		expiryFlag = false;
		sessionData = null;
		sessionID = null;
		oldSessionID = null;
	}

	/**
	Use the current injector to check for configuration for this session: `this.sessionName`, `this.expiry` and `this.savePath`.

	If no values are available in the injector, the defaults will be used.
	This also initialises a cache from our `this.cacheConnection` using `this.savePath` as the namespace.
	This will be called automatically as part of dependency injection.
	**/
	@inject public function injectConfig( context:HttpContext ) {
		// Manually check for these injections, because if they're not provided we have defaults - we don't want minject to throw an error.
		this.sessionName =
			if ( context.injector.hasRule(String,"sessionName") )
				context.injector.getResponse( String, "sessionName" )
			else defaultSessionName;
		this.expiry =
			if ( context.injector.hasRule(Int,"sessionExpiry") )
				context.injector.getResponse( Int, "sessionExpiry" );
			else defaultExpiry;
		this.savePath =
			if ( context.injector.hasRule(String,"sessionSavePath") )
				context.injector.getResponse( String, "sessionSavePath" )
			else defaultSavePath;
		this.cache = this.cacheConnection.getNamespace( savePath );
	}

	/**
	Set the number of seconds the session should last.

	Note in this implementation only the cookie expiry is affected.
	The session is not currently deleted / expired from the cache.
	The user could manually override this or send the session variable in the request parameters, and the session would still work.
	**/
	public function setExpiry( e:Int ) {
		expiry = e;
	}

	/**
	Initiate the session.

	This will check for an existing session ID.
	If one exists, it will read and fetch the session data from that session's cache item.

	If a session does not exist, one will be created, including generating and reserving a new session ID.

	This must be called before any other operations which require access to the current session.
	**/
	public function init():Surprise<Noise,Error> {
		function startFreshSession() {
			this.regenerateID();
			this.sessionData = new StringMap();
			this.started = true;
			return Success(Noise);
		}

		if ( !started ) {
			get_id();
			if ( sessionID==null || !isValidID(sessionID) ) {
				return startFreshSession().asSurprise();
			}
			else {
				return cache.get( sessionID ).map(function( outcome:Outcome<Dynamic,CacheError> ):Outcome<Noise,Error> {
					switch outcome {
						case Success(data):
							this.sessionData = Std.instance( data, StringMap );
							if ( sessionData!=null ) {
								this.started = true;
								return Success(Noise);
							}
							else {
								context.ufWarn( 'Failed to unserialize session $sessionID (Was ${Type.typeof(data)}, expected StringMap), starting a fresh session instead.' );
								return startFreshSession();
							}
						case Failure(ENotInCache):
							context.ufWarn( 'Client requested session $sessionID, but it did not exist in the cache. Starting a fresh session instead.' );
							return startFreshSession();
						case Failure(ECacheNotReadable(msg)):
							context.ufWarn( 'Failed to read cache for session $sessionID: $msg. Starting a fresh session instead.' );
							return startFreshSession();
						case Failure(error):
							return Failure( Error.withData('Failed to initialize session',error) );
					}
				});
			}
		}
		else return Future.sync( Success(Noise) );
	}

	/**
	Commit if required.

	Returns an Outcome, which is a Failure if the commit failed, usually because of not having permission to write to disk.
	**/
	public function commit():Surprise<Noise,Error> {

		var oldSessionID = sessionID;
		var sessionIDSurprise =
			if ( sessionID==null || regenerateFlag ) findNewSessionID()
			else Future.sync( Success(sessionID) );

		return
			sessionIDSurprise
			>> function(id:String):Noise {
				this.sessionID = id;
				return Noise;
			}
			>> function(_:Noise):Surprise<Noise,Error> {
				if ( regenerateFlag ) {
					// Delete the old cached entry, and then we'll commit the new one.
					commitFlag = true;
					return cache.remove( oldSessionID ).changeFailureToError();
				}
				return Future.sync( Success(Noise) );
			}
			>> function(_:Noise):Surprise<Noise,Error> {
				if ( commitFlag && sessionData!=null ) {
					setCookie( sessionID, expiry );
					return cache.set( sessionID, sessionData ).changeSuccessToNoise().changeFailureToError();
				}
				return Future.sync( Success(Noise) );
			}
			>> function(_:Noise):Noise {
				if ( expiryFlag && !closeFlag ) {
					setCookie( sessionID, expiry );
				}
				return Noise;
			}
			>> function(_:Noise):Surprise<Noise,Error> {
				if ( closeFlag ) {
					setCookie( "", -1 );
					return cache.remove( sessionID ).changeFailureToError();
				}
				return Future.sync( Success(Noise) );
			}
			;
	}

	function findNewSessionID():Surprise<String,Error> {
		var tryID = generateSessionID();
		return cache.get( tryID ).flatMap(function(outcome:Outcome<Dynamic,CacheError>):Surprise<String,Error> {
			return switch outcome {
				case Success(outcome):
					// It's taken... try a different ID.
					return findNewSessionID();
				case Failure(ENotInCache):
					// It is available! Set the cookie and reserve the name.
					setCookie( tryID, this.expiry );
					return cache.set( tryID, new StringMap() ).map( function(outcome) switch outcome {
						case Success(_): return Success(tryID);
						case Failure(err): return Failure( Error.withData('Failed to reserve session ID $tryID',err) );
					});
				case Failure(e):
					return Future.sync( Failure(Error.withData('Failed to find new session ID, cache error',e)) );
			}
		});
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
	Retrieve an item from the session data.

	This will throw an error if `this.init()` has not already been called.
	**/
	public inline function get( name:String ):Dynamic {
		checkStarted();
		return sessionData!=null ? sessionData.get( name ) : null;
	}

	/**
	Set an item in the session data.

	Note this will not commit the value to our cache until `this.commit()` is called.

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
	Force the session to be committed at the end of this request.
	**/
	public inline function triggerCommit():Void {
		commitFlag = true;
	}

	/**
	Trigger a regeneration of the session ID when `this.commit` is called.
	**/
	public function regenerateID():Void {
		regenerateFlag = true;
	}

	/**
	Whether or not the current session is active, meaning it has been assigned an ID and has been initialized.
	**/
	public inline function isActive():Bool {
		return started && get_id()!=null;
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

	The sessionData and sessionID will be set to null, and the session will be flagged for deletion (when `this.commit` is called)
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

	inline function generateSessionID() {
		return Random.string(40);
	}

	inline function checkStarted() {
		if ( !started )
			throw "Trying to access session data before calling init()";
	}
}
