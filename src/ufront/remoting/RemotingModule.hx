package ufront.remoting;

import haxe.remoting.Context;
import haxe.Serializer;
import haxe.Unserializer;
import haxe.CallStack;
import ufront.module.IHttpModule;
import ufront.application.HttpApplication;
import ufront.web.error.*;
import ufront.web.result.*;
import ufront.web.context.*;
import minject.Injector;
import ufront.application.*;
import ufront.auth.*;
import tink.CoreApi;
import ufront.core.AsyncSignal;

/**
	Checks if a request is a remoting request and processes accordingly.

	It looks for the "X-Haxe-Remoting" remoting header to check if this is a remoting call - the path/URL used does not matter.
	If it is a remoting call, it will process it accordingly and return a remoting result (basically serialized Haxe values).
	Traces are also serialized and sent to the client.

	@author Jason O'Neil
**/
class RemotingModule implements IHttpModule
{
	var injector:Injector;
	var apis:List<Class<RemotingApiContext>>;
	var app:HttpApplication;

	/** Construct a new RemotingModule, optionally adding an API to the remoting Context. **/
	public function new() {
		apis = new List();
	}

	/** Expose a RemotingApiContext to the request **/
	public inline function loadApi( remotingApiContext:Class<RemotingApiContext> ) {
		apis.push( remotingApiContext );
	}

	/** Initializes a module and prepares it to handle remoting requests. */
	public function init( application:HttpApplication ):Void {
		app = application;
		injector = 
			if (Std.is(app, UfrontApplication)) cast(app,UfrontApplication).remotingInjector
			else app.appInjector;
		app.onPostResolveRequestCache.handle( executeRemoting );
	}

	/** Disposes of the resources (other than memory) that are used by the module. */
	public function dispose():Void {
		injector = null;
		apis = null;
	}

	function executeRemoting( httpContext:HttpContext ):Future<Noise> {
		var doneTrigger = Future.trigger();
		if ( httpContext.request.clientHeaders.exists("X-Haxe-Remoting") ) {
			
			// Set up the injector
			var requestInjector = injector.createChildInjector();
			requestInjector.mapValue( IAuthHandler, httpContext.auth );
			requestInjector.mapValue( Array, httpContext.messages, "messages" );

			// Map the specific implementations for auth and session
			requestInjector.mapValue( Type.getClass( httpContext.session ), httpContext.session );
			requestInjector.mapValue( Type.getClass( httpContext.auth ), httpContext.auth );

			// Set up the context
			var context = new Context();
			for (api in apis) {
				var apiContext = requestInjector.instantiate( api );
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
				remotingResponse = processRequest( params["__x"], context );
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

			// Mark this request as complete so further events don't fire
			httpContext.completed = true;

			// Run the log functions asynchronously, then complete.  
			AsyncSignal.dispatchChain( httpContext, [app.onLogRequest, app.onPostLogRequest] ).handle( function(_) doneTrigger.trigger(null) );
		}
		else doneTrigger.trigger(null); // Not a remoting call

		return doneTrigger.asFuture();
	}

	function processRequest( requestData:String, ctx:Context ):String {
		var u = new Unserializer( requestData );
		var path:Array<String> = u.unserialize();
		var args:Array<String> = u.unserialize();
		var data = ctx.call( path, args );
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
			return '$serializedStack\n$serializedException';
		#else
			return '$serializedException';
		#end

	}
}