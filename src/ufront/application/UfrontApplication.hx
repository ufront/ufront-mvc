package ufront.application;

import haxe.ds.StringMap;
import ufront.application.HttpApplication;
import haxe.web.Dispatch.DispatchConfig;
import ufront.web.context.HttpContext;
import ufront.web.UfrontConfiguration;
import ufront.web.url.filter.*;
import ufront.module.*;

/**
	A standard Ufront Application.  This extends HttpApplication and provides:

	- Routing with `ufront.module.DispatchModule`
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
		The configuration that was used when setting up the application.
		
		This is set during the constructor.  Changing values of this object is not guaranteed to have any effect.
	**/
	public var configuration(default,null):UfrontConfiguration;
	
	/** 
		The dispatch module used for this application.
		
		This is mostly made accessible for unit testing and logging purposes.  You are unlikely to need to access it for anything else.
	**/
	public var dispatchModule(default,null):DispatchModule;
	
	/** 
		The error module used for this application.
		
		This is made accessible so that you can configure the error module or add new error handlers.
	**/
	public var errorModule(default,null):ErrorModule;

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
	public function new( dispatchConfig:DispatchConfig, ?conf:UfrontConfiguration ) {
		this.configuration = (conf!=null) ? conf : new UfrontConfiguration();

		super();

		// Add a DispatchModule which will deal with all of our routing and executing contorller actions and results
		dispatchModule = new DispatchModule(dispatchConfig);
		modules.add( dispatchModule );

		// add debugging modules
		errorModule = new ErrorModule();
		modules.add( errorModule );
		if ( !configuration.disableBrowserTrace ) 
			modules.add( new TraceToBrowserModule() );
		if ( null!=configuration.logFile ) 
			modules.add( new TraceToFileModule(configuration.logFile) );
		
		// Add URL filter for basePath, if it is not "/"
		var path = Strings.trim( configuration.basePath, "/" );
		if ( path.length>0 )
			super.addUrlFilter( new DirectoryUrlFilter(path) );

		// Unless mod_rewrite is used, filter out index.php/index.n from the urls.
		if ( configuration.urlRewrite!=true )
			super.addUrlFilter( new PathInfoUrlFilter() );

		// Set up custom trace.  Will trace all ITraceModules found, or use the default as a fallback
		var old = haxe.Log.trace;
		var allModules = modules; // workaround for weird neko glitch when you have no trace modules...
		haxe.Log.trace = function(msg:Dynamic, ?pos:haxe.PosInfos) {
			var found = false;
			for( module in allModules ) {
				var tracer = Types.as( module, ITraceModule );
				if(null != tracer) {
					found = true;
					tracer.trace( msg, pos );
				}
			}
			if( !found )
				old( msg, pos );
		}
	}

	override public function execute( ?httpContext:HttpContext ) {
		
		// Set up HttpContext for the request
		if ( httpContext==null ) httpContext = HttpContext.createWebContext( urlFilters );
		else httpContext.setUrlFilters( urlFilters );

		// execute
		super.execute( httpContext );
	}
}