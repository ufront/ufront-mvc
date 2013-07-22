package ufront.application;

import ufront.module.IHttpModule;
import ufront.web.url.filter.IUrlFilter;
import hxevents.AsyncDispatcher;
import hxevents.Dispatcher;
import ufront.web.session.IHttpSessionState;
import ufront.web.context.*;
import ufront.auth.*;
import thx.error.*;

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
		Modules to be used in the application.  
		They will be initialized when `initModules()` is called, or when `execute()` is called.
		After they are initialised, modifying this list will have no effect.
	**/
	public var modules(default,null):List<IHttpModule>;

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
	public var onBeginRequest(default,null):AsyncDispatcher<HttpContext>;

	/**
		Event to trigger caching modules so we can serve requests from the cache, bypassing execution 
		of the event the usual request actions.
	**/
	public var onResolveRequestCache(default,null):AsyncDispatcher<HttpContext>;

	/**
		Occurs after a cache requests have been checked.
	**/
	public var onPostResolveRequestCache(default,null):AsyncDispatcher<HttpContext>;

	/**
		Occurs as a request is to be dispatched, deciding on which action to execute.
	**/
	public var onDispatch(default,null):AsyncDispatcher<HttpContext>;

	/**
		Occurs after the controller, action and arguments have been decided by the dispatcher.
	**/
	public var onPostDispatch(default,null):AsyncDispatcher<HttpContext>;

	/**
		Occurs just before a request's action is to be executed.
	**/
	public var onActionExecute(default,null):AsyncDispatcher<HttpContext>;

	/**
		Occurs just after a request's action has been executed and it's result is available
	**/
	public var onPostActionExecute(default,null):AsyncDispatcher<HttpContext>;

	/**
		Occurs when executing the `ActionResult` from the request's action
	**/
	public var onResultExecute(default,null):AsyncDispatcher<HttpContext>;

	/**
		Occurs just after executing the `ActionResult` from the request's action
	**/
	public var onPostResultExecute(default,null):AsyncDispatcher<HttpContext>;

	/**
		Occurs when an event handler finishes execution in order to let caching modules store responses that will
		be used to serve subsequent requests from the cache.
	**/
	public var onUpdateRequestCache(default,null):AsyncDispatcher<HttpContext>;

	/**
		Occurs when caching modules are finished updating and storing responses that are used to serve subsequent
		requests from the cache.
	**/
	public var onPostUpdateRequestCache(default,null):AsyncDispatcher<HttpContext>;

	/**
		Occurs just before any logging is performed for the current request.
	**/
	public var onLogRequest(default,null):AsyncDispatcher<HttpContext>;

	/**
		Occurs when all the event handlers for the LogRequest event has completed processing.
	**/
	public var onPostLogRequest(default,null):AsyncDispatcher<HttpContext>;

	/**
		Occurs as the last event in the HTTP pipeline chain of execution when responding to a request.
	**/
	public var onEndRequest(default,null):Dispatcher<HttpContext>;

	/**
		Occurs when an unhandled exception is thrown.
	**/
	public var onApplicationError(default,null):AsyncDispatcher<{ context:HttpContext, error:Error }>;

	///// End Events /////

	/**
		Start a new HttpApplication

		Depending on the platform, this may run multiple requests or it may be created per request.

		The constructor will initialize each of the events, and add a single `onPostLogRequest` event handler to make sure logs are not executed twice in the event of an error.

		After creating the application, you can initialize the modules and then execute requests with a given HttpContext.
	**/
	public function new() {

		onBeginRequest = new AsyncDispatcher();

		onResolveRequestCache = new AsyncDispatcher();
		onPostResolveRequestCache = new AsyncDispatcher();

		onDispatch = new AsyncDispatcher();
		onPostDispatch = new AsyncDispatcher();

		onActionExecute = new AsyncDispatcher();
		onPostActionExecute = new AsyncDispatcher();

		onResultExecute = new AsyncDispatcher();
		onPostResultExecute = new AsyncDispatcher();

		onUpdateRequestCache = new AsyncDispatcher();
		onPostUpdateRequestCache = new AsyncDispatcher();

		onLogRequest = new AsyncDispatcher();
		onPostLogRequest = new AsyncDispatcher();
		onPostLogRequest.add( _executedLogRequest );

		onEndRequest = new Dispatcher();

		onApplicationError = new AsyncDispatcher();

		modules = new List();
		urlFilters = [];
	}

	@:access(ufront.web.context.HttpContext)
	function _executedLogRequest( context:HttpContext ) {
		context.logDispatched = true;
	}

	/** 
		Add a module to this HttpApplication.

		Returns itself so that you can chain methods together.
	**/
	public function addModule( module:IHttpModule ) {
		if (module!=null) modules.add( module );
		return this;
	}

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

		Once all the events have fired, if no errors occured, `_conclude` is run.
		The `_conclude()` function will then flush the output from the response, fire "onEndRequest", and dispose of the context and modules.
		
		If at any point errors occur, the chain stops, and `onApplicationError` is triggered, followed by running `_conclude()`
		If at any point this HttpApplication is marked as complete, the chain stops and `_conclude()` is run.
	**/
	public function execute( ?httpContext:HttpContext ) {
		
		// Set up HttpContext for the request, and the URL filters
		if (httpContext == null) httpContext = HttpContext.createWebContext( urlFilters );
		else httpContext.setUrlFilters( urlFilters );

		// Check modules are initialized
		initModules();

		// Begin the chain of events.  They will be executed until either a completion, an error or the end of the chain.
		// After that _conclude() will run
		_dispatchChain( httpContext, [
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
		], _conclude.bind(httpContext) );
	}

	/** Flush the output, fire the onEndRequest event, dispose of the context **/
	function _conclude( httpContext:HttpContext ) {
		_flush( httpContext );
		_dispatchEnd( httpContext );
		httpContext.dispose();
	}

	/** Flush the response to the output. Catch errors. **/
	@:access(ufront.web.context.HttpContext)
	function _flush( context:HttpContext ) {
		try {
			if( !context.flushed ) {
				context.response.flush();
				context.flushed = true;
			}
		} 
		catch( e:Dynamic ) {
			_dispatchError( context, e );
		}
	}


	/** 
		Init every module required for this application.

		If this is not called before `execute()`, it will be called during `execute()`.

		If modules have already been initialized, this will have no effect.
	**/
	public function initModules( ?context:HttpContext ) {
		if ( _initiatedModules==false ) {
			for ( module in modules ) {
				try module.init( this )
				catch( e:Dynamic ) {
					if ( context==null )
		 				context = HttpContext.createWebContext();
					_dispatchError( context, e );
				}
			}
			_initiatedModules = true;
		}
	}
	var _initiatedModules = false;

	/** End the request by triggering the final onEndRequest event.  Catch errors **/
	function _dispatchEnd( context:HttpContext ) {
		try {
			onEndRequest.dispatch( context );
		} 
		catch (e:Dynamic) {
			_dispatchError( context, e );
		}
	}

	/**
		Loop through every event in the chain (unless the request is completed by an event)

		Catch errors.  After finished, run `afterEffect()`, which is probably `_conclude()`
	**/
	function _dispatchChain( httpContext:HttpContext, dispatchers:Array<AsyncDispatcher<HttpContext>>, afterEffect:Void->Void ) {
		for( dispatcher in dispatchers ) {
			if( httpContext.completed ) break;
			try {
				dispatcher.dispatch( httpContext, null, _dispatchError.bind(httpContext) );
			}
			catch (e:Dynamic) {
				_dispatchError( httpContext, e );
				return;
			}
		}
		if( null!=afterEffect ) afterEffect();
	}

	/**
		If logging hasn't happened, do that so the error is logged.
		Then either hit up the "onApplicationError" event, or if nothing is listening, simply throw the error.
	**/
	function _dispatchError( context:HttpContext, e:Dynamic ) {
		if( !context.logDispatched ) {
			_dispatchChain( context, [
				onLogRequest, 
				onPostLogRequest
			], _dispatchError.bind(context,e) );
			return;
		}

		var event = {
			context: context,
			error: Std.is(e, Error) ? e : new Error(Std.string(e))
		};

		if( !onApplicationError.has() )
			throw event.error;
		else
			onApplicationError.dispatch( event );

		_conclude( context );
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
		for ( module in modules ) module.dispose();
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
		modules = null;
		urlFilters = null;
	}
}