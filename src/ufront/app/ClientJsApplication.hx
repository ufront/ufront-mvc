package ufront.app;

import ufront.web.UfrontClientConfiguration;
import ufront.web.context.HttpContext;
import ufront.web.session.*;
import ufront.auth.*;
import ufront.view.*;
import ufront.handler.*;
import ufront.log.*;
import pushstate.PushState;
import thx.core.Strings;
import ufront.web.url.filter.*;

class ClientJsApplication extends HttpApplication {
	/**
		The configuration that was used when setting up the client application.

		This is set during the constructor.  Changing values of this object is not guaranteed to have any effect.
	**/
	public var configuration(default,null):UfrontClientConfiguration;

	/**
		The dispatch handler used for this application.

		This is mostly made accessible for unit testing and logging purposes.  You are unlikely to need to access it for anything else.
	**/
	public var mvcHandler(default,null):MVCHandler;

	/**
		The view engine being used with this application

		It is configured using the `viewEngine` property on your `UfrontConfiguration`.
	**/
	public var viewEngine(default,null):UFViewEngine;

	public function new( optionsIn:UfrontClientConfiguration ) {
		super();

		configuration = DefaultUfrontClientConfiguration.get();
		for ( field in Reflect.fields(optionsIn) ) {
			var value = Reflect.field( optionsIn, field );
			Reflect.setField( configuration, field, value );
		}

		// Set up our handlers, and the injections needed for them.
		mvcHandler = new MVCHandler( configuration.indexController );

		// Map some default injector rules
		for ( controller in configuration.controllers ) {
			inject( controller );
		}
		for ( api in configuration.apis ) {
			inject( api );
			// TODO: Inject Async versions of APIs.
		}
		// TODO: inject API Proxies, both sync and async versions.

		// Set up handlers and middleware
		addRequestMiddleware( configuration.requestMiddleware );
		addRequestHandler( [mvcHandler] );
		addResponseMiddleware( configuration.responseMiddleware );
		addErrorHandler( configuration.errorHandlers );

		// Add log handlers according to configuration
		if ( !configuration.disableBrowserTrace ) {
			addLogHandler( new BrowserConsoleLogger() );
		}

		// Add URL filter for basePath, if it is not "/"
		var path = Strings.trimChars( configuration.basePath, "/" );
		if ( path.length>0 )
			super.addUrlFilter( new DirectoryUrlFilter(path) );

		// Unless mod_rewrite is used, filter out index.php/index.n from the urls.
		if ( configuration.urlRewrite!=true )
			super.addUrlFilter( new PathInfoUrlFilter() );

		// Save the session / auth factories for later, when we're building requests
		if (configuration.sessionImplementation!=null) inject( UFHttpSession, configuration.sessionImplementation );
		if (configuration.authImplementation!=null) inject( UFAuthHandler, configuration.authImplementation );

		// Inject some settings for the view engine.
		if ( configuration.viewEngine!=null ) {
			inject( String, configuration.viewPath, "viewPath" );
			inject( UFViewEngine, configuration.viewEngine, true );
		}

		if ( configuration.defaultLayout!=null )
			inject( String, configuration.defaultLayout, "defaultLayout" );

		if ( configuration.viewEngine!=null ) {
			try {
				inject( configuration.viewEngine );
				viewEngine = injector.getInstance( UFViewEngine );
				for ( te in configuration.templatingEngines ) {
					viewEngine.addTemplatingEngine( te );
				}
			}
			catch (e:Dynamic) {
				trace( 'Failed to load view engine ${Type.getClassName(configuration.viewEngine)}: $e' );
			}
		}
	}

	/**
		Re-execute the app each time a PushState event occurs.
	**/
	public function listen():ClientJsApplication {
		var basePath = null;
		PushState.init( basePath, false );
		PushState.addEventListener(function(url,data) {
			// TODO: Work with "data" to set up some fake "POST" variables in our HttpRequest
			this.executeRequest();
		});
		return this;
	}

	/**
		Shortcut to map a class or value into `injector`.

		See `ufront.core.InjectorTools.inject()` for details on how the injections are applied.

		This method is chainable.
	**/
	override public function inject<T>( cl:Class<T>, ?val:T, ?cl2:Class<T>, ?singleton:Bool=false, ?named:String ):ClientJsApplication {
		return cast super.inject( cl, val, cl2, singleton, named );
	}
}
