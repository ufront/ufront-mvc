package ufront.web;

#if neko 
import neko.Web;
#else if php 
import neko.Web;
#end
import ufront.web.error.PageNotFoundError;
import ufront.web.HttpApplication;
import ufront.web.routing.RequestContext;
import ufront.web.IHttpHandler;
import ufront.web.IHttpModule;
import ufront.web.Dispatch;

/**
 * Gets an IHttpHandler from the routing and executes it in the HttpApplication context.
 * Uses ufront.web.Dispatch to match the URL to a controller action and it's parameters.
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
			var d = new Dispatch( httpContext.request.uri, Web.getParams() );
			d.runtimeDispatch( dispatchConfig );
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
		
		// How can I pass the HTTP context or request context to the controller still?
		// httpHandler.processRequest(application.httpContext, async);
	}

	/** Disposes of the resources (other than memory) that are used by the module. */
	public function dispose() : Void
	{
		dispatchConfig = null;
		httpHandler = null;
	}
}