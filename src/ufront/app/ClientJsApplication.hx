package ufront.app;

#if client
	import ufront.app.UfrontClientConfiguration;
	import ufront.web.context.HttpContext;
	import ufront.web.session.*;
	import ufront.auth.*;
	import ufront.view.*;
	import ufront.handler.*;
	import ufront.log.*;
	import ufront.remoting.*;
	import ufront.web.*;
	import haxe.remoting.Connection;
	import haxe.remoting.AsyncConnection;
	import ufront.api.*;
	import pushstate.PushState;
	import ufront.web.url.filter.*;
	import ufront.web.client.UFClientAction;
	import tink.CoreApi;
	import ufront.core.ClassRef;
	using ufront.core.InjectionTools;
	using StringTools;

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
		Get the most recent `HttpContext`.

		If no requests have been executed yet, this will generate a new HttpContext based on the current browser state.
		**/
		public var currentContext(get,null):HttpContext;

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
				injector.mapRuntimeTypeOf( controller ).toClass( controller );
			}
			for ( api in configuration.apis ) {
				injector.mapRuntimeTypeOf( api ).asSingleton();
				var asyncApi = UFAsyncApi.getAsyncApi( api );
				if ( asyncApi!=null )
					injector.mapRuntimeTypeOf( asyncApi ).asSingleton();
			}

			// Add the remoting connections.
			if ( configuration.remotingPath!=null ) {
				var syncRemotingConnection = HttpConnection.urlConnect( "/" );
				var asyncRemotingConnection = HttpAsyncConnection.urlConnect( "/" );
				injector.map( Connection ).toValue( syncRemotingConnection );
				injector.map( AsyncConnection ).toValue( asyncRemotingConnection );
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

			if ( configuration.defaultLayout!=null )
				injector.map( String, "defaultLayout" ).toValue( configuration.defaultLayout );

			if ( configuration.viewEngine!=null ) {
				// Set up the view engine, add it to the injector as a singleton, under both "UFViewEngine" and the implementation type.
				injector.map( String, "viewPath" ).toValue( configuration.viewPath );
				injector.map( UFViewEngine ).toSingleton( configuration.viewEngine );
				injector.mapRuntimeTypeOf( configuration.viewEngine ).toValue( injector.getValue(UFViewEngine) );

				try {
					viewEngine = injector.getValue( UFViewEngine );
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

		override public function executeRequest():Surprise<Noise,Error> {
			loadCurrentContext();
			return this.execute( currentContext );
		}

		override public function init():Surprise<Noise,Error> {
			_currentApps.push( this );
			return super.init();
		}

		override public function dispose():Surprise<Noise,Error> {
			_currentApps.remove( this );
			return super.dispose();
		}

		/**
		Register a `UFClientAction` to be available in `this.executeAction`.
		**/
		public function registerAction( actionClass:Class<UFClientAction<Dynamic>> ):ClientJsApplication {
			this.injector.mapRuntimeTypeOf( actionClass ).asSingleton();
			return this;
		}

		/**
		Execute a given UFClientAction, optionally passing data to the method.

		If the `UFClientAction` has been triggered before, the action instance will be re-used.
		If not, it will be created using dependency injection.

		The action will be executed using `this.currentContext` and the provided data.

		@param actionClass The `Class<UFClientAction>` or class name (as a `String`) for the action to execute.
		@param data (optional) The data to provide to the action.
		**/
		public function executeAction<T>( actionClass:ClassRef<UFClientAction<T>>, ?data:Null<T> ):Void {
			if ( this.injector.hasMapping(actionClass.toString()) ) {
				var action:UFClientAction<T> = this.injector.getValueForType( actionClass.toString() );
				action.execute( this.currentContext, data );
			}
			else throw 'UFClientAction ${actionClass.toString()} was not registered with the ClientJsApplication.';
		}

		function get_currentContext():HttpContext {
			if ( this.currentContext==null )
				loadCurrentContext();
			return currentContext;
		}

		function loadCurrentContext() {
			this.currentContext = HttpContext.createContext( this.injector, urlFilters );
		}

		// Statics used to expose `ufExecuteAction()` method.
		static var _currentApps:Array<ClientJsApplication> = [];

		/**
		Call `executeAction()` for the current application (or applications).

		This is exposed to the Javscript context as `ufExecuteAction()` and so can be called from 3rd party code.
		**/
		@:expose("ufExecuteAction")
		public static function ufExecuteAction<T>( actionClass:ClassRef<UFClientAction<T>>, ?data:Null<T> ):Void {
			for ( app in _currentApps )
				app.executeAction( actionClass, data );
		}
	}
#end
