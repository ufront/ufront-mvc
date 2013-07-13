package ufront.web.mvc;

import ufront.web.DirectoryUrlFilter;
import ufront.web.HttpApplication;
import ufront.web.HttpContext;
import ufront.web.PathInfoUrlFilter;
import ufront.web.AppConfiguration;
import ufront.web.module.ErrorModule;
import ufront.web.module.ITraceModule;
import ufront.web.module.TraceToBrowserModule;
import ufront.web.module.TraceToFileModule;
import ufront.web.Dispatch;
import ufront.web.DispatchModule;
import ufront.remoting.RemotingApiContext;
import haxe.ds.StringMap;
import haxe.web.Dispatch.DispatchConfig;
using DynamicsT;

/**
 * ...
 * @author Andreas Soderlund
 * @author Franco Ponticelli
 * @author Jason O'Neil
 *
 * Uses Dispatch rather than the MVC routing system.
 */

class UfrontApplication extends HttpApplication
{
	public var routeModule(default, null) : DispatchModule;
	// public var haxeRemotingModule(default, null) : HaxeRemotingModule;

	/**
	 * Initializes a new instance of the MvcApplication class.
	 * @param	?routes				 Routes object for the application.
	 * @param	?serverConfiguration Server-specific settings like mod_rewrite. If null, class defaults will be used.
	 * @param	?httpContext		 Context for the request, if null a web context will be created. Could be useful for unit testing.
	 */
	public function new(?routes : DispatchConfig, ?remotingContext : RemotingApiContext, ?configuration : AppConfiguration, ?httpContext : HttpContext)
	{
		if (configuration == null)
			configuration = new AppConfiguration();

		if (routes != null)
		{
			if (httpContext == null)
			{
				httpContext = HttpContext.createWebContext();

				// if base path is different from "/" than work in a subfolder
				var path = Strings.trim(configuration.basePath, "/");
				if (path.length > 0)
					httpContext.addUrlFilter(new DirectoryUrlFilter(path));

				// Unless mod_rewrite is used, filter out index.php/index.n from the urls.
				if(configuration.modRewrite != true)
					httpContext.addUrlFilter(new PathInfoUrlFilter());
			}
		}

		super(httpContext);

		if (routes != null)
		{
			// Add a UrlRoutingModule to the application, to set up the routing.
			modules.add(routeModule = new DispatchModule(routes));
		}

		if (remotingContext != null)
		{
			// modules.add(haxeRemotingModule = new HaxeRemotingModule(remotingContext));
		}

		// add debugging modules
		modules.add(new ErrorModule());

		if(!configuration.disableBrowserTrace)
		{
			modules.add(new TraceToBrowserModule());
		}

		if(null != configuration.logFile)
		{
			modules.add(new TraceToFileModule(configuration.logFile));
		}

		var old = haxe.Log.trace;
		haxe.Log.trace = function(msg : Dynamic, ?pos : haxe.PosInfos)
		{
			var found = false;
			for(module in modules)
			{
				var tracer = Types.as(module, ITraceModule);
				if(null != tracer)
				{
					found = true;
					tracer.trace(msg, pos);
				}
			}
			if(!found)
				old(msg, pos);
		}
	}
}