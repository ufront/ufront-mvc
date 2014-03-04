package ufront.handler;

import haxe.remoting.Context;
import haxe.Serializer;
import haxe.Unserializer;
import haxe.CallStack;
import ufront.app.HttpApplication;
import ufront.web.HttpError;
import ufront.web.result.*;
import ufront.web.context.*;
import minject.Injector;
import ufront.api.*;
import ufront.app.*;
import ufront.auth.*;
import ufront.core.Sync;
import tink.CoreApi;
import ufront.core.AsyncSignal;

/**
	Checks if a request is a remoting request and processes accordingly.

	It looks for the "X-Haxe-Remoting" remoting header to check if this is a remoting call - the path/URL used does not matter.
	If it is a remoting call, it will process it accordingly and return a remoting result (basically serialized Haxe values).
	Traces are also serialized and sent to the client.

	@author Jason O'Neil
**/
class RemotingHandler implements UFRequestHandler implements UFInitRequired
{
	/**
		An injector for things that should be available to the API classes in your remoting context.

		This extends `HttpApplication.injector`, so all mappings to the application injector will be available here.

		You can also add mappings that will only be available in the remoting APIs.  

		`UfrontApplication` will add mappings for each API class by default.

		We will create a child injector for each remoting request that also maps a `ufront.auth.UFAuthHandler` instance for checking auth in your API, and a `messages:Array<Message>` array so our APIs can log messages in a generic way whether running in a web context or not.
	**/
	public var injector(default,null):Injector;
	
	var apis:List<Class<UFApiContext>>;

	/** Construct a new RemotingModule, optionally adding an API to the remoting Context. **/
	public function new() {
		apis = new List();
		injector = new Injector();
		injector.mapValue( Injector, injector );
	}

	/** Expose a UFApiContext to the request **/
	public inline function loadApi( UFApiContext:Class<UFApiContext> ) {
		apis.push( UFApiContext );
	}

	/** Initializes a module and prepares it to handle remoting requests. */
	public function init( app ):Surprise<Noise,HttpError> {
		injector.parentInjector = app.injector;
		return Sync.success();
	}

	/** Disposes of the resources (other than memory) that are used by the module. */
	public function dispose( app ):Surprise<Noise,HttpError> {
		injector = null;
		apis = null;
		return Sync.success();
	}

	public function handleRequest( httpContext:HttpContext ):Surprise<Noise,HttpError> {
		var doneTrigger = Future.trigger();
		if ( httpContext.request.clientHeaders.exists("X-Haxe-Remoting") ) {
			var actionContext = new ActionContext( httpContext );

			// Set up the injector
			var requestInjector = injector.createChildInjector();
			requestInjector.mapValue( HttpContext, httpContext );
			requestInjector.mapValue( HttpRequest, httpContext.request );
			requestInjector.mapValue( HttpResponse, httpContext.response );
			requestInjector.mapValue( ActionContext, actionContext );
			requestInjector.mapValue( UFAuthHandler, httpContext.auth );
			requestInjector.mapValue( Array, httpContext.messages, "messages" );
			requestInjector.mapValue( String, httpContext.contentDirectory, "contentDirectory" );

			// Map the specific implementations for auth and session
			requestInjector.mapValue( Type.getClass( httpContext.session ), httpContext.session );
			requestInjector.mapValue( Type.getClass( httpContext.auth ), httpContext.auth );

			// Expose this injector to the HttpContext
			httpContext.injector = injector;

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
				remotingResponse = processRequest( params["__x"], context, actionContext );
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
	function processRequest( requestData:String, ctx:Context, actionContext:ActionContext ):String {
		var u = new Unserializer( requestData );
		var path:Array<String> = u.unserialize();
		var args:Array<Dynamic> = u.unserialize();

		var className = path.copy();
		actionContext.handler = this;
		actionContext.action = path[path.length-1];
		actionContext.controller = ctx.objects.get( actionContext.action );
		actionContext.args = args;

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
			return serializedStack + "\n" + serializedException;
		#else
			return '$serializedException';
		#end
	}

	public function toString() return "ufront.handler.RemotingHandler";
}