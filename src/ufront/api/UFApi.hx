package ufront.api;

import haxe.PosInfos;
import ufront.log.MessageList;
import haxe.EnumFlags;
import haxe.remoting.RemotingError;
import ufront.auth.*;
import haxe.CallStack;
import haxe.remoting.RemotingUtil;
using tink.CoreApi;

/**
	This class provides a build macro that will take some extra precautions to make
	sure your Api class compiles successfully on the client as well as the server.

	Basically, the build macro strips out private methods, and the method bodies of public methods,
	so all that is left is the method signiature.

	This way, the Proxy class will still be created successfully, but none of the server-side APIs
	get tangled up in client side code.
**/
@:autoBuild(ufront.api.ApiMacros.buildApiClass())
class UFApi
{
	/**
		The current `ufront.auth.UFAuthHandler`.

		You can use this to check permissions etc.

		This is inserted via dependency injection.
	**/
	@inject public var auth:UFAuthHandler<UFAuthUser>;

	/**
		The messages list.

		When called from a web context, this will usually result in the HttpContext's `messages` array being pushed to so your log handlers can handle the messages appropriately.

		This is inserted via dependency injection, and must be injected for `ufTrace`, `ufLog`, `ufWarn` and `ufError` to function correctly.
	**/
	@:noCompletion @inject public var messages:MessageList;

	/**
		A default constructor.

		This has no effect, it just exists so you don't need to create a constructor on every child class.
	**/
	public function new() {}

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

	/**
		Print the current class name
	**/
	@:noCompletion
	public function toString() {
		return Type.getClassName( Type.getClass(this) );
	}
}

/**
	A class that builds an API proxy of an existing UFApi.
	On the server it just wraps results in Futures.
	On the client it uses a `HttpAsyncConnectionWithTraces` to perform remoting.
	Constructor dependency injection is used to get the original API on the server or the remoting connection on the client.
	Usage: `class AsyncLoginApi extends UFAsyncApi<LoginApi> {}`
**/
@:autoBuild( ufront.api.ApiMacros.buildAsyncApiProxy() )
class UFAsyncApi<T:UFApi> {
	var className:String;
	#if server
		var api:T;
		@inject public function new( api:T ) {
			this.api = api;
		}
	#elseif client
		var cnx:haxe.remoting.HttpAsyncConnectionWithTraces;
		@inject public function new( cnx:haxe.remoting.HttpAsyncConnectionWithTraces ) {
			this.cnx = cnx;
		}
	#end
	
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
					wrappedOutcome = switch result {
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
}