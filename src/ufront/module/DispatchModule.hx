package ufront.module;

import hxevents.Async;
import ufront.module.IHttpModule;
import ufront.application.*;
import ufront.web.context.*;
import ufront.web.session.IHttpSessionState;
import ufront.auth.*;
import haxe.web.Dispatch.DispatchConfig;
import haxe.web.Dispatch.DispatchError;
import ufront.web.Dispatch;
import hxevents.Async;
import minject.Injector;
import ufront.web.error.*;
import ufront.web.result.*;
import ufront.web.context.*;

/**
	Uses `ufront.web.Dispatch` to match the URL to a controller action and it's parameters.

	@author Jason O'Neil
**/
class DispatchModule implements IHttpModule
{
	var injector:Injector;

	/** The Object (API, Routes or Controller) that Dispatch will check requests against. */
	public var dispatchConfig(default, null) : DispatchConfig;
	
	/** The Dispatch object used **/
	public var dispatch(default, null):Dispatch;

	/** 
		Construct using a dispatchConfig 

		Example usage:

		```
		var routes = new MyRoutes();
		var dispatchConfig = ufront.web.Dispatch.make( routes );
		var dispatchModule = new DispatchModule( dispatchConfig );

		// or, more concisely:
		new DispatchModule( ufront.web.Dispatch.make(new MyRouteOrController()) );
		```
	**/
	public function new( dispatchConfig ) {
		this.dispatchConfig = dispatchConfig;
	}

	/** Initializes a module and prepares it to handle requests. */
	public function init( application:HttpApplication ) : Void {
		application.onDispatch.add( executeDispatchHandler );
		application.onActionExecute.addAsync( executeActionHandler );
		application.onResultExecute.addAsync( executeResultHandler );

		injector = 
			if (Std.is(application, UfrontApplication)) cast(application,UfrontApplication).dispatchInjector
			else application.appInjector;
	}

	function executeDispatchHandler( context:HttpContext ) {
		// Update the contexts
		var actionContext = new ActionContext( context );
		context.actionContext = actionContext;
		
		// Set up the injector 
		var requestInjector = injector.createChildInjector();
		requestInjector.mapValue( HttpContext, context );
		requestInjector.mapValue( HttpRequest, context.request );
		requestInjector.mapValue( HttpResponse, context.response );
		requestInjector.mapValue( IHttpSessionState, context.session );
		requestInjector.mapValue( IAuthHandler, context.auth );
		if (context.auth!=null) requestInjector.mapValue( IAuthUser, context.auth.currentUser );
		requestInjector.mapValue( ActionContext, actionContext );
		requestInjector.mapValue( Array, context.messages, "messages" );

		// Map the specific implementations for auth and session
		requestInjector.mapValue( Type.getClass( context.session ), context.session );
		requestInjector.mapValue( Type.getClass( context.auth ), context.auth );

		// Process the dispatch request
		try {
			var filteredUri = context.getRequestUri();
			var params = context.request.params;
			dispatch = new Dispatch( filteredUri, params, context.request.httpMethod );

			// Listen for when the controller, action and args have been decided so we can set our "context" object up...
			dispatch.onProcessDispatchRequest.add(function() {
				// Update the actionContext
				actionContext.controller = dispatch.controller;
				actionContext.action = dispatch.action;
				actionContext.args = dispatch.arguments;
				
				// Inject into our controller (if it already has been injected, no matter...)
				switch Type.typeof( dispatch.controller ) {
					case TClass( cl ): 
						requestInjector.injectInto( dispatch.controller );
					default:
				}
			});

			// Duplicate routes for each request, in case the object is cached.  
			var controller = dispatchConfig.obj;
			switch Type.typeof( controller ) {
				case TClass( cl ): 
					dispatchConfig.obj = requestInjector.instantiate( cl );
				default:
			}

			dispatch.processDispatchRequest( dispatchConfig );
		} 
		catch ( e:DispatchError ) throw dispatchErrorToHttpError( e )
	}

	function executeActionHandler( context:HttpContext, async:Async ) {

		// Update the Dispatch details (in case a module/middleware changed them)
		dispatch.controller = context.actionContext.controller;
		dispatch.action = context.actionContext.action;
		dispatch.arguments = context.actionContext.args;

		// Execute the result
		try {
			// TODO - make this async...
			var result = dispatch.executeDispatchRequest();
			context.actionResult = createActionResult( result );
			async.completed();
		}
		catch ( e : DispatchError ) {
			// Will be thrown happen if this function is called before dispatch.processDispatchRequest has run
			async.error( dispatchErrorToHttpError(e) );
		}
		catch ( e : Dynamic ) {
			async.error( e );
		}
	}

	function executeResultHandler( context:HttpContext, async:hxevents.Async ) {
		try {
			context.actionResult.executeResult( context.actionContext, async );
		}
		catch ( e: Dynamic ) {
			async.error( e );
		}
	}

	function dispatchErrorToHttpError( e : DispatchError ) {
		return switch ( e ) {
			case DENotFound( part ): new PageNotFoundError();
			case DEInvalidValue: new BadRequestError();
			case DEMissing: new PageNotFoundError();
			case DEMissingParam( _ ): new BadRequestError();
			case DETooManyValues: new PageNotFoundError();
		}
	}

	public static function createActionResult( returnValue:Dynamic ):ActionResult {
		if ( returnValue==null ) {
			return new EmptyResult();
		}
		else {
			var actionReturnValue = Types.as( returnValue, ActionResult );
			if ( actionReturnValue==null ) {
				actionReturnValue = new ContentResult(Std.string(returnValue), null);
			}
			return actionReturnValue;
		}
	}

	/** Disposes of the resources (other than memory) that are used by the module. */
	public function dispose() : Void {
		dispatchConfig = null;
		dispatch = null;
	}
}