package ufront.app;

import ufront.app.HttpApplication;
import haxe.ds.StringMap;
import minject.Injector;
import ufront.log.*;
import ufront.api.*;
import ufront.handler.*;
import ufront.view.TemplatingEngines;
import ufront.view.UFViewEngine;
import ufront.web.context.HttpContext;
import ufront.web.session.*;
import ufront.web.url.filter.*;
import ufront.web.Controller;
import ufront.web.HttpError;
import ufront.app.UfrontConfiguration;
import ufront.web.session.UFHttpSession;
import ufront.auth.*;
using tink.CoreApi;
using ufront.core.InjectionTools;
using StringTools;

/**
A standard Ufront Application for executing requests on the server.

This extends `HttpApplication` for a "batteries included" way to set up your server-side Ufront app.

Out of the box it provides:

- The `MVCHandler` for macro powered routing and a model / view / controller style of responding to requests.
- The `RemotingHandler` for automatic Haxe powered remoting APIs.
- Tracing to a browser console during a web request or a remoting call, based on your `UfrontConfiguration`.
- Default URL Filtering rules, based on your `UfrontConfiguration`.

Ufront uses `minject.Injector` for dependency injection, and `UfrontApplication` adds several things to the injector, depending on your configuration:

- All of the controllers specified in your configuration (By default: every `Controller` imported into your app).
- All of the APIs specified in your configuration (by default: every `UFApi` imported into your app).
- The `UFAsyncApi` versions of any `UFApi` classes injected above.
- A singleton of the `UFViewEngine` specified in your `UfronConfiguration`.
- The implementation of `UFHttpSession` you chose in your `UfrontConfiguration`, to be instantiated on each request.
- The implementation of `UFAuthHandler` you chose in your `UfrontConfiguration`, to be instantiated on each request.
- A String named `viewPath` for the path to your view folder, specified in your `UfrontConfiguration`.
- A String name `scriptDirectory`, containing the path to the directory the current app is located in.
- A String name `contentDirectory`, containing the path to the content directory specified in your configuration.

Futher injections may take place in various middleware / handlers also.
**/
class UfrontApplication extends HttpApplication {
	/**
	The configuration that was used when setting up the application.

	This is set during the constructor.  Changing values of this object is not likely to have any effect.
	**/
	public var configuration(default,null):UfrontConfiguration;

	/**
	The MVC handler used for this application.

	This is made accessible for unit testing and logging purposes, you are unlikely to need to access it directly for anything else.
	**/
	public var mvcHandler(default,null):MVCHandler;

	/**
	The remoting handler used for this application.

	It is automatically set up if a `UFApiContext` class is supplied.

	This is made accessible for unit testing and logging purposes, you are unlikely to need to access it directly for anything else.
	**/
	public var remotingHandler(default,null):RemotingHandler;

	/**
	The view engine being used with this application.

	It is configured using the `viewEngine` property on your `UfrontConfiguration`.
	**/
	public var viewEngine(default,null):UFViewEngine;

	/**
	Initialize a new UfrontApplication with the given configurations.

	@param ?optionsIn Options for UfrontApplication.  See `DefaultUfrontConfiguration` for details.  Any missing values will imply defaults should be used.
	**/
	public function new( ?optionsIn:UfrontConfiguration ) {
		super();

		configuration = DefaultUfrontConfiguration.get();
		for ( field in Reflect.fields(optionsIn) ) {
			var value = Reflect.field( optionsIn, field );
			Reflect.setField( configuration, field, value );
		}

		// Set up our handlers, and the injections needed for them.
		mvcHandler = new MVCHandler( configuration.indexController );
		remotingHandler = new RemotingHandler();
		if ( configuration.remotingApi!=null ) {
			remotingHandler.loadApiContext( configuration.remotingApi );
		}

		// Map some default injector rules
		for ( controller in configuration.controllers ) {
			injector.mapRuntimeTypeOf( controller ).toClass( controller );
		}
		for ( api in configuration.apis ) {
			injector.mapRuntimeTypeOf( api ).toClass( api );
			var asyncApi = UFAsyncApi.getAsyncApi( api );
			if ( asyncApi!=null )
				injector.mapRuntimeTypeOf( asyncApi ).toClass( asyncApi );
		}

		// Set up handlers and middleware
		addRequestMiddleware( configuration.requestMiddleware );
		addRequestHandler( [remotingHandler,mvcHandler] );
		addResponseMiddleware( configuration.responseMiddleware );
		addErrorHandler( configuration.errorHandlers );

		// Add log handlers according to configuration
		if ( !configuration.disableServerTrace ) {
			addLogHandler( new ServerConsoleLogger() );
		}
		if ( !configuration.disableBrowserTrace ) {
			addLogHandler( new BrowserConsoleLogger() );
			addLogHandler( new RemotingLogger() );
		}
		if ( null!=configuration.logFile ) {
			addLogHandler( new FileLogger(configuration.logFile) );
		}

		// Add URL filter for basePath, if it is not "/"
		var path = configuration.basePath;
		if (path.endsWith("/")) path = path.substr(0, path.length-1);
		if (path.startsWith("/")) path = path.substr(1);
		if ( path.length>0 )
			super.addUrlFilter( new DirectoryUrlFilter(path) );

		// Unless mod_rewrite is used, filter out index.php/index.n from the urls.
		if ( configuration.urlRewrite!=true )
			super.addUrlFilter( new PathInfoUrlFilter() );

		// Save the session / auth factories for later, when we're building requests
		if (configuration.sessionImplementation!=null) {
			injector.map( UFHttpSession ).toClass( configuration.sessionImplementation );
			injector.mapRuntimeTypeOf( configuration.sessionImplementation ).toClass( configuration.sessionImplementation );
		}
		if (configuration.authImplementation!=null) {
			injector.map( UFAuthHandler ).toClass( configuration.authImplementation );
			injector.mapRuntimeTypeOf( configuration.authImplementation ).toClass( configuration.authImplementation );
		}

		// Set up the view engine, add it to the injector as a singleton, under both "UFViewEngine" and the implementation type.
		if ( configuration.viewEngine!=null ) {
			injector.map( String, "viewPath" ).toValue( configuration.viewPath );
			injector.map( UFViewEngine ).toSingleton( configuration.viewEngine );
			injector.mapRuntimeTypeOf( configuration.viewEngine ).toSingleton( injector.getValue(UFViewEngine) );
		}

		if ( configuration.contentDirectory!=null )
			setContentDirectory( configuration.contentDirectory );

		if ( configuration.defaultLayout!=null )
			injector.map( String, "defaultLayout" ).toValue( configuration.defaultLayout );

		#if ufront_ufadmin
			CompileTime.importPackage( "ufront.ufadmin.modules" ); // Ensure all ufront admin controllers are loaded.
			if ( configuration.adminModules!=null ) {
				injector.injectValue( List, Lambda.list(configuration.adminModules), "adminModules" );
			}
		#end

		for ( te in configuration.templatingEngines )
			addTemplatingEngine( te );
	}

	/**
	Execute the current request.

	The first time this runs, `this.initOnFirstExecute()` will be called, which runs some more initialization that requires the HttpContext to be ready before running.
	**/
	override public function execute( httpContext:HttpContext ):Surprise<Noise,Error> {
		HttpError.throwIfNull( httpContext, "httpContext" );

		if ( firstRun )
			initOnFirstExecute( httpContext );

		// execute
		return super.execute( httpContext );
	}

	var firstRun = true;
	function initOnFirstExecute( httpContext:HttpContext ):Void {
		firstRun = false;
		injector.map( String, "scriptDirectory" ).toValue( httpContext.request.scriptDirectory );
		injector.map( String, "contentDirectory" ).toValue( httpContext.contentDirectory );

		// Add our templating engines to the UFViewEngine
		if ( configuration.viewEngine!=null ) {
			try {
				this.viewEngine = injector.getValue( UFViewEngine );
				for ( te in appTemplatingEngines ) {
					viewEngine.addTemplatingEngine( te );
				}
			}
			catch (e:Dynamic) {
				httpContext.ufWarn( 'Failed to load view engine ${Type.getClassName(configuration.viewEngine)}: $e' );
			}
		}
	}

	/** Shortcut for `remotingHandler.loadApiContext()`. See `RemotingHandler.loadApiContext()` for details. **/
	public inline function loadApiContext( apiContext:Class<UFApiContext> ):UfrontApplication {
		remotingHandler.loadApiContext( apiContext );
		return this;
	}

	var appTemplatingEngines = new List();
	/** Add support for a templating engine to your view engine. **/
	public function addTemplatingEngine( engine:TemplatingEngine ):UfrontApplication {
		appTemplatingEngines.add( engine );
		if ( viewEngine!=null )
			viewEngine.addTemplatingEngine( engine );
		return this;
	}
}
