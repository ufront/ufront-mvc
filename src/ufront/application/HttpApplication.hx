/**
 * ...
 * @author Franco Ponticelli
 */

package ufront.application;

import ufront.module.IHttpModule;
import thx.error.Error;
import hxevents.AsyncDispatcher;
import hxevents.Dispatcher;
import ufront.web.context.*;
import ufront.web.session.IHttpSessionState;

class HttpApplication
{
	public var httpContext(default, null) : HttpContext;
	public var request(get, null) : HttpRequest;
	public var response(get, null) : HttpResponse;
	public var session(get, null) : IHttpSessionState;
	public var modules(default, null) : List<IHttpModule>;

	var _completed : Bool;

	///// Events /////

	/**
	 * The onBeginRequest event signals the creation of any given new request.
	 * This event is always raised and is always the first event to occur during the processing of a request.
	 */
	public var onBeginRequest(default, null) : AsyncDispatcher<HttpApplication>;

	/**
	 * Occurs to let the caching modules serve requests from the cache, bypassing execution of the event
	 * handler (for example, a page or an XML Web service).
	 */
	public var onResolveRequestCache(default, null) : AsyncDispatcher<HttpApplication>;

	/**
	 * Occurs when execution of the current event handler is bypassed and allows a caching module to
	 * serve a request from the cache.
	 */
	public var onPostResolveRequestCache(default, null) : AsyncDispatcher<HttpApplication>;

	/**
	 * Occurs just before a request is to be dispatched.
	 */
	public var onDispatchHandler(default, null) : AsyncDispatcher<HttpApplication>;

	/**
	 * Occurs after a dispatch has (and it's associated action) has been completed
	 */
	public var onPostDispatchHandler(default, null) : AsyncDispatcher<HttpApplication>;

	/**
	 * Occurs just before executing an event handler (for example, a page or an XML Web service).
	 */
	public var onRequestResultExecute(default, null) : AsyncDispatcher<HttpApplication>;

	/**
	 * Occurs when the event handler (for example, a page or an XML Web service) finishes execution.
	 */
	public var onPostRequestResultExecute(default, null) : AsyncDispatcher<HttpApplication>;

	/**
	 * Occurs when an event handler finishes execution in order to let caching modules store responses that will
	 * be used to serve subsequent requests from the cache.
	 */
	public var onUpdateRequestCache(default, null) : AsyncDispatcher<HttpApplication>;

	/**
	 * Occurs when caching modules are finished updating and storing responses that are used to serve subsequent
	 * requests from the cache.
	 */
	public var onPostUpdateRequestCache(default, null) : AsyncDispatcher<HttpApplication>;

	/**
	 * Occurs just before any logging is performed for the current request.
	 */
	public var onLogRequest(default, null) : AsyncDispatcher<HttpApplication>;

	/**
	 * Occurs when all the event handlers for the LogRequest event has completed processing.
	 */
	public var onPostLogRequest(default, null) : AsyncDispatcher<HttpApplication>;

	/**
	 * Occurs as the last event in the HTTP pipeline chain of execution when responding to a request.
	 */
	public var onEndRequest(default, null) : Dispatcher<HttpApplication>;

	/**
	 * Occurs when an unhandled exception is thrown.
	 */
	public var onApplicationError(default, null) : AsyncDispatcher<{ application : HttpApplication, error : Error}>;

	///// End Events /////

	public function new(?httpContext : HttpContext) {
		this.httpContext = (httpContext == null) ? HttpContext.createWebContext() : httpContext;

		onBeginRequest = new AsyncDispatcher();

		onResolveRequestCache = new AsyncDispatcher();
		onPostResolveRequestCache = new AsyncDispatcher();

		onDispatchHandler = new AsyncDispatcher();
		onPostDispatchHandler = new AsyncDispatcher();

		onRequestResultExecute = new AsyncDispatcher();
		onPostRequestResultExecute = new AsyncDispatcher();

		onUpdateRequestCache = new AsyncDispatcher();
		onPostUpdateRequestCache = new AsyncDispatcher();

		onLogRequest = new AsyncDispatcher();
		onPostLogRequest = new AsyncDispatcher();
		onPostLogRequest.add(_executedLogRequest);

		onEndRequest = new Dispatcher();

		onApplicationError = new AsyncDispatcher();

		modules = new List();

		_completed = false;
	}

	var _logDispatched : Bool;
	var _flushed : Bool;

	function _executedLogRequest(_) {
		_logDispatched = true;
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
		- onDispatchHandler
		- onPostDispatchHandler
		- onRequestResultExecute
		- onPostRequestResultExecute
		- onUpdateRequestCache
		- onPostUpdateRequestCache
		- onLogRequest
		- onPostLogRequest

		Once all the events have fired, if no errors occured, `_conclude` is run.
		The `_conclude()` function will then flush the output from the response, fire "onEndRequest", and dispose of the context and modules.
		
		If at any point errors occur, the chain stops, and `onApplicationError` is triggered, followed by running `_conclude()`
		If at any point this HttpApplication is marked as complete, the chain stops and `_conclude()` is run.
	**/
	public function execute() {
		_flushed = _logDispatched = false;
		// wire modules
		for (module in modules)
			_initModule(module);

		_dispatchChain([
			onBeginRequest,
			onResolveRequestCache,
			onPostResolveRequestCache,
			onDispatchHandler,
			onPostDispatchHandler,
			onRequestResultExecute,
			onPostRequestResultExecute,
			onUpdateRequestCache,
			onPostUpdateRequestCache,
			onLogRequest,
			onPostLogRequest
		], _conclude);
	}

	/** Flush the output, fire the onEndRequest event, and close up shop **/
	function _conclude() {
		// flush contents
		_flush();
		// this event is always dispatched no matter what
		_dispatchEnd();
		_dispose();
	}

	/** Flush the response to the output. Catch errors. **/
	function _flush() {
		try {
			if(!_flushed) {
				response.flush();
				_flushed = true;
			}
		} 
		catch(e : Dynamic) {
			_dispatchError(e);
		}
	}

	/** Init every module required for this request **/
	function _initModule(module : IHttpModule) {
		try {
			module.init(this);
		} 
		catch(e : Dynamic) {
			_dispatchError(e);
		}
	}

	/** End the request by triggering the final onEndRequest event.  Catch errors **/
	function _dispatchEnd() {
		try {
			onEndRequest.dispatch(this);
		} 
		catch (e : Dynamic) {
			_dispatchError(e);
		}
	}

	/**
		Loop through every event in the chain (unless the request is completed by an event)

		Catch errors.  After finished, run `afterEffect()`
	**/
	function _dispatchChain(dispatchers : Array<AsyncDispatcher<HttpApplication>>, afterEffect : Void -> Void) {
		#if php
			// PHP has issues with long chains of methods
			for(dispatcher in dispatchers) {
				if(_completed)
					break;
				dispatcher.dispatch(this, null, _dispatchError);
			}
			if(null != afterEffect)
				afterEffect();
		#else
				var self = this;
				var next = null;
				next = function() {
					var dispatcher = dispatchers.shift();
					if(self._completed || null == dispatcher) {
						if(null != afterEffect)
							afterEffect();
						return;
					}
					dispatcher.dispatch(self, next, self._dispatchError);
				}
				next();
		#end
	}

	/**
		If logging hasn't happened, do that so the error is logged.
		Then either hit up the "onApplicationError" event, or if nothing is listening, simply throw the error.
	**/
	function _dispatchError(e : Dynamic) {
		if(!_logDispatched) {
			_dispatchChain([onLogRequest, onPostLogRequest], _dispatchError.bind(e));
			return;
		}

		var event = {
			application : this,
			error : Std.is(e, Error) ? e : new Error(Std.string(e))
		};

		if(!onApplicationError.has())
			throw event.error;
		else
			onApplicationError.dispatch(event);

		_conclude();
	}

	/**
		Close each module and the context
	**/
	function _dispose() {
		for (module in modules)
			module.dispose();
		httpContext.dispose();
	}

	/**
		Finish the request.  No more events in the chain will be executed.
	**/
	public function completeRequest() {
		_completed = true;
	}

	function get_request() return httpContext.request;
	function get_response() return httpContext.response;
	function get_session() return httpContext.session;
}