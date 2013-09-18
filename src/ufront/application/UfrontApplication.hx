package ufront.application;

import haxe.ds.StringMap;
import haxe.PosInfos;
import minject.Injector;
import ufront.application.HttpApplication;
import haxe.web.Dispatch.DispatchConfig;
#if ufront_easyauth
	import ufront.auth.EasyAuth;
#end
import ufront.log.*;
import ufront.remoting.RemotingApiContext;
import ufront.remoting.RemotingModule;
import ufront.web.context.HttpContext;
import ufront.web.Dispatch;
import ufront.web.session.FileSession;
import ufront.web.url.filter.*;
import ufront.web.Controller;
import ufront.web.UfrontConfiguration;
import ufront.module.*;
import ufront.web.session.IHttpSessionState;
import ufront.auth.IAuthHandler;
import ufront.auth.IAuthUser;
import ufront.remoting.RemotingApiClass;
using Objects;

/**
	A standard Ufront Application.  This extends HttpApplication and provides:

	- Routing with `ufront.module.DispatchModule`
	- Easily add remoting API context and initiate the `ufront.remoting.RemotingModule`
	- Tracing, to console or logfile, based on your `ufront.web.UfrontConfiguration`

	And in future

	- easily cache requests

	@author Jason O'Neil
	@author Andreas Soderlund
	@author Franco Ponticelli
**/
class UfrontApplication extends HttpApplication
{
	/**
		An injector for things that should be available to dispatch / controllers.
	
		This extends `HttpApplication.appInjector`, and adds the following mappings by default:

		- A mapClass rule for every class that extends `ufront.web.Controller`
		- A mapSingleton rule for every class that extends `ufront.remoting.RemotingApiClass`
		- We will create a child injector for each dispatch request that also maps a `ufront.web.context.HttpContext` instance and related auth, session, request and response values.
	**/
	public var dispatchInjector:Injector;

	/**
		An injector for things that should be available to the API classes in the remoting context.

		This extends `HttpApplication.appInjector`, and adds the following mappings by default:

		- A mapSingleton rule for every class that extends `ufront.remoting.RemotingApiClass`
		- We will create a child injector for each remoting request that also maps a `ufront.auth.IAuthHandler` instance for checking auth in your API.
	**/
	public var remotingInjector:Injector;

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
		The remoting module used for this application.
		
		It is automatically set up if a `RemotingApiContext` class is found
	**/
	public var remotingModule(default,null):RemotingModule;
	
	/** 
		The error module used for this application.
		
		This is made accessible so that you can configure the error module or add new error handlers.
	**/
	public var errorModule(default,null):ErrorModule;

	/**
		Messages (traces, logs, warnings, errors) that are not associated with a specific request.
	**/
	public var messages:Array<Message>;

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

		// Set up custom trace.  Will save messages to the `messages` array, and let modules log as they desire.
		messages = [];
		haxe.Log.trace = function(msg:Dynamic, ?pos:PosInfos) {
			messages.push({ msg: msg, pos: pos, type: Trace });
		}

		configuration = DefaultUfrontConfiguration.get();
		configuration.merge( optionsIn );

		// Set up the injectors
		dispatchInjector = appInjector.createChildInjector();
		remotingInjector = appInjector.createChildInjector();
		dispatchInjector.mapValue( Injector, dispatchInjector );
		remotingInjector.mapValue( Injector, remotingInjector );

		// Map some default rules
		for ( controller in configuration.controllers ) dispatchInjector.mapClass( controller, controller );
		for ( api in configuration.apis ) {
			remotingInjector.mapClass( api, api );
			dispatchInjector.mapClass( api, api );
		}

		// Set up the error module first, in case it catches any errors in other modules
		addModule( configuration.errorModule );

		// Add a remoting module (and the remoting logger) if there is a RemotingApiContext...
		if ( configuration.remotingContext!=null ) {
			remotingModule = new RemotingModule();
			addModule( remotingModule );
			remotingModule.loadApi( configuration.remotingContext );
			addModule( new RemotingLogger() );
		}

		// Add a DispatchModule which will deal with all of our routing and executing contorller actions and results
		dispatchModule = new DispatchModule( configuration.dispatchConf );
		addModule( dispatchModule );

		// add tracing modules
		if ( !configuration.disableBrowserTrace ) 
			addModule( new BrowserConsoleLogger() );
		if ( null!=configuration.logFile ) 
			addModule( new FileLogger(configuration.logFile) );
		
		// Add URL filter for basePath, if it is not "/"
		var path = Strings.trim( configuration.basePath, "/" );
		if ( path.length>0 )
			super.addUrlFilter( new DirectoryUrlFilter(path) );

		// Unless mod_rewrite is used, filter out index.php/index.n from the urls.
		if ( configuration.urlRewrite!=true )
			super.addUrlFilter( new PathInfoUrlFilter() );

		// Save the session / auth factories for later, when we're building requests
		sessionFactory = configuration.sessionFactory;
		authFactory = configuration.authFactory;
	}

	var sessionFactory:HttpContext->IHttpSessionState;
	var authFactory:HttpContext->IAuthHandler<IAuthUser>;

	/**
		Execute the current request.

		If `httpContext` is not defined, `HttpContext.create()` will be used, with your session data being sent through.
	**/
	override public function execute( ?httpContext:HttpContext ) {
		// Set up HttpContext for the request
		if ( httpContext==null ) httpContext = HttpContext.create( sessionFactory, authFactory, urlFilters );

		// execute
		super.execute( httpContext );
	}
}