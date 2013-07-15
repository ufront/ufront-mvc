package ufront.application;

import haxe.ds.StringMap;
import ufront.application.HttpApplication;
import haxe.web.Dispatch.DispatchConfig;
import ufront.web.context.HttpContext;
import ufront.web.UfrontConfiguration;
import ufront.web.url.filter.*;
import ufront.module.*;
using DynamicsT;

/**
	A standard Ufront Application.  This extends HttpApplication and provides:

	- Routing with `ufront.modules.DispatchModule`
	- Tracing, to console or logfile, based on your `ufront.web.UfrontConfiguration`

	And in future

	- easily add remoting module and API context
	- easily cache requests

	@author Jason O'Neil
	@author Andreas Soderlund
	@author Franco Ponticelli
**/

class UfrontApplication extends HttpApplication
{
	/**
		Initialize a new UfrontApplication with the given configurations.

		@param	?dispathConfig		Routes for the application.  Must be `DispatchConfig`.
		@param	?controllerPackage	Package for the controllers. If null, the current application package will be used.
		@param	?httpContext		Context for the request, if null a web context will be created. Useful for unit testing.
		
		Example usage: 

		```
		var routes = new MyRoutes();
		var dispatchConfig = ufront.web.Dispatch.make( routes );
		var configuration = new UfrontConfiguration(false); 
		var ufrontApp = new UfrontApplication( dispatchConfig, configuration );
		ufrontApp.execute();
		```
	**/
	public function new(dispatchConfig : DispatchConfig, ?configuration : UfrontConfiguration, ?httpContext : HttpContext) {
		if (configuration == null)
			configuration = new UfrontConfiguration();

		super(httpContext);

		// Add URL filter for basePath, if it is not "/"
		var path = Strings.trim(configuration.basePath, "/");
		if (path.length>0)
			httpContext.addUrlFilter(new DirectoryUrlFilter(path));

		// Unless mod_rewrite is used, filter out index.php/index.n from the urls.
		if (configuration.urlRewrite!=true)
			httpContext.addUrlFilter(new PathInfoUrlFilter());

		// Add a DispatchModule which will deal with all of our routing and executing contorller actions and results
		modules.add( new DispatchModule(dispatchConfig) );

		// add debugging modules
		modules.add(new ErrorModule());
		if (!configuration.disableBrowserTrace) modules.add(new TraceToBrowserModule());
		if (null!=configuration.logFile) modules.add(new TraceToFileModule(configuration.logFile));

		// Set up custom trace.  Will trace all ITraceModules found, or use the default as a fallback
		var old = haxe.Log.trace;
		haxe.Log.trace = function(msg : Dynamic, ?pos : haxe.PosInfos) {
			var found = false;
			for(module in modules) {
				var tracer = Types.as(module, ITraceModule);
				if(null != tracer) {
					found = true;
					tracer.trace(msg, pos);
				}
			}
			if(!found)
				old(msg, pos);
		}
	}
}