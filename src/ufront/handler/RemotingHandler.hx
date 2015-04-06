package ufront.handler;

import haxe.remoting.Context;
import haxe.Serializer;
import haxe.Unserializer;
import haxe.CallStack;
import ufront.log.Message;
import ufront.web.context.*;
import ufront.remoting.RemotingError;
import minject.Injector;
import ufront.api.*;
import ufront.app.*;
import ufront.auth.*;
import ufront.core.Sync;
import tink.CoreApi;
import haxe.rtti.Meta;
import haxe.EnumFlags;

/**
	Checks if a request is a remoting request and processes accordingly.

	It looks for the "X-Haxe-Remoting" remoting header to check if this is a remoting call - the path/URL used does not matter.
	If it is a remoting call, it will process it accordingly and return a remoting result (basically serialized Haxe values).
	Traces are also serialized and sent to the client.

	If used with a UfrontApplication, and the `UfrontConfiguration.remotingApi` option was set, that API will be loaded automatically.
	Further APIs can be loaded through `ufrontApp.remotingHandler.loadApiContext()`.

	@author Jason O'Neil
**/
class RemotingHandler implements UFRequestHandler
{
	var apiContexts:List<Class<UFApiContext>>;
	var apis:List<Class<UFApi>>;
	var context:Context;

	public function new() {
		this.apiContexts = new List();
		this.apis = new List();
	}

	/**
		Expose a single UFApi to the request.
		This will be available through Ufront style remoting, using `UFApi` or `UFAsyncApi` on the client.
	**/
	public inline function loadApi( api:Class<UFApi> ) {
		apis.push( api );
	}

	/**
		Expose a group of UFApis to the request.
		These will be available through Ufront style remoting, using `UFApi` or `UFAsyncApi` on the client.
	**/
	public inline function loadApis( newAPIs:Iterable<Class<UFApi>> ) {
		for ( api in newAPIs )
			loadApi( api );
	}

	/**
		Expose a UFApiContext to the request.

		This will be available through both Ufront style and Haxe style remoting.

		Ufront style remoting uses the `UFApi` and `UFAsyncApi` on the client.
		Ufront remoting works synchronously for `UFApi`, or returns a surprise for `UFAsyncApi`.

		Haxe style remoting creates a context class on the client containing all the API proxies.
		For example a class `ApiContext` with `var signupApi:SignupApi` would generate `ApiContextClient` with `var signupApi:SignupApiProxy`.
		Haxe style remoting uses remoting calls using plain async callbacks..
	**/
	public inline function loadApiContext( apiContext:Class<UFApiContext> ) {
		apiContexts.push( apiContext );
		loadApis( UFApiContext.getApisInContext(apiContext) );
	}

	public function handleRequest( httpContext:HttpContext ):Surprise<Noise,Error> {
		var doneTrigger = Future.trigger();
		if ( httpContext.request.clientHeaders.exists("X-Haxe-Remoting") ) {

			// Execute the request
			var r = httpContext.response;
			var remotingResponse:Future<String>;

			// Set the status to OK for now, and only change it if an error is thrown.
			r.setOk();

			// We are keeping these outside of the try {} so they can be referenced in the catch {}
			var path:Array<String> = null;
			var args:Array<Dynamic> = null;

			try {
				initializeContext( httpContext.injector );

				// Check the '__x' parameter is present
				var params = httpContext.request.params;
				if ( !params.exists("__x") )
					throw 'Remoting call did not have parameter `__x` which describes which API call to make.  Aborting';

				// Understand the request that is being made and then execute it
				var u = new Unserializer( params["__x"] );
				path = u.unserialize();
				args = u.unserialize();
				var apiCallFinished = executeApiCall( path, args, context, httpContext.actionContext );
				remotingResponse = apiCallFinished.map(function(data:Dynamic) {
					var s = new Serializer();
					s.serialize( data );
					return "hxr" + s.toString();
				});
			}
			catch ( e:Dynamic ) {
				// Don't use the `async.error` handler and the ErrorModule, rather, send the error over the remoting protocol.
				var error:String = e;
				var apiNotFoundMessages = ["Invalid path","No such object","Can't access","No such method"];
				if ( path!=null && args!=null && Std.is(e,String) && Lambda.exists(apiNotFoundMessages,function(msg) return StringTools.startsWith(error,msg)) ) {
					remotingResponse = Future.sync( 'Unable to access ${path.join(".")} - API Not Found ($error). See ${@:privateAccess context.objects}' );
					r.setNotFound();
				}
				else {
					r.setInternalError();
					remotingResponse = Future.sync( remotingError(e,httpContext) );
				}
			}

			remotingResponse.handle(function(response:String) {
				// Set the response
				r.contentType = "application/x-haxe-remoting";
				r.clearContent();
				r.write( response );

				// Finished... mark request as handled and move on to middleware/logging etc
				httpContext.completion.set(CRequestHandlersComplete);
				doneTrigger.trigger( Success(Noise) );
			});
		}
		else doneTrigger.trigger( Success(Noise) ); // Not a remoting call

		return doneTrigger.asFuture();
	}

	public function initializeContext( injector:Injector ) {
		context = new Context();
		for ( apiContextClass in apiContexts ) {
			var apiContext = injector.instantiate( apiContextClass );
			for ( fieldName in Reflect.fields(apiContext) ) {
				var api = Reflect.field( apiContext, fieldName );
				if ( Reflect.isObject(api) )
					context.addObject( fieldName, api, false );
			}
		}
		for ( apiClass in apis ) {
			var className = Type.getClassName( apiClass );
			var api = injector.instantiate( apiClass );
			context.addObject( className, api, false );
		}
	}

	@:access(haxe.remoting.Context)
	public function executeApiCall( path:Array<String>, args:Array<Dynamic>, remotingContext:Context, actionContext:ActionContext ):Future<Dynamic> {
		// Preliminary check that the path exists.
		if ( remotingContext.objects.exists(path[0])==false ) {
			throw 'Invalid path ${path.join(".")}';
		}

		// Save the details of the request to the ActionContext.
		actionContext.handler = this;
		actionContext.action = path[path.length-1];
		actionContext.controller = remotingContext.objects.get( path[0] ).obj;
		actionContext.args = args;

		// Get the return type information for the current call.
		var returnType:Int;
		try {
			var fieldsMeta = Meta.getFields( Type.getClass(actionContext.controller) );
			var actionMeta = Reflect.field( fieldsMeta, actionContext.action );
			returnType = actionMeta.returnType[0];
		}
		catch( e:Dynamic ) {
			#if debug
				actionContext.httpContext.ufError( 'Failed to get metadata for API: $e' );
				actionContext.httpContext.ufError( 'Assuming API call to ${actionContext.action} returns a regular value' );
			#end
			returnType = 0;
		}
		var flags:EnumFlags<ApiReturnType> = EnumFlags.ofInt( returnType );

		// Make the call, and wrap it as a Future, so we can handle sync/async calls the same.
		// Note, the serialized result will always be the result of the future, and it's up to the client to re-wrap it in a future so that it matches the type signiature.
		// So if you're API calls return Future's, you will need to use a Ufront Remoting Connection, not one of the Haxe ones in the standard library.
		var result:Dynamic = remotingContext.call( path, args );
		return
			if (flags.has(ARTFuture)) result;
			else if (flags.has(ARTVoid)) Future.sync( null );
			else Future.sync( result );
	}

	function remotingError( e:Dynamic, httpContext:HttpContext ):String {
		// Log the error
		httpContext.ufError( e );

		if ( httpContext.request.clientHeaders.exists("X-Ufront-Remoting") ) {
			// We can include the "hxe" and "hxs" exception and stack trace.
			// Serialize the exception
			var s = new haxe.Serializer();
			s.serializeException(e);
			var serializedException = "hxe" + s.toString();

			#if debug
				// Serialize the stack trace
				var exceptionStack = CallStack.toString( CallStack.exceptionStack() );
				var serializedStack = "hxs" + Serializer.run( exceptionStack );
				return serializedStack + "\n" + serializedException;
			#else
				return serializedException;
			#end
		}
		else {
			// This is standard Haxe remoting.  Only use the "hxr" line with a serialized exception.
			var s = new haxe.Serializer();
			s.serializeException(e);
			return "hxr" + s.toString();
		}

	}

	public function toString() return "ufront.handler.RemotingHandler";
}
