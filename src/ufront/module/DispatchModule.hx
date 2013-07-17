package ufront.module;

import ufront.module.IHttpModule;
import ufront.application.HttpApplication;
import haxe.web.Dispatch.DispatchConfig;
import haxe.web.Dispatch.DispatchError;
import ufront.web.Dispatch;
import ufront.web.error.*;
import ufront.web.result.*;
import ufront.web.context.*;

/**
	Uses `ufront.web.Dispatch` to match the URL to a controller action and it's parameters.

	@author Jason O'Neil
**/
class DispatchModule implements IHttpModule
{
	/** The Object (API, Routes or Controller) that Dispatch will check requests against. */
	public var dispatchConfig(default, null) : DispatchConfig;
	
	/** The Dispatch object used **/
	var dispatch:Dispatch;

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
		// TODO: make both of these async... may require some cleverness in the controllers?
		application.onDispatch.add( executeDispatchHandler );
		application.onActionExecute.add( executeActionHandler );
		application.onResultExecute.add( executeResultHandler );
	}

	// function executeDispatch(application : HttpApplication, async : hxevents.Async)
	function executeDispatchHandler( application:HttpApplication ) {
		var httpContext = application.httpContext;
		try {
			var filteredUri = httpContext.getRequestUri();
			var params = httpContext.request.params.toStringMap();
			dispatch = new Dispatch( filteredUri, params, httpContext );
			dispatch.processDispatchRequest( dispatchConfig );
			httpContext.response.actionContext = new ActionContext( httpContext, dispatch.controller, dispatch.action, dispatch.arguments );
		} 
		catch ( e : DispatchError ) {
			switch ( e ) {
				case DENotFound( part ): throw new PageNotFoundError();
				case DEInvalidValue: throw new BadRequestError();
				case DEMissing: throw new PageNotFoundError();
				case DEMissingParam( _ ): throw new BadRequestError();
				case DETooManyValues: throw new PageNotFoundError();
			}
		}
	}

	function executeActionHandler( application:HttpApplication ) {
		// Get the contexts
		var httpContext = application.httpContext;
		var actionContext = httpContext.response.actionContext;

		// Update the Dispatch details (in case a module/middleware changed them)
		dispatch.controller = actionContext.controller;
		dispatch.action = actionContext.action;
		dispatch.arguments = actionContext.args;

		// Execute the result
		try {
			var result = dispatch.executeDispatchRequest();
			httpContext.response.actionResult = createActionResult( result );
		} 
		catch ( e : DispatchError ) {
			// Will be thrown happen if this function is called before dispatch.processDispatchRequest has run
			throw new BadRequestError();
		}
	}

	function executeResultHandler( application:HttpApplication ) {
		var response = application.httpContext.response;
		response.actionResult.executeResult( response.actionContext );
	}

	function createActionResult(returnValue : Dynamic) : ActionResult {
		if (returnValue == null) {
			return new EmptyResult();
		}
		else {
			var actionReturnValue = Types.as( returnValue, ActionResult );
			if (actionReturnValue == null) {
				actionReturnValue =  new ContentResult(Std.string(actionReturnValue), null);
			}
			return actionReturnValue;
		}
	}

	/** Disposes of the resources (other than memory) that are used by the module. */
	public function dispose() : Void {
		dispatchConfig = null;
	}
}