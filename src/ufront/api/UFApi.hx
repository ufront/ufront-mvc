package ufront.api;

import haxe.PosInfos;
import haxe.EnumFlags;
import ufront.remoting.RemotingError;
import haxe.CallStack;
import ufront.remoting.RemotingUtil;
import haxe.rtti.Meta;
using tink.CoreApi;

/**
	An API that can be used in Ufront controllers, tasks, other APIs, or via remoting.

	**Server and Client**

	UFApis are designed to run on the server, and have access to all the server resources (FileSystem, DB, Email sending etc).
	They are also designed to be shared with clients via Haxe Remoting - so you can call your server APIs seamlessly from the client.

	**Writing APIs for the server:**

	When you write your APIs, simple extend UFApi:

	```haxe
	class LoginApi extends UFApi {
		// You can inject anything you need to help with your API.
		@inject public var easyAuth:EasyAuth;

		public function attemptLogin( username:String, password:String ):User {
			// Do some logic which might involve reading from the database, other APIs, HTTP calls etc.
			return easyAuth.startSessionSync( new EasyAuthDBAdapter(username,password) ).sure();
		}
	}
	```

	Some general points of advice:

	- A UFApi is created once per request, and is discarded at the end of the request. So it can store information relevant to that request.
	- Static variables are sometimes shared between requests on mod_neko, mod_tora and client side JS, meaning you should not rely on static variables to have a "fresh" state for each request.
	- If your API needs to run asynchronously, make sure it returns a `Future` or a `Surprise`.
	- If your API returns an `Outcome` it has some special behaviour when being used with `UFAsyncApi` or `UFAsyncCallbackApi`.

	**Using APIs on the client:**

	There are 3 ways to call your `UFApi` from the client:

	1. **With a `UFAsyncApi<YourApi>` proxy.**
		This will wrap your API, and return a `Surprise` instead of a synchronous value.
		When you compile the client it will use asynchronous HTTP remoting calls.
		See `UFAsyncApi` for more details.

	2. **With a `UFAsyncCallbackApi<YourApi>` proxy.**
		This will wrap your API, and use callback methods for `onResult` and `onError` rather than returning a result directly.
		When you compile the client it will use asynchronous HTTP remoting calls.
		See `UFAsyncCallbackApi` for more details.

	3. **By calling your `UFApi` directly on the client.**
		When you compile your `UFApi` on the client, it will attempt to use a synchronous remoting connection to the server.
		This works well on sys targets like Neko and PHP, and is useful for your CLI tasks to call server APIs.
		On Javascript however this will usually fail, because synchronous XmlHttpRequests are not supported, unless you are making the call from a Web Worker.

	All 3 of these methods compile on both the client and the server, allowing you to call them in the same way on the client or the server.

	**Sharing an API for Remoting:**

	For APIs to be available over remoting, they need to be shared with the `RemotingHandler`.
	The easiest way to do this is to create a `UFApiContext` class with each of the APIs you wish to share, and set it as the `remotingApi` in your given `UfrontConfiguration`.

	**Injections:**

	The following injections are required for a `UFApi` class to function correctly:

	- **(Server)** `auth`: A `UFAuthHandler` that the API can use to check permissions for certain actions.
	- **(Server)** `messages`: A `MessageList` used to track `ufTrace`, `ufLog`, `ufWarn` and `uferror` calls and send them to the appropriate output.
	- **(Client)** `cnx`: A `haxe.remoting.Connection` used to send synchronous HTTP remoting calls.

	Because APIs are usually created through dependency injection, you can also add other injections to your APIs:

	```haxe
	@inject public var mailer:UFMailer;
	@inject public var loginApi:LoginApi;
	@inject("contentDirectory") public var contentDir:String;

	var doc:Document;
	@inject public function getDocument( ds:DocumentStore ) {
		doc = ds.get( "myDocument" );
	}
	```

	Remember that injections points must be public to be recognised by `minject`.

	All APIs will be available in the dependency injector for each request, so you can use them in other APIs, your Controllers etc.

	**Logging Functions**:

	Because Ufront may be used in a multi-threaded and multi-request environment, the static `haxe.Log.trace()` function does not send output to the client unless compiled with `-debug`.

	Similar to our `Controller` class, `UFApi` provides some helpers: `ufTrace()`, `ufLog()`, `ufWarn()` and `ufError()`.
	These will be sent to all the relevant `UFLogHandler` instances - including to the browser console - when called through both remoting requests and regular web requests.

	**Checking Authorization**:

	An `auth` object is injected in each `UFApi`. You can use it to check permissions:

	```haxe
	if ( auth.hasPermission( CanDeletePosts ) ) { ... }
	auth.requirePermission( CanDeletePosts ); // Throw an error if they do not have permission.
	if ( auth.currentUser.id!=document.owner.id ) { ... }
	```

	**Security Note:** It is wise to do your authentication checks in your server rather than your controllers.
	If you choose to run your controllers on the client, or expose the API over remoting, you risk somebody bypassing the security checks.
	Placing your checks in the API ensures they will always run on a server before you allow a certain action to take place.

	See `UFAuthHandler` for a complete description of the API.
**/
@:autoBuild(ufront.api.ApiMacros.buildApiClass())
class UFApi {

	#if server
		/**
			The current `ufront.auth.UFAuthHandler`.

			You can use this to check permissions etc.

			This is inserted via dependency injection.

			This property only exists when compiled with `-D server`.
		**/
		@inject public var auth:ufront.auth.UFAuthHandler<ufront.auth.UFAuthUser>;

		/**
			The messages list.

			When called from a web context, this will usually result in the HttpContext's `messages` array being pushed to so your log handlers can handle the messages appropriately.

			This is inserted via dependency injection, and must be injected for `ufTrace`, `ufLog`, `ufWarn` and `ufError` to function correctly.

			This property only exists when compiled with `-D server`.
		**/
		@:noCompletion @inject public var messages:ufront.log.MessageList;
	#elseif client
		/**
			The `haxe.remoting.Connection` needed on the client to make a synchronous remoting call, matching the usage server side.

			This is inserted via dependency injection, and is required for client side synchronous remoting to function correctly.

			This property only exists when compiled with `-D client`.
		**/
		@inject public var cnx:haxe.remoting.Connection;
	#end

	public function new() {}

	#if server
		/**
			A shortcut to `HttpContext.ufTrace`

			A `messages` array must be injected for these to function correctly.  Use `ufront.handler.MVCHandler` and `ufront.handler.RemotingHandler` to inject this correctly.
		**/
		@:noCompletion
		inline function ufTrace( msg:Dynamic, ?pos:PosInfos ) {
			messages.push({ msg: msg, pos: pos, type:Trace });
		}

		/**
			A shortcut to `HttpContext.ufLog`

			A `messages` array must be injected for these to function correctly.  Use `ufront.handler.MVCHandler` and `ufront.handler.RemotingHandler` to inject this correctly.
		**/
		@:noCompletion
		inline function ufLog( msg:Dynamic, ?pos:PosInfos ) {
			messages.push({ msg: msg, pos: pos, type:Log });
		}

		/**
			A shortcut to `HttpContext.ufWarn`

			A `messages` array must be injected for these to function correctly.  Use `ufront.handler.MVCHandler` and `ufront.handler.RemotingHandler` to inject this correctly.
		**/
		@:noCompletion
		inline function ufWarn( msg:Dynamic, ?pos:PosInfos ) {
			messages.push({ msg: msg, pos: pos, type:Warning });
		}

		/**
			A shortcut to `HttpContext.ufError`

			A `messages` array must be injected for these to function correctly.  Use `ufront.handler.MVCHandler` and `ufront.handler.RemotingHandler` to inject this correctly.
		**/
		@:noCompletion
		inline function ufError( msg:Dynamic, ?pos:PosInfos ) {
			messages.push({ msg: msg, pos: pos, type:Error });
		}
	#elseif client
		var className:String;
		inline function _makeApiCall<A>( method:String, args:Array<Dynamic> ):A {
			if ( className==null )
				className = Type.getClassName( Type.getClass(this) );

			// Find out if this is a Future
			var isFuture = false;
			var isVoid = false;
			try {
				var fieldsMeta = Meta.getFields( Type.getClass(this) );
				var actionMeta = Reflect.field( fieldsMeta, actionContext.action );
				var returnType:Int = actionMeta.returnType[0];
				var flags:EnumFlags<ApiReturnType> = EnumFlags.ofInt( returnType );
				isFuture = flags.has(ARTFuture);
			} catch( e:Dynamic ) {}

			var flags:EnumFlags<ApiReturnType>;
			var result = cnx.resolve( className ).resolve( method ).call( args );
			return if (isFuture) Future.sync(result) : result;
		}
	#end

	/**
		Print the current class name.
	**/
	@:noCompletion
	public function toString() {
		return Type.getClassName( Type.getClass(this) );
	}
}

/**
	A class that builds an Asynchronous API proxy of an existing UFApi.

	On the client it uses a `HttpAsyncConnection` to perform remoting, and wraps the results in a `Surprise<A,RemotingError<B>>` type, where a `Success` is the original return result, and a `Failure` describes the remoting failure or the API failure.

	On the server it just wraps results in the same `Surprise` type, so that the Async API can be used identically on the client or the server.

	Dependency injection is used to get the original API on the server, or the remoting connection on the client.

	Usage: `class AsyncLoginApi extends UFAsyncApi<LoginApi> {}`
**/
@:autoBuild( ufront.api.ApiMacros.buildAsyncApiProxy() )
class UFAsyncApi<SyncApi:UFApi> {
	var className:String;
	#if server
		/**
			Because of limitations between minject and generics, we cannot simply use `@inject public var api:T` based on a type paremeter.
			Instead, we get the build method to create a `@inject public function injectApi( injector:Injector )` method, specifying the class of our sync Api as a constant.
		**/
		public var api:SyncApi;
	#elseif client
		@inject public var cnx:haxe.remoting.AsyncConnection;
	#end

	public function new() {}

	function _makeApiCall<A,B>( method:String, args:Array<Dynamic>, flags:EnumFlags<ApiReturnType> ):Surprise<A,RemotingError<B>> {
		var remotingCallString = '$className.$method(${args.join(",")})';
		#if server
			function callApi():Dynamic {
				return Reflect.callMethod( api, Reflect.field(api,method), args );
			}
			function returnError( e:Dynamic ) {
				var stack = CallStack.toString( CallStack.exceptionStack() );
				return Future.sync( Failure(ServerSideException(remotingCallString,e,stack)) );
			}

			if ( flags.has(ARTVoid) ) {
				try {
					callApi();
					return Future.sync( Success(null) );
				}
				catch ( e:Dynamic ) return returnError(e);
			}
			else if ( flags.has(ARTFuture) && flags.has(ARTOutcome) ) {
				try {
					var surprise:Surprise<A,B> = callApi();
					return surprise.map(function(result) return switch result {
						case Success(data): Success(data);
						case Failure(err): Failure(ApiFailure(remotingCallString,err));
					});
				}
				catch ( e:Dynamic ) return returnError(e);
			}
			else if ( flags.has(ARTFuture) ) {
				try {
					var future:Future<A> = callApi();
					return future.map(function(data) {
						return Success( data );
					});
				}
				catch ( e:Dynamic ) return returnError(e);
			}
			else if ( flags.has(ARTOutcome) ) {
				try {
					var outcome:Outcome<A,B> = callApi();
					switch outcome {
						case Success(data): Future.sync( Success(data) );
						case Failure(err): Future.sync( Failure(ApiFailure(remotingCallString,err)) );
					}
					return Future.sync( Success(null) );
				}
				catch ( e:Dynamic ) return returnError(e);
			}
			else {
				try {
					var result:A = callApi();
					return Future.sync( Success(result) );
				}
				catch ( e:Dynamic ) return returnError(e);
			}
		#elseif client
			var resultTrigger = Future.trigger();
			var cnx = cnx.resolve(className).resolve(method);
			cnx.setErrorHandler(RemotingUtil.wrapErrorHandler(function (err:RemotingError<Dynamic>) {
				resultTrigger.trigger( Failure(cast err) );
			}));
			cnx.call( args, function(result:Dynamic) {
				var wrappedOutcome:Outcome<A,RemotingError<B>>;
				if ( flags.has(ARTVoid) ) {
					wrappedOutcome = Success(cast Noise);
				}
				else if ( flags.has(ARTOutcome) ) {
					var outcome:Outcome<A,B> = result;
					wrappedOutcome = switch outcome {
						case Success(data): Success(data);
						case Failure(err): Failure(ApiFailure(remotingCallString,err));
					}
				}
				else {
					wrappedOutcome = Success(result);
				}
				resultTrigger.trigger( wrappedOutcome );
			});
			return resultTrigger.asFuture();
		#end
	}

	/**
		For a given sync `UFApi` class, see if a matching `UFAsyncApi` class is available, and return it.
		Returns null if no matching `UFAsyncApi` was found.
	**/
	public static function getAsyncApi<T:UFApi>( syncApi:Class<T> ):Null<Class<UFAsyncApi<T>>> {
		var meta = Meta.getType(syncApi);
		if ( meta.asyncApi!=null ) {
			var asyncApiName:String = meta.asyncApi[0];
			if ( asyncApiName!=null ) {
				return cast Type.resolveClass( asyncApiName );
			}
		}
		return null;
	}
}
