package ufront.app;

#if macro
	import haxe.macro.Expr;
#else
	import ufront.app.HttpApplication;
	import haxe.ds.StringMap;
	import minject.Injector;
	import haxe.web.Dispatch.DispatchConfig;
	import ufront.log.*;
	import ufront.api.UFApiContext;
	import ufront.handler.*;
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
#end

/**
	A standard Ufront Application.  This extends HttpApplication and provides:

	- Routing with `ufront.module.DispatchModule`
	- Easily add remoting API context and initiate the `ufront.api.RemotingModule`
	- Tracing, to console, logfile or remoting call, based on your `ufront.web.UfrontConfiguration`

	And in future

	- easily cache requests
	
	Things we inject:

	- `app.injector`
		- A copy of the `Injector` itself
		- The `UFSessionFactory` provided in the configuration
		- The `UFAuthFactory` provided in the configuration
		- A String name `scriptDirectory`, containing the path to the current module.
		- A String name `contentDirectory`, containing a path to ufront's specified content directory.
	- `app.dispatchHandler.injector`
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
	#if !macro 

		/** 
			The configuration that was used when setting up the application.
			
			This is set during the constructor.  Changing values of this object is not guaranteed to have any effect.
		**/
		public var configuration(default,null):UfrontConfiguration;
		
		/** 
			The dispatch handler used for this application.
			
			This is mostly made accessible for unit testing and logging purposes.  You are unlikely to need to access it for anything else.
		**/
		public var dispatchHandler(default,null):DispatchHandler;
		
		/** 
			The remoting handler used for this application.
			
			It is automatically set up if a `UFApiContext` class is supplied
		**/
		public var remotingHandler(default,null):RemotingHandler;

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

			dispatchHandler = new DispatchHandler();
			remotingHandler = new RemotingHandler();
			
			// Map some default injector rules
			
			for ( controller in configuration.controllers ) 
				dispatchHandler.injector.mapClass( controller, controller );
			
			for ( api in configuration.apis ) {
				remotingHandler.injector.mapClass( api, api );
				dispatchHandler.injector.mapClass( api, api );
			}

			// Set up handlers and middleware
			addRequestMiddleware( configuration.requestMiddleware );
			addRequestHandler( [remotingHandler,dispatchHandler] );
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
		}

		/**
			Execute the current request.

			If `httpContext` is not defined, `HttpContext.create()` will be used, with your session data being sent through.

			The first time this runs, it will map injections for the Strings "scriptDirectory" and "contentDirectory", so that they can be used by various middleware / handlers / actions / views etc.
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
			if ( configuration.viewEngine!=null ) {
				injector.injectInto( configuration.viewEngine );
				inject( UFViewEngine, configuration.viewEngine );
			}
		}

		/**
			Shortcut for `remotingHandler.loadApi()`

			Returns itself so chaining is enabled
		**/
		public inline function loadApi( apiContext:Class<UFApiContext> ) {
			remotingHandler.loadApi( apiContext );
			return this;
		}

		/**
			Shortcut for `dispatchHandler.loadApi()`

			Returns itself so chaining is enabled
		**/
		public inline function loadRoutesConfig( dispatchConfig:DispatchConfig ) {
			dispatchHandler.loadRoutesConfig( dispatchConfig );
			return this;
		}

	#else 
		/**
			Shortcut for `dispatchHandler.loadRoutes()`

			Returns itself so chaining is enabled
		**/
			macro public function loadRoutes( ethis:Expr, obj:ExprOf<{}> ):ExprOf<UfrontApplication> {
				var dispatchConf:Expr = ufront.web.Dispatch.makeConfig( obj );
				return macro $ethis.loadRoutesConfig( $dispatchConf );
			}
	#end
}