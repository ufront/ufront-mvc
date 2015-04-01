package ufront.api;

import haxe.PosInfos;
import haxe.EnumFlags;
import ufront.remoting.RemotingError;
import haxe.CallStack;
import ufront.remoting.RemotingUtil;
import haxe.rtti.Meta;
using tink.CoreApi;

/**
	A UFApi is an API that can be used in Ufront controllers, tasks, other APIs, over via remoting.

	Features:

	- Compiles on Client and Server
	- Dependency injection (into this class)
	- Dependency injection (into other APIs or controllers)
	- ufTrace, ufLog, ufWarn, ufError
	- auth
	- Sync Remoting on the client
	- Async Remoting on the client with UFAsyncApi
	- Async on the server with UFAsyncApi
	- Remoting with ApiContext

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
			return cnx.resolve( className ).resolve( method ).call( args );
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
