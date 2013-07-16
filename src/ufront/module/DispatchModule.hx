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
	/** Gets the collection of defined routes for the Ufront application. */
	public var dispatchConfig(default, null) : DispatchConfig;

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
		application.onDispatchHandler.add( executeDispatch );
		application.onRequestResultExecute.add( executeDispatch );
	}

	// function executeDispatch(application : HttpApplication, async : hxevents.Async)
	function executeDispatch( application:HttpApplication ) {
		var httpContext = application.httpContext;
		try {
			var filteredUri = httpContext.getRequestUri();
			var params = httpContext.request.params.toStringMap();
			var d = new Dispatch( filteredUri, params, httpContext );
			httpContext.response.actionResult = createActionResult( d.runtimeReturnDispatch(dispatchConfig) );
			httpContext.response.actionResultContext = new ActionResultContext( httpContext, d.controller, d.action );
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

	function onRequestResultHandler( application:HttpApplication ) {
		var actionResult = application.httpContext.response.actionResult;
		var actionResultContext = application.httpContext.response.actionResultContext;
		actionResult.executeResult( actionResultContext );
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