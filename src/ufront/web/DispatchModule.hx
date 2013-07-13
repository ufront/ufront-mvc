package ufront.web;

#if neko 
import neko.Web;
#elseif php 
import neko.Web;
#end
import ufront.web.error.PageNotFoundError;
import ufront.web.HttpApplication;
import ufront.web.routing.RequestContext;
import ufront.web.IHttpHandler;
import ufront.web.IHttpModule;
import haxe.web.Dispatch.DispatchConfig;
import haxe.web.Dispatch.DispatchError;
import ufront.web.UfrontDispatch;
import ufront.web.mvc.*;

/**
 * Gets an IHttpHandler from the routing and executes it in the HttpApplication context.
 * Uses ufront.web.UfrontDispatch to match the URL to a controller action and it's parameters.
 * @author Jason O'Neil
 */
class DispatchModule implements IHttpModule
{
	/** Gets the collection of defined routes for the Ufront application. */
	public var dispatchConfig(default, null) : DispatchConfig;

	var httpHandler : IHttpHandler;

	public function new(dispatchConfig)
	{
		this.dispatchConfig = dispatchConfig;
	}

	/** Initializes a module and prepares it to handle requests. */
	public function init(application : HttpApplication) : Void
	{
		// application.onPostMapRequestHandler.addAsync(executeHttpHandler);
		application.onPostMapRequestHandler.add(executeHttpHandler);
	}

	// function executeHttpHandler(application : HttpApplication, async : hxevents.Async)
	function executeHttpHandler(application : HttpApplication)
	{
		var httpContext = application.httpContext;

		try 
		{
			var d = new UfrontDispatch( httpContext.request.uri, Web.getParams(), httpContext );
			if ( Std.is(dispatchConfig.obj, SimpleController) ) {
				var firstController:SimpleController = dispatchConfig.obj;
				firstController.setupControllerContext( httpContext );
			}
			var actionReturn = d.runtimeReturnDispatch( dispatchConfig );
			var result = createActionResult( actionReturn.result );
			result.executeResult( actionReturn.controllerContext );
		} 
		catch ( e : DispatchError )
		{
			switch ( e )
			{
				case DENotFound( part ): throw new PageNotFoundError();
				case DEInvalidValue: throw "Dispatch: Invalid Value";
				case DEMissing: throw "Dispatch: Missing";
				case DEMissingParam( p ): throw "Dispatch: Missing Param " + p;
				case DETooManyValues: throw "Dispatch: Too Many Values";
			}
		}
	}

	static function createActionResult(actionReturnValue : Dynamic) : ActionResult
	{
		if (actionReturnValue == null)
			return new EmptyResult();

		if (Std.is(actionReturnValue, ActionResult)) return cast actionReturnValue;
		return new ContentResult(Std.string(actionReturnValue), null);
	}

	/** Disposes of the resources (other than memory) that are used by the module. */
	public function dispose() : Void
	{
		dispatchConfig = null;
		httpHandler = null;
	}
}