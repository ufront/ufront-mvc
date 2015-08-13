package ufront.api;

import haxe.EnumFlags;
import ufront.remoting.RemotingError;
import ufront.remoting.RemotingUtil;
import ufront.web.HttpError;
import tink.core.Error;
import haxe.CallStack;
import haxe.rtti.Meta;
using ufront.core.AsyncTools;
using tink.CoreApi;

/**
An asynchronous proxy that calls a server API, using a `Surprise` to wait for the result.

#### Transformation:

Each public method of the `UFApi` you are proxying will be available in the proxy.
Instead of returning a synchronous value though, each method will return a `Surprise`, (a `Future<Outcome>`), which will hold the result of the remoting call, whether it succeeded or failed.

#### Return typing:

The return type for each function will be typed as follows:

- An API return type of `:Surprise<A,B>` will become `:Surprise<A,TypedError<RemotingError<B>>>`.
- An API return type of `:Future<T>` will become `:Surprise<T,TypedError<RemotingError<Dynamic>>>`.
- An API return type of `:Outcome<A,B>` will become `:Surprise<A,TypedError<RemotingError<B>>>`.
- An API return type of `:Void` will become `:Surprise<Noise,TypedError<RemotingError<Dynamic>>>`.
- An API return type of `:T` will become `:Surprise<T,TypedError<RemotingError<Dynamic>>>`.

#### Client and Server differences:

On the client it uses an injected `AsyncConnection` to perform the remoting call.

On the server, the original API will be called, and the result will be wrapped in a `Surprise` as described above.
If the server API is synchronous, the Surprise will also be resolved (and handled) synchronously.

Using the same `Surprise` results allows identical usage of the API on both the client or the server.

#### Injections:

The class must have the following injected to be functional:

- On the server, `api` - an instance of the original API object.
- On the client, `cnx` - an `AsyncConnection` to use for remoting.
- Both will be injected if you are using ufront's `Injector`.

#### UFAsyncApi and UFAsyncCallbackApi:

This class is quite similar to `UFAsyncCallbackApi`, except it returns a `Surprise` rather than using callbacks.
If your client code is using Ufront, it will probably be easier to use `UFAsyncApi` and call them from your controllers on the client or server.
If your client code is not using Ufront, or particularly if it is not written in Haxe, it may be easier to create a `UFClientApiContext` and use the callback style APIs.

#### Usage:

```haxe
class AsyncLoginApi extends UFAsyncApi<LoginApi> {}

@inject public var api:AsyncLoginApi;

// The long way:
var surprise = api.attemptLogin( username, password );
var result = "";
surprise.handle(function(outcome) switch outcome {
  case Success(user): result = 'You are logged in as $user!';
  case Failure(err): result = 'Failed to log in: $err';
}
return result;

// The short way, using the ">>" operator from tink_core, which allows you to just handle a success:
return api.attemptLogin( username, password ) >> function( user ) {
  return 'You are logged in as $user!';
}
```
**/
#if !macro
@:autoBuild( ufront.api.ApiMacros.buildAsyncApiProxy() )
#end
class UFAsyncApi<SyncApi:UFApi> {
	var className:String;
	#if server
		/**
		The `api` is provided by dependency injection.
		However, because of limitations between minject and generics, we cannot simply use `@inject public var api:T` based on a type paremeter.
		Instead, we get the build macro to create a `@inject public function injectApi( injector:Injector )` method, specifying the class of our sync Api as a constant.
		**/
		public var api:SyncApi;
	#elseif client
		@inject public var cnx:haxe.remoting.AsyncConnection;
	#end

	public function new() {}

	function _makeApiCall<A,B>( method:String, args:Array<Dynamic>, flags:EnumFlags<ApiReturnType>, ?pos:haxe.PosInfos ):Surprise<A,TypedError<RemotingError<B>>> {
		var remotingCallString = '$className.$method(${args.join(",")})';
		#if server
			function callApi():Dynamic {
				return Reflect.callMethod( api, Reflect.field(api,method), args );
			}
			function returnError( e:Dynamic ) {
				var stack = CallStack.toString( CallStack.exceptionStack() );
				var remotingError = RServerSideException(remotingCallString,e,stack);
				return HttpError.remotingError( remotingError, pos ).asBadSurprise();
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
						case Failure(err): Failure(HttpError.remotingError(RApiFailure(remotingCallString,err),pos));
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
					return switch outcome {
						case Success(data): Future.sync( Success(data) );
						case Failure(err): Future.sync( Failure(HttpError.remotingError(RApiFailure(remotingCallString,err),pos)) );
					}
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
				resultTrigger.trigger( Failure(HttpError.remotingError(cast err,pos)) );
			}));
			cnx.call( args, function(result:Dynamic) {
				var wrappedOutcome:Outcome<A,TypedError<RemotingError<B>>>;
				if ( flags.has(ARTVoid) ) {
					wrappedOutcome = Success(cast Noise);
				}
				else if ( flags.has(ARTOutcome) ) {
					var outcome:Outcome<A,B> = result;
					wrappedOutcome = switch outcome {
						case Success(data): Success(data);
						case Failure(err): Failure(HttpError.remotingError(RApiFailure(remotingCallString,err),pos));
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

	This works by looking for `@asyncApi("path.to.AsyncApi")` metadata on the given `syncApi` class.
	This metadata should be generated by `UFAsyncApi`'s build macro.
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
