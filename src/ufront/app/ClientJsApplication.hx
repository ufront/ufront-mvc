package ufront.app;

#if client
	import ufront.web.UfrontClientConfiguration;
	import ufront.web.context.HttpContext;
	import ufront.web.session.*;
	import ufront.auth.*;
	import ufront.view.*;
	import ufront.handler.*;
	import ufront.log.*;
	import ufront.remoting.HttpConnection;
	import ufront.remoting.HttpAsyncConnection;
	import haxe.remoting.Connection;
	import haxe.remoting.AsyncConnection;
	import ufront.api.*;
	import pushstate.PushState;
	import thx.core.Strings;
	import ufront.web.url.filter.*;

	/**
	A standard Ufront Client-Side Application for executing requests in the browser.

	This extends `HttpApplication` for a "batteries included" way to set up your client-side Ufront app.

	Out of the box it provides:

	- The `MVCHandler` for macro powered routing and a model / view / controller style of responding to requests.
	- Tracing directly to a browser console, based on your `UfrontClientConfiguration`.
	- Default URL Filtering rules, based on your `UfrontClientConfiguration`.

	Ufront uses `minject.Injector` for dependency injection, and `UfrontApplication` adds several things to the injector, depending on your configuration:

	- All of the controllers specified in your configuration (By default: every `Controller` imported into your app).
	- If a remoting path is supplied in your `UfrontClientConfiguration`, then an appropriate `ufront.remoting.HttpConnection` and `ufront.remoting.HttpAsyncConnection` will be injected.
	- The `UFApi` proxy versions of all of the APIs specified in your configuration (by default: every `UFApi` imported into your app).
	- The `UFAsyncApi` proxy versions of all `UFApi` objects injected above.
	- A singleton of the `UFViewEngine` specified in your `UfrontClientConfiguration`.
	- The implementation of `UFHttpSession` you chose in your `UfrontClientConfiguration`, to be instantiated on each request.
	- The implementation of `UFAuthHandler` you chose in your `UfrontClientConfiguration`, to be instantiated on each request.
	- A String named `viewPath` for the path to your view folder, specified in your `UfrontClientConfiguration`.

	Futher injections may take place in various middleware / handlers also.
	**/
	class ClientJsApplication extends HttpApplication {
		/**
		The configuration that was used when setting up the application.

		This is set during the constructor.  Changing values of this object is not likely to have any effect.
		**/
		public var configuration(default,null):UfrontClientConfiguration;

		/**
		The MVC handler used for this application.

		This is made accessible for unit testing and logging purposes, you are unlikely to need to access it directly for anything else.
		**/
		public var mvcHandler(default,null):MVCHandler;

		/**
		The view engine being used with this application

		It is configured using the `viewEngine` property on your `UfrontClientConfiguration`.
		**/
		public var viewEngine(default,null):UFViewEngine;

		/**
		Initialize a new ClientJsApplication with the given configurations.

		@param ?optionsIn Options for ClientJsApplication.  See `DefaultUfrontClientConfiguration` for details.  Any missing values will imply defaults should be used.
		**/
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
				var asyncApi = UFAsyncApi.getAsyncApi( api );
				if ( asyncApi!=null )
					inject( asyncApi );
			}

			// Add the remoting connections.
			if ( configuration.remotingPath!=null ) {
				var syncRemotingConnection = HttpConnection.urlConnect( "/" );
				var asyncRemotingConnection = HttpAsyncConnection.urlConnect( "/" );
				inject( Connection, syncRemotingConnection );
				inject( AsyncConnection, asyncRemotingConnection );
			}

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
		Use `PushState.addEventListener` to re-execute the app each time a PushState event occurs.

		This allows you to respond to users clicking "pushstate" links, submitting "pushstate" forms, using the back button etc.

		This does not execute on the initial page load - please also call `this.executeRequest()` if you need to execute on the initial page load.
		**/
		public function listen():ClientJsApplication {
			var basePath = null;
			PushState.init( basePath, false );
			PushState.addEventListener(function(url,data) {
				this.executeRequest();
			});
			return this;
		}

		/**
		Shortcut to map a class or value into `injector`.

		See `InjectionTools.inject()` for details on how the injections are applied.
		**/
		override public function inject<T>( cl:Class<T>, ?val:T, ?cl2:Class<T>, ?singleton:Bool=false, ?named:String ):ClientJsApplication {
			return cast super.inject( cl, val, cl2, singleton, named );
		}
	}
#end
