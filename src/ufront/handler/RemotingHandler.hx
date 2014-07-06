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
			
			// Execute the request
			var r = httpContext.response;
			var remotingResponse:String;
			try {
				// Check the '__x' parameter is present
				var params = httpContext.request.params;
				if ( !params.exists("__x") ) 
					throw 'Remoting call did not have parameter `__x` which describes which API call to make.  Aborting';
				
				// Execute the response ... TODO... can we make this support async?
				remotingResponse = processRequest( params["__x"], context, httpContext.actionContext );
				r.setOk();
			}
			catch ( e:Dynamic ) {
				// Don't use the `async.error` handler and the ErrorModule, rather, send the error over the remoting protocol.
				remotingResponse = remotingError( e, httpContext );
				r.setInternalError();
			}

			// Set the response
			r.contentType = "application/x-haxe-remoting";
			r.clearContent();
			r.write( remotingResponse );

			// Finished... mark request as handled and move on to middleware/logging etc
			httpContext.completion.set(CRequestHandlersComplete);
			doneTrigger.trigger( Success(Noise) );
		}
		else doneTrigger.trigger( Success(Noise) ); // Not a remoting call

		return doneTrigger.asFuture();
	}

	@:access(haxe.remoting.Context)
	function processRequest( requestData:String, remotingContext:Context, actionContext:ActionContext ):String {
		var u = new Unserializer( requestData );
		var path:Array<String> = u.unserialize();
		var args:Array<Dynamic> = u.unserialize();

		var className = path.copy();
		actionContext.handler = this;
		actionContext.action = path[path.length-1];
		actionContext.controller = remotingContext.objects.get( actionContext.action );
		actionContext.args = args;

		var data = remotingContext.call( path, args );

		var s = new Serializer();
		s.serialize( data );
		return "hxr" + s.toString();
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
			return '$serializedException';
		#end
	}

	public function toString() return "ufront.handler.RemotingHandler";
}
