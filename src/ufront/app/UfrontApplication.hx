package ufront.app;

import ufront.app.HttpApplication;
import haxe.ds.StringMap;
import minject.Injector;
import ufront.log.*;
import ufront.api.UFApiContext;
import ufront.handler.*;
import ufront.view.TemplatingEngines;
import ufront.view.UFViewEngine;
import ufront.web.context.HttpContext;
import ufront.web.Dispatch;
import ufront.web.session.*;
import ufront.web.url.filter.*;
import ufront.web.Controller;
import ufront.web.UfrontConfiguration;
import ufront.web.session.UFHttpSessionState;
import ufront.auth.*;
import ufront.api.UFApi;
#if ufront_easyauth
	import ufront.auth.EasyAuth;
#end
using Objects;

/**
	A standard Ufront Application.  This extends HttpApplication and provides:

	- Routing with `ufront.handler.MVCHandler`
	- Easily add remoting API context and initiate the `ufront.handler.RemotingHandler`
	- Tracing, to console, logfile or remoting call, based on your `ufront.web.UfrontConfiguration`

	And in future:

	- easily cache requests
	
	Ufront uses `minject.Injector` for dependency injection, and `UfrontApplication` adds several things to each injector, depending on the context.
	For each context, we map the following items:

	- `app.injector`
		- A copy of the `Injector` itself
		- The `UFSessionFactory` provided in the configuration
		- The `UFAuthFactory` provided in the configuration
		- A String name `scriptDirectory`, containing the path to the current module.
		- A String name `contentDirectory`, containing a path to ufront's specified content directory.
	- `app.mvcHandler.injector`
		- All of the mappings from `app.injector`
		- All of the controllers specified in your configuration (by default: all of them)
		- All of the APIs specified in your configuration (by default: all of them)
	- `app.remotingHandler.injector`
		- All of the mappings from `app.injector`
		- All of the APIs specified in your configuration (by default: all of them)
	
	Futher injections may take place in various middleware / handlers also.

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
		The dispatch handler used for this application.
		
		This is mostly made accessible for unit testing and logging purposes.  You are unlikely to need to access it for anything else.
	**/
	public var mvcHandler(default,null):MVCHandler;
	
	/** 
		The remoting handler used for this application.
		
		It is automatically set up if a `UFApiContext` class is supplied
	**/
	public var remotingHandler(default,null):RemotingHandler;
	
	/** 
		The view engine being used with this application
		
		It is configured using the `viewEngine` property on your `UfrontConfiguration`.
	**/
	public var viewEngine(default,null):UFViewEngine;

	/**
		Initialize a new UfrontApplication with the given configurations.

		@param	?optionsIn		Options for UfrontApplication.  See `DefaultUfrontConfiguration` for details.  Any missing values will imply defaults should be used.
		
		Example usage: 

		```
		var routes = new MyRoutes();
		var dispatchConfig = ufront.web.Dispatch.make( routes );
		var configuration = new UfrontConfiguration(false); 
		var ufrontApp = new UfrontApplication({
			dispatchConfig: Dispatch.make( new MyRoutes() );
		} , configuration, myapp.Api );
		ufrontApp.execute();
		```

		This will redirect `haxe.Log.trace` to a local function which adds trace messages to the `messages` property of this application.  You will need to use an appropriate tracing module to view these.
	**/
	public function new( ?optionsIn:UfrontConfiguration ) {
		super();

		configuration = DefaultUfrontConfiguration.get();
		configuration.merge( optionsIn );

		mvcHandler = new MVCHandler();
		remotingHandler = new RemotingHandler();

		mvcHandler.indexController = configuration.indexController;

		if ( null!=configuration.remotingApi ) 
			loadApi( configuration.remotingApi );
		
		// Map some default injector rules
		
		for ( controller in configuration.controllers ) 
			mvcHandler.injector.mapClass( controller, controller );
		
		for ( api in configuration.apis ) {
			remotingHandler.injector.mapSingleton( api );
			mvcHandler.injector.mapSingleton( api );
		}

		// Set up handlers and middleware
		addRequestMiddleware( configuration.requestMiddleware );
		addRequestHandler( [remotingHandler,mvcHandler] );
		addResponseMiddleware( configuration.responseMiddleware );
		addErrorHandler( configuration.errorHandlers );
		
		// Add log handlers according to configuration
		if ( !configuration.disableBrowserTrace ) {
			addLogHandler( new BrowserConsoleLogger() );
			addLogHandler( new RemotingLogger() );
		}
		if ( null!=configuration.logFile ) {
			addLogHandler( new FileLogger(configuration.logFile) );
		}

		// Add URL filter for basePath, if it is not "/"
		var path = Strings.trim( configuration.basePath, "/" );
		if ( path.length>0 )
			super.addUrlFilter( new DirectoryUrlFilter(path) );

		// Unless mod_rewrite is used, filter out index.php/index.n from the urls.
		if ( configuration.urlRewrite!=true )
			super.addUrlFilter( new PathInfoUrlFilter() );

		// Save the session / auth factories for later, when we're building requests
		inject( UFSessionFactory, configuration.sessionFactory );
		inject( UFAuthFactory, configuration.authFactory );

		// Set up the view engine
		this.viewEngine = configuration.viewEngine;
	}

	/**
		Execute the current request.

		If `httpContext` is not defined, `HttpContext.create()` will be used, with your session data being sent through.

		The first time this runs, `initOnFirstExecute()` will be called, which runs some more initialization that requires the HttpContext to be ready before running.
	**/
	override public function execute( ?httpContext:HttpContext ) {
		// Set up HttpContext for the request
		if ( httpContext==null ) httpContext = HttpContext.create( injector, urlFilters, configuration.contentDirectory );

		if ( firstRun ) initOnFirstExecute( httpContext );

		// execute
		return super.execute( httpContext );
	}

	static var firstRun = true;
	function initOnFirstExecute( httpContext:HttpContext ) {
		firstRun = false;
		
		inject( String, httpContext.request.scriptDirectory, "scriptDirectory" );
		inject( String, httpContext.contentDirectory, "contentDirectory" );
		
		// Make the UFViewEngine available (and inject into it, in case it needs anything)
		if ( viewEngine!=null ) {
			injector.injectInto( viewEngine );
			inject( UFViewEngine, viewEngine );
		}
	}

	/**
		Shortcut for `remotingHandler.loadApi()`

		Returns itself so chaining is enabled.
	**/
	public inline function loadApi( apiContext:Class<UFApiContext> ) {
		remotingHandler.loadApi( apiContext );
		return this;
	}

	/**
		Add support for a templating engine to your view engine.

		Some ready-to-go templating engines are included `ufront.view.TemplatingEngines`.
	**/
	public inline function addTemplatingEngine( engine:TemplatingEngine ) {
		viewEngine.addTemplatingEngine( engine );
		return this;
	}

	override public function inject<T>( cl:Class<T>, ?val:T, ?cl2:Class<T>, ?singleton=false, ?named:String ):UfrontApplication {
		return cast super.inject( cl, val, cl2, singleton, named );
	}
}