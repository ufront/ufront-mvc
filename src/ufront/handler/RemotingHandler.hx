package ufront.handler;

import haxe.remoting.Context;
import haxe.Serializer;
import haxe.Unserializer;
import haxe.CallStack;
import ufront.app.HttpApplication;
import ufront.log.Message;
import ufront.web.result.*;
import ufront.web.context.*;
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
	Further APIs can be loaded through `ufrontApp.remotingHandler.loadApi()`.

	@author Jason O'Neil
**/
class RemotingHandler implements UFRequestHandler implements UFInitRequired
{
	var apis:List<Class<UFApiContext>>;

	/** Construct a new RemotingModule, optionally adding an API to the remoting Context. **/
	public function new() {
		apis = new List();
	}

	/** Expose a UFApiContext to the request **/
	public inline function loadApi( apiContext:Class<UFApiContext> ) {
		apis.push( apiContext );
	}

	/** Initializes a module and prepares it to handle remoting requests. */
	public function init( app:HttpApplication ):Surprise<Noise,Error> {
		var ufApp = Std.instance( app, UfrontApplication );
		if ( ufApp!=null ) {
			loadApi( ufApp.configuration.remotingApi );
		}
		return Sync.success();
	}

	/** Disposes of the resources (other than memory) that are used by the module. */
	public function dispose( app:HttpApplication ):Surprise<Noise,Error> {
		apis = null;
		return Sync.success();
	}

	public function handleRequest( httpContext:HttpContext ):Surprise<Noise,Error> {
		var doneTrigger = Future.trigger();
		if ( httpContext.request.clientHeaders.exists("X-Haxe-Remoting") ) {

			// Execute the request
			var r = httpContext.response;
			var remotingResponse:Future<String>;
			
			// Set the status to OK for now, and only change it if an error is thrown.
			r.setOk();
			
			try {
				// Set up the context
				var context = new Context();
				for (api in apis) {
					var apiContext = httpContext.injector.instantiate( api );
					for (fieldName in Reflect.fields(apiContext)) {
						var o = Reflect.field(apiContext, fieldName);
						if (Reflect.isObject(o))
							context.addObject(fieldName, o);
					}
				}

				// Check the '__x' parameter is present
				var params = httpContext.request.params;
				if ( !params.exists("__x") )
					throw 'Remoting call did not have parameter `__x` which describes which API call to make.  Aborting';

				// Execute the response ... TODO... can we make this support async?
				remotingResponse = processRequest( params["__x"], context, httpContext.actionContext );
			}
			catch ( e:Dynamic ) {
				// Don't use the `async.error` handler and the ErrorModule, rather, send the error over the remoting protocol.
				r.setInternalError();
				remotingResponse = Future.sync( remotingError(e,httpContext) );
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

	@:access(haxe.remoting.Context)
	function processRequest( requestData:String, remotingContext:Context, actionContext:ActionContext ):Future<String> {
		// Understand the request that is being made.
		var u = new Unserializer( requestData );
		var path:Array<String> = u.unserialize();
		var args:Array<Dynamic> = u.unserialize();

		// Save the details of the request to the ActionContext.
		actionContext.handler = this;
		actionContext.action = path[path.length-1];
		actionContext.controller = remotingContext.objects.get( actionContext.action );
		actionContext.args = args;
		// CHECK: are all of the above actionContext values correct?
		
		// Get the return type information for the current call.
		var fieldsMeta = Meta.getFields( Type.getClass(actionContext.controller) );
		var actionMeta = Reflect.field( fieldsMeta, actionContext.action );
		var flags:EnumFlags<ApiReturnType> = EnumFlags.ofInt( actionMeta.returnType );


		// Make the call, and wrap it as a Future, so we can handle sync/async calls the same.
		// Note, the serialized result will always be the result of the future, and it's up to the client to re-wrap it in a future so that it matches the type signiature.
		var result:Dynamic = remotingContext.call( path, args );
		var apiCallFinished:Future<Dynamic> =
			if (flags.has(ARTFuture)) result;
			else if (flags.has(ARTVoid)) Future.sync( null );
			else Future.sync( result );
		
		// Return a mapped future that will trigger when the result is ready and has been serialized.
		return apiCallFinished.map(function(data:Dynamic) {
			var s = new Serializer();
			s.serialize( data );
			return "hxr" + s.toString();
		});
	}

	function remotingError( e:Dynamic, httpContext:HttpContext ):String {
		// Log the error
		httpContext.ufError( e );

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

	public function toString() return "ufront.handler.RemotingHandler";
}
