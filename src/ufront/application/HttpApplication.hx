package ufront.application;

import ufront.module.IHttpModule;
import ufront.web.url.filter.IUrlFilter;
import ufront.core.AsyncSignal;
import ufront.core.AsyncCallback;
import ufront.web.session.IHttpSessionState;
import minject.Injector;
import ufront.web.context.*;
import ufront.auth.*;
import thx.error.*;
import tink.CoreApi;

/**
	The base class for a HTTP Application

	This provides the framework for setting up a web-app that either uses Http or emulates Http behaviour - receiving requests and issuing responses.

	It's function is:

	- Have a handful of events, one after another.  The event chain fires for each request.
	- Have different modules that do things (eg, a module to check a cache, a module to fire a controller action, a module to log a request)
	- Modules listen to events, and trigger their functionality at the right part of the request.
	- Each request has a HttpContext, describing the request, the response, the current session, authorization handler and other things.
	- Once the request is complete, or if there is an error, the HTTP response is sent to the client.

	Depending on the environment, a HttpApplication may be created once per request, or the application may be persistent and have many requests.
**/
class HttpApplication
{
	/**
		An injector for things that should be available to all parts of the application.

		Things we could inject:

		- Your App Configuration
		- An ICacheHandler implementation
		- An IMailer implementation

		etc.

		This will be made available to the following:

		- Any `ufront.module.IHttpModule` - for example, RemotingModule, DispatchModule or CacheModule
		- Any child injectors, for example, "controllerInjector" or "apiInjector" in `UfrontApplication`
	**/
	public var appInjector:Injector;

	/** 
		Modules to be used in the application.  
		They will be initialized when `initModules()` is called, or when `execute()` is called.
		After they are initialised, modifying this list will have no effect.
	**/
	public var modules(default,null):Array<IHttpModule>;

	/**
		UrlFilters for the current application.  
		These will be used in the HttpContext for `getRequestUri` and `generateUri`.  
		See `addUrlFilter()` and `clearUrlFilters()` below.  
		Modifying this list will take effect at the beginning of the next `execute()` request.
	**/
	public var urlFilters(default,null):Array<IUrlFilter>;

	///// Events /////

	/**
		The onBeginRequest event signals the creation of any given new request.
		This event is always raised and is always the first event to occur during the processing of a request.
	**/
	public var onBeginRequest(default,null):AsyncSignal<HttpContext>;

	/**
		Event to trigger caching modules so we can serve requests from the cache, bypassing execution 
		of the event the usual request actions.
	**/
	public var onResolveRequestCache(default,null):AsyncSignal<HttpContext>;

	/**
		Occurs after a cache requests have been checked.
	**/
	public var onPostResolveRequestCache(default,null):AsyncSignal<HttpContext>;

	/**
		Occurs as a request is to be dispatched, deciding on which action to execute.
	**/
	public var onDispatch(default,null):AsyncSignal<HttpContext>;

	/**
		Occurs after the controller, action and arguments have been decided by the dispatcher.
	**/
	public var onPostDispatch(default,null):AsyncSignal<HttpContext>;

	/**
		Occurs just before a request's action is to be executed.
	**/
	public var onActionExecute(default,null):AsyncSignal<HttpContext>;

	/**
		Occurs just after a request's action has been executed and it's result is available
	**/
	public var onPostActionExecute(default,null):AsyncSignal<HttpContext>;

	/**
		Occurs when executing the `ActionResult` from the request's action
	**/
	public var onResultExecute(default,null):AsyncSignal<HttpContext>;

	/**
		Occurs just after executing the `ActionResult` from the request's action
	**/
	public var onPostResultExecute(default,null):AsyncSignal<HttpContext>;

	/**
		Occurs when an event handler finishes execution in order to let caching modules store responses that will
		be used to serve subsequent requests from the cache.
	**/
	public var onUpdateRequestCache(default,null):AsyncSignal<HttpContext>;

	/**
		Occurs when caching modules are finished updating and storing responses that are used to serve subsequent
		requests from the cache.
	**/
	public var onPostUpdateRequestCache(default,null):AsyncSignal<HttpContext>;

	/**
		Occurs just before any logging is performed for the current request.
	**/
	public var onLogRequest(default,null):AsyncSignal<HttpContext>;

	/**
		Occurs when all the event handlers for the LogRequest event has completed processing.
	**/
	public var onPostLogRequest(default,null):AsyncSignal<HttpContext>;

	/**
		Occurs as the last event in the HTTP pipeline chain of execution when responding to a request.
	**/
	public var onEndRequest(default,null):AsyncSignal<HttpContext>;

	/**
		Occurs when an unhandled exception is thrown.
	**/
	public var onApplicationError(default,null):AsyncSignal<{ context:HttpContext, error:Dynamic }>;

	///// End Events /////

	/**
		Start a new HttpApplication

		Depending on the platform, this may run multiple requests or it may be created per request.

		The constructor will initialize each of the events, and add a single `onPostLogRequest` event handler to make sure logs are not executed twice in the event of an error.

		After creating the application, you can initialize the modules and then execute requests with a given HttpContext.
	**/
	@:access(ufront.web.context.HttpContext)
	public function new() {

		appInjector = new Injector();
		appInjector.mapValue( Injector, appInjector );

		onBeginRequest = new AsyncSignal();

		onResolveRequestCache = new AsyncSignal();
		onPostResolveRequestCache = new AsyncSignal();

		onDispatch = new AsyncSignal();
		onPostDispatch = new AsyncSignal();

		onActionExecute = new AsyncSignal();
		onPostActionExecute = new AsyncSignal();

		onResultExecute = new AsyncSignal();
		onPostResultExecute = new AsyncSignal();

		onUpdateRequestCache = new AsyncSignal();
		onPostUpdateRequestCache = new AsyncSignal();

		onLogRequest = new AsyncSignal();
		onPostLogRequest = new AsyncSignal();
		onPostLogRequest.handle( function _executedLogRequest(context:HttpContext) context.logDispatched = true );

		onEndRequest = new AsyncSignal();

		onApplicationError = new AsyncSignal();

		modules = [];
		urlFilters = [];
	}

	/** 
		Add a module to this HttpApplication.

		Returns itself so that you can chain methods together.
	**/
	public function addModule( module:IHttpModule ) {
		if (module!=null) modules.push( module );
		return this;
	}


	/** 
		Init every module required for this application.

		If this is not called before `execute()`, it will be called during `execute()`.

		If modules have already been initialized, this will have no effect.

		The `context` argument is optional, and is only needed if an error occurs initializing the modules, in which case, it uses the `HttpContext` to send an error message to the browser.
	**/
	public function initModules( ?context:HttpContext ) {
		if ( _initiatedModules==false ) {
			for ( module in modules ) {
				try {
					appInjector.injectInto( module );
					module.init( this );
				}
				catch( e:Dynamic ) {
					if ( context==null ) {
						context = HttpContext.create();
					}
					_dispatchError( context, e );
				}
			}
			_initiatedModules = true;
		}
	}
	var _initiatedModules = false;

	/** 
		Execute the request 

		Works by initiating the modules, firing the events in order, and once the request is complete flushing the output and closing the request.
		Each module listens to events and reads the request, processes, and adds to the response during the chain.

		Events are fired in the following order:

		- onBeginRequest
		- onResolveRequestCache
		- onPostResolveRequestCache
		- onDispatch
		- onPostDispatch
		- onActionExecute
		- onPostActionExecute
		- onResultExecute
		- onPostResultExecute
		- onUpdateRequestCache
		- onPostUpdateRequestCache
		- onLogRequest
		- onPostLogRequest

		Once all the events have fired, if no errors occured, then flush the output from the response, fire "onEndRequest", and dispose of the context.
		
		If at any point errors occur, the chain stops, and `onApplicationError` is triggered, followed by running `_conclude()`
		If at any point this HttpApplication is marked as complete, the chain stops and `_conclude()` is run.
	**/
	@:access(ufront.web.context.HttpContext)
	public function execute( ?httpContext:HttpContext ) {
		
		// Set up HttpContext for the request, and the URL filters
		if (httpContext == null) httpContext = HttpContext.create( urlFilters );
		else httpContext.setUrlFilters( urlFilters );

		// Check modules are initialized
		initModules( httpContext );

		// Begin the chain of events.  They will be executed until either a completion, an error or the end of the chain.
		// After that _conclude() will run
		var showStopper = function() return httpContext.completed;
		AsyncSignal
			.dispatchChain( httpContext, [
				onBeginRequest,
				onResolveRequestCache,
				onPostResolveRequestCache,
				onDispatch,
				onPostDispatch,
				onActionExecute,
				onPostActionExecute,
				onResultExecute,
				onPostResultExecute,
				onUpdateRequestCache,
				onPostUpdateRequestCache,
				onLogRequest,
				onPostLogRequest
			], showStopper )
			.handle(function (result:AsyncCompletion) {
				switch (result) {
					case Error( e ): 
						return _dispatchError( httpContext, e );
					default: 
						var flushed = Future.trigger();
						var requestEnded = Future.trigger();

						// Commit session
						var sessionDone = httpContext.commitSession();
						
						// After session is committed, flush the response (if needed, and catch errors, if needed)
						sessionDone.handle(function () {
							try {
								if( !httpContext.flushed ) {
									httpContext.response.flush();
									httpContext.flushed = true;
								}
								flushed.trigger( Completed );
							} 
							catch( e:Dynamic ) {
								_dispatchError(httpContext, e).handle( function(r) flushed.trigger(r) );
							}
						});

						// After flushing, end the request
						flushed.asFuture().handle( function () {
							onEndRequest.trigger( httpContext ).handle( function(r) requestEnded.trigger(r) );
						});

						// After the request is ended, dispose the context
						requestEnded.asFuture().handle( httpContext.dispose );

						return requestEnded.asFuture();
				}
			});
	}

	/**
		If logging hasn't happened, do that so the error is logged.
		Then either hit up the "onApplicationError" event, or if nothing is listening, simply throw the error.

		Wrap Error / Context
		If Error Handler
			onApplicationError.trigger()
			then if not logged, log
			then 
				if error throw
				else finalFlush()
		Else
			if not logged then log (throw if error)
			throw original error
	**/
	@:access(ufront.web.context.HttpContext)
	function _dispatchError( context:HttpContext, e:Dynamic ) {
		// Wrap the event if it isn't already an error
		var event = {
			context: context,
			error: e
		};

		// If there is an error handler, execute that and wait
		var hasErrorHandler = (onApplicationError.getLength() > 0);
		var afterErrorHandler = 
			if ( hasErrorHandler )
				onApplicationError.trigger( event );
			else
				AsyncCallback.COMPLETED;

		// After the error handler, check if we need logging to happen
		var afterLogging = Future.trigger();
		afterErrorHandler.handle(function () {
			if( !context.logDispatched )  
				AsyncSignal.dispatchChain( context, [
					onLogRequest,
					onPostLogRequest
				]).handle( function(r) afterLogging.trigger(r) );
			else 
				afterLogging.trigger( Completed );
		});

		// After the logging is done, if there was an error handler, do a flush, if not, throw anyway
		var requestEnded = Future.trigger();
		afterLogging.asFuture().handle(function (result) {
			switch result {
				case Error(e): 
					throw e; // There was an error in the error handler.  Ouch!
				default:
					if (hasErrorHandler) { 
						// Do a final flush, end the request
						if( !context.flushed ) {
							context.response.flush();
							context.flushed = true;
						}
						onEndRequest.trigger( context ).handle( function(r) requestEnded.trigger(r) );
					}
					else {
						// No error handler, just throw error to give best hope of debugging
						throw event.error; 
					} 
			}
		});

		return requestEnded.asFuture();
	}

	/**
		Add a URL filter to be used in the HttpContext for `getRequestUri` and `generateUri`
	**/
	public function addUrlFilter( filter:IUrlFilter ) {
		NullArgument.throwIfNull( filter );
		urlFilters.push( filter );
	}

	/**
		Remove existing URL filters
	**/
	public function clearUrlFilters() {
		urlFilters = [];
	}

	/**
		Dispose of the HttpApplication (and dependant modules etc)
	**/
	public function dispose() {
		for ( module in modules ) 
			module.dispose();
		modules = null;
		_initiatedModules = false;

		onBeginRequest = null;
		onResolveRequestCache = null;
		onPostResolveRequestCache = null;
		onDispatch = null;
		onPostDispatch = null;
		onActionExecute = null;
		onPostActionExecute = null;
		onResultExecute = null;
		onPostResultExecute = null;
		onUpdateRequestCache = null;
		onPostUpdateRequestCache = null;
		onLogRequest = null;
		onPostLogRequest = null;
		onEndRequest = null;
		onApplicationError = null;
		
		urlFilters = null;
	}
}