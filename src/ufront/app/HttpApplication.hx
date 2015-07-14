package ufront.app;

import ufront.web.url.filter.UFUrlFilter;
import ufront.core.AsyncTools;
import minject.Injector;
import ufront.app.UFMiddleware;
import ufront.web.context.HttpContext;
import ufront.web.HttpError;
import ufront.auth.*;
import ufront.log.Message;
import haxe.PosInfos;
import tink.core.Error.Pos;
using tink.CoreApi;

/**
A HttpApplication responds to each request by generating a `HttpContext` and passing it through each stage of the request.

It is the base class for `UfrontApplication` and `ClientJsApplication`, and could be used for other implementations also.

#### Request life-cycle:

The `HttpApplication` is responsible for managing the lifecycle of each request.

The lifecycle is:

- Set up the HttpApplication.
- Initialise each of the modules (`UFRequestMiddleware`, `UFRequestHandler`, `UFResponseMiddleware`, `UFLogHandler` and `UFErrorHandler`).
- Create a `HttpContext` for each request, and then:
- Pass the `HttpContext` through the `UFRequestMiddleware`.
- Once the request middleware is complete, pass the `HttpContext` through each `UFRequestHandler`.
- Once the request handler is complete, pass the `HttpContext` through each `UFResponseMiddleware`.
- Once the response middleware is complete, pass the `HttpContext` through each `UFLogHandler`.
- Once the log handlers have completed, flush the `HttpResponse` from `HttpContext.response`, this sends the result to the browser.
- Any stage can result in an error, in which case the the `Error` and the `HttpContext` are passed through each `UFErrorHandler` and `UFLogHandler`.
- Any module can modify the `completion` flags of `HttpContext`, allowing it to skip other modules during the lifecycle of the request. See `HttpContext.completion`.

Each module returns a `Surprise`, allowing it to run asynchronously, and the request chain will wait for each module to complete before moving.

See the documentation for `this.execute` for more details.

#### Persistence:

Depending on the environment, a `HttpApplication` may be created once per request, or the application may be persistent and have many requests.
Client JS, NodeJS and Neko (when using `mod_tora` or `mod_neko` and the `Web.cacheModule` feature) are able to keep the same application alive and respond to multiple requests.
PHP, and Neko (when not using `Web.cacheModule`) create a new application for each request.
**/
class HttpApplication
{
	/**
	A dependency injector for the current application.

	Any dependencies injected here will be available to all parts of the application, including the `UFMiddleware`, `UFRequestHandler`, `UFLogHandler` and `UFErrorHandler` modules.
	It will also be used as the parent injector for each request, which will be used for `Controller` and `UFApi` objects.

	It is smart to include things available to all requests at this level: for example, app configuration, a `UFCache` implementations, a `UFMailer` implementation etc.
	You should avoid injecting things which might be particular to a given request: for example, a `UFHttpSession` should belong to just one request, not the whole application.
	If you wish to inject something into a specific request, you can use middleware and access the `HttpContext.injector`.

	The `this.inject()` method can be used as a helper to inject dependencies.

	The `injector` is injected into itself so that modules, APIs and controllers can have access to the injector also.
	**/
	public var injector:Injector;

	/**
	Middleware that can read and respond to the current HttpRequest, before the `UFRequestHandler` handlers execute.

	See `UFRequestMiddleware` for details and examples.
	**/
	public var requestMiddleware(default,null):Array<UFRequestMiddleware>;

	/**
	Handlers that can process this request and write a response.

	Examples:

	 - `ufront.handler.MVCHandler`
	 - `ufront.handler.RemotingHandler`
	 - A handler which passes static assets to the client (in case your web server does not do this automatically)
	 - A CSS Preprocesser handler (compile *.css requests from *.sass or *.less files using an appropriate CSS preprocessor)

	See `UFRequestHandler` for details and examples.
	**/
	public var requestHandlers(default,null):Array<UFRequestHandler>;

	/**
	Middleware that can read and respond to the current HttpRequest, after the `UFRequestHandler` handlers execute.

	See `UFResponseMiddleware` for details and examples.
	**/
	public var responseMiddleware(default,null):Array<UFResponseMiddleware>;

	/**
	Log handlers to use for traces, logs, warnings and errors.

	See `UFLogHandler` for details and examples.
	**/
	public var logHandlers(default,null):Array<UFLogHandler>;

	/**
	Error handlers to use if unhandled exceptions or Failures occur.

	See `UFErrorHandler` for details and examples.
	**/
	public var errorHandlers(default,null):Array<UFErrorHandler>;

	/**
	UrlFilters for the current application.

	These will be used for `HttpContext.getRequestUri()` and `HttpContext.generateUri()`.

	Modifying this list will only have an effect on future requests - modifications after a request has started will not affect that request.

	See `this.addUrlFilter()` and `this.clearUrlFilters()` below, and `UFUrlFilter` for more details.
	**/
	public var urlFilters(default,null):Array<UFUrlFilter>;

	/**
	Messages (traces, logs, warnings and errors) that are not associated with a specific request.

	These are generally recorded from calls to `trace()` or `haxe.Log.trace()`, which have no knowledge of the current request.
	**/
	public var messages:Array<Message>;

	/** A future trigger, for internal use, that lets us tell if all our modules (middleware and handlers) are ready for use. **/
	var modulesReady:Surprise<Noise,Error>;

	/** A position representing the current module.  Useful for diagnosing if something in our async chain never completed. **/
	var currentModule:Pos;

	/** The relative path to the content directory. **/
	var pathToContentDir:String = null;

	/**
	Start a new HttpApplication and initialise the internal state.
	**/
	public function new() {
		// Set up injector
		requestMiddleware = [];
		requestHandlers = [];
		responseMiddleware = [];
		logHandlers = [];
		errorHandlers = [];
		urlFilters = [];
		messages = [];
		injector = new Injector();
		injector.injectValue( injector );
	}

	/**
	Initialise the modules used in this application.

	This will:
	- Redirect `haxe.Log.trace()` to save messages to `this.messages`.
	- Check all modules which require initialisation (`UFInitRequired`) and run those initialisations.
	- Return a `Surprise`, which triggers once the modules are complete, and is either a `Success` or a `Failure` if any modules failed to initialise.

	If `init()` is called more than once, it will return the same `Surprise` as the first `init()` call, meaning that modules are only initiated once per application.

	When responding to a request, `init()` is called as the first step of our chain in each `execute()` call.
	**/
	public function init():Surprise<Noise,Error> {
		haxe.Log.trace = function(msg:Dynamic, ?pos:PosInfos) {
			messages.push({ msg: msg, pos: pos, type: Trace });
		}
		if ( modulesReady==null ) {
			var futures = [];
			for ( module in getModulesThatRequireInit() ) {
				futures.push( module.init(this) );
			}
			modulesReady = Future.ofMany( futures ).map( function(outcomes:Array<Outcome<Noise,Error>>) {
				for (o in outcomes) {
					switch o {
						case Failure(err): return Failure(err); // pass the failure on...
						case Success(_):
					}
				}
				return Success(Noise);
			});
		}
		return modulesReady;
	}

	/**
	Perform `dispose()` on any modules that require it (those marked with the `UFInitRequired` interface).
	**/
	public function dispose():Surprise<Noise,Error> {
		var futures = [];
		for ( module in getModulesThatRequireInit() )
			futures.push( module.dispose(this) );
		return Future.ofMany( futures ).map(function(outcomes) {
			modulesReady = null;
			for (o in outcomes) {
				switch o {
					case Failure(_): return o; // pass the failure on...
					case Success(_):
				}
			}
			return Success(Noise);
		});
	}

	function getModulesThatRequireInit():Array<UFInitRequired> {
		var moduleSets:Array<Array<Dynamic>> = [ requestMiddleware, requestHandlers, responseMiddleware, logHandlers, errorHandlers ];
		var modules:Array<UFInitRequired> = [];
		for ( set in moduleSets )
			for ( module in set )
				if ( Std.is(module,UFInitRequired) )
					modules.push( cast module );
		return modules;
	}

	/**
	Add one or more `UFRequestMiddleware` modules to this HttpApplication. This method is chainable.
	**/
	inline public function addRequestMiddleware( ?middlewareItem:UFRequestMiddleware, ?middleware:Iterable<UFRequestMiddleware>, ?first:Bool=false ):HttpApplication
		return addModule( requestMiddleware, middlewareItem, middleware, first );

	/**
	Add one or more `UFRequestHandler` modules to this HttpApplication. This method is chainable.
	**/
	inline public function addRequestHandler( ?handler:UFRequestHandler, ?handlers:Iterable<UFRequestHandler>, ?first:Bool=false ):HttpApplication
		return addModule( requestHandlers, handler, handlers, first );

	/**
	Add one or more `UFErrorHandler` modules to this HttpApplication. This method is chainable.
	**/
	inline public function addErrorHandler( ?handler:UFErrorHandler, ?handlers:Iterable<UFErrorHandler>, ?first:Bool=false ):HttpApplication
		return addModule( errorHandlers, handler, handlers, first );

	/**
	Add one or more `UFRequestMiddleware` modules to this HttpApplication. This method is chainable.
	**/
	inline public function addResponseMiddleware( ?middlewareItem:UFResponseMiddleware, ?middleware:Iterable<UFResponseMiddleware>, ?last:Bool=false ):HttpApplication
		return addModule( responseMiddleware, middlewareItem, middleware, !last );

	/**
	Add one or more `UFMiddleware` modules to this HttpApplication. This method is chainable.
	**/
	public function addMiddleware( ?middlewareItem:UFMiddleware, ?middleware:Iterable<UFMiddleware>, ?firstInLastOut:Bool=false ):HttpApplication {
		addRequestMiddleware( middlewareItem, middleware, firstInLastOut );
		addResponseMiddleware( middlewareItem, middleware, firstInLastOut );
		return this;
	}

	/**
	Add one or more `UFLogHandler` modules to this HttpApplication. This method is chainable.
	**/
	inline public function addLogHandler( ?logger:UFLogHandler, ?loggers:Iterable<UFLogHandler>, ?first:Bool=false ):HttpApplication
		return addModule( logHandlers, logger, loggers, first );

	function addModule<T>( modulesArr:Array<T>, ?newModule:T, ?newModules:Iterable<T>, first:Bool ):HttpApplication {
		if (newModule!=null) {
			injector.injectInto( newModule );
			if (first) modulesArr.unshift( newModule );
			else modulesArr.push( newModule );
		};
		if (newModules!=null) for (newModule in newModules) {
			injector.injectInto( newModule );
			if (first) modulesArr.unshift( newModule );
			else modulesArr.push( newModule );
		};
		return this;
	}

	/**
	Execute the current request, passing the HttpContext through each module until the request is complete.

	**Execution Chain:**

	- Setting the URL filters on the HttpContext.
	- Running `this.init()` to make sure all modules are initialized and ready to receive requests.
	- Executing each `UFRequestMiddleware` module, in order.
	- Executing each `UFRequestHandler` module, in order, until one of them is able to handle and process our request.
	- Executing each `UFResponseMiddleware` module, in order.
	- Executing each `UFLogHandler` module, in order, to log messages. We pass the current `HttpContext` and `this.appMessages` to each handler.
	- Flushing the response to the browser and concluding the request.

	Each module returns a `Surprise`, which is a `Future<Outcome>`.
	This waits until the module is complete, and returns either a `Success` (in which case we continue with the execute chain) or a `Failure`, in which case we handle the error.

	If errors occur (an unhandled exception is thrown or an `Outcome.Failure` is returned by one of the modules), we will then abandon the execution chain and work through the error handling chain.

	**Error Handling Chain:**

	- Executing each `UFErrorHandler` module, in order, passing the relevant `Error` and `HttpContext` objects.
	- Executing each `UFResponseMiddleware` module, in order, if they haven't already been run.
	- Executing all  `UFLogHandler` module, in order, if they haven't already been run.
	- Flushing the response to the browser and concluding the request.
	- If any exceptions are thrown or failures encountered during the error handling chain, an exception will be thrown, so please be careful that middleware, error handlers and log handlers fail gracefully.

	**Marking a stage as "complete":**

	Before executing any module in either the `execute` chain or the `handleError` chain, we check `HttpContext.completion` to see if the current request stage has been marked as completed.
	If the current stage has been marked as complete, the remaining modules in that stage will be skipped and the execution chain will continue from the next stage.

	**Breaking the asynchronous chain:**

	If any modules return a `Surprise` that fails to trigger, the asynchronous call chain will be broken and the request will fail to complete.
	The synchronous platforms (Neko and PHP), when compiled with `-debug`, will alert you to which module in the chain failed to trigger correctly.
	At this stage there is no time-out functionality, so please be careful that all modules always return and trigger a valid Future.
	**/
	@:access(ufront.web.context.HttpContext)
	public function execute( httpContext:HttpContext ):Surprise<Noise,Error> {
		httpContext.setUrlFilters( urlFilters );

		var reqMidModules = requestMiddleware.map(
			function(m) return new Pair(
				m.requestIn.bind(),
				HttpError.fakePosition( m, "requestIn", [] )
			)
		);
		var reqHandModules = requestHandlers.map(
			function(m) return new Pair(
				m.handleRequest.bind(),
				HttpError.fakePosition( m, "handleRequest", [] )
			)
		);
		var resMidModules = responseMiddleware.map(
			function(m) return new Pair(
				m.responseOut.bind(),
				HttpError.fakePosition( m, "requestOut", [] )
			)
		);
		var logHandModules = logHandlers.map(
			function(m) return new Pair(
				m.log.bind(_,messages),
				HttpError.fakePosition( m, "log", ['httpContext','appMessages'] )
			)
		);

		// Here we use the '>>' operator from `tink.core.Future`, which allows us to perform a `flatMap()` only when the `Surprise` returns a `Success`.
		// This is great for chaining operations together, and propagating the error from any stage through the chain.
		// The final future returned is for once the `flush()` call has completed, which will happen once all the modules have finished.
		// See https://github.com/haxetink/tink_core#operators

		var allDone =
			init() >>
			function (n:Noise) return executeModules( reqMidModules, httpContext, CRequestMiddlewareComplete ) >>
			function (n:Noise) return executeModules( reqHandModules, httpContext, CRequestHandlersComplete ) >>
			function (n:Noise) return executeModules( resMidModules, httpContext, CResponseMiddlewareComplete) >>
			function (n:Noise) return executeModules( logHandModules, httpContext, CLogHandlersComplete ) >>
			function (n:Noise) return clearMessages() >>
			function (n:Noise) return flush( httpContext );

		// We need an empty handler to make sure all the `executeModules` calls above fire correctly.
		// This seems to be tink_core trying to be clever with Lazy evaluation, and never performing the `flatMap` if it is never handled.
		allDone.handle( function() {} );

		#if (debug && (neko || php))
			// Do a quick check that the async code actually completed, and if not, inform which module dropped the ball.
			// For now we are only testing sync targets, in future we may provide a "timeout" on async targets to perform a similar test.
			if ( httpContext.completion.has(CFlushComplete)==false ) {
				var msg =
					'Async callbacks never completed for URI ${httpContext.getRequestUri()}:  ' +
					'The last active module was ${currentModule.className}.${currentModule.methodName}';
				throw msg;
			}
		#end

		return allDone;
	}

	/**
	Execute a collection of modules (middleware or handlers) in order, until either a certain flag is marked as complete for that request, or all the modules have completed sucessfully.

	Usage:

	```haxe
	var reqHandlerModules = requestHandlers.map(function (r) return new Pair(r.handleRequest, HttpError.fakePosition(r,"handleRequest",['httpContext'])));
	requestHandlersDone:Future<Noise> = executeModules( reqHandlerModules, httpContext, CRequestHandler );
	```

	Returns a future that will be a Success if the chain completed successfully, or a Failure containing the error otherwise.
	**/
	function executeModules( modules:Array<Pair<HttpContext->Surprise<Noise,Error>,Pos>>, ctx:HttpContext, ?flag:RequestCompletion ):Surprise<Noise,Error> {
		var done:FutureTrigger<Outcome<Noise,Error>> = Future.trigger();
		function runNext() {
			var m = modules.shift();
			if ( flag!=null && ctx.completion.has(flag) ) {
				done.trigger( Success(Noise) );
			}
			else if ( m==null ) {
				if (flag!=null)
					ctx.completion.set( flag );
				done.trigger( Success(Noise) );
			}
			else {
				var moduleCb = m.a;
				currentModule = m.b;
				var moduleResult =
					try moduleCb( ctx )
					catch ( e:Dynamic ) {
						ctx.ufLog( 'Caught error $e while executing module ${currentModule.className}.${currentModule.methodName} in HttpApplication.executeModules()' );
						Future.sync( Failure( HttpError.wrap(e,null,currentModule) ) );
					}
				moduleResult.handle( function (result) {
					switch result {
						case Success(_): runNext();
						case Failure(e): handleError(e, ctx, done);
					}
				});
			}
		};
		runNext();
		return done.asFuture();
	}

	/**
	Run through each of the error handlers, then the log handlers (if they haven't run already)

	Then mark the middleware and requestHandlers as complete, so the `execute` function can log, flush and finish the request.
	**/
	function handleError( err:Error, ctx:HttpContext, doneTrigger:FutureTrigger<Outcome<Noise,Error>> ):Void {
		if ( !ctx.completion.has(CErrorHandlersComplete) ) {

			var errHandlerModules = errorHandlers.map(
				function(m) return new Pair(
					m.handleError.bind(err),
					HttpError.fakePosition( m, "handleError", [err.toString()] )
				)
			);
			var resMidModules = responseMiddleware.map(
				function(m) return new Pair(
					m.responseOut.bind(),
					HttpError.fakePosition( m, "requestOut", [] )
				)
			);
			var logHandModules = logHandlers.map(
				function(m) return new Pair(
					m.log.bind(_,messages),
					HttpError.fakePosition( m, "log", ['httpContext','appMessages'] )
				)
			);

			var allDone =
				executeModules( errHandlerModules, ctx, CErrorHandlersComplete ) >>
				function (n:Noise) {
					// Mark the handler as complete.  (It will continue on with the Middleware, Logging and Flushing stages)
					ctx.completion.set( CRequestHandlersComplete );
					return SurpriseTools.success();
				} >>
				function (n:Noise) return executeModules( resMidModules, ctx, CResponseMiddlewareComplete) >>
				function (n:Noise) return executeModules( logHandModules, ctx, CLogHandlersComplete ) >>
				function (n:Noise) return clearMessages() >>
				function (n:Noise) return flush( ctx );

			allDone.handle( doneTrigger.trigger.bind(Failure(err)) );
		}
		else {
			// This is bad: we are in `handleError` after `handleError` has already been called...
			// This means an error was thrown in one of:
			//   - the ErrorHandlers
			//   - the LogHandlers
			//   - the ResponseMiddleware
			//   - the "flush" stage...
			// rethrow the error, and hopefully they'll come to this line number and figure out what happened.
			var msg = 'You had an error after your error handler had already run.  Last active module: ${currentModule.className}.${currentModule.methodName}';
			#if neko
				Sys.println(msg);
				Sys.println('Error Data: ${err.data}');
				neko.Lib.rethrow( err );
			#else
				throw '$msg. \n$err. \nError data: ${err.data}';
			#end
		}
	}

	function clearMessages():Surprise<Noise,Error> {
		for ( i in 0...messages.length ) {
			messages.pop();
		}
		return SurpriseTools.success();
	}

	function flush( ctx:HttpContext ):Noise {
		if ( !ctx.completion.has(CFlushComplete) ) {
			ctx.response.flush();
			ctx.completion.set(CFlushComplete);
		}
		return Noise;
	}

	#if (php || neko || (js && !nodejs))
	/**
	Create a `HttpContext` for the current request and execute it.

	Available on PHP, Neko and Client JS.
	**/
	public function executeRequest() {
		var context =
			if ( pathToContentDir!=null ) HttpContext.createContext( this.injector, urlFilters, pathToContentDir )
			else HttpContext.createContext( this.injector, urlFilters );
		this.execute( context );
	}
	#elseif nodejs
	/**
	Start a HTTP server using `express.Express`, listening on the specified port.
	Includes the `Express.serveStatic()` middleware.
	Will create a HttpContext and execute each request.

	Available on NodeJS only.

	@param port The port to listen on (default 2987).
	**/
	public function listen( ?port:Int=2987 ):Void {
		var app = new express.Express();
		app.use( express.Express.serveStatic(".") );
		// TODO: check if we need to use a mw.BodyParser() middleware here.
		var ufAppMiddleware:express.Middleware = function(req:express.Request,res:express.Response,next:express.Error->Void) {
			var context:HttpContext =
				if ( pathToContentDir!=null ) HttpContext.createNodeJsContext( req, res, injector, urlFilters, pathToContentDir )
				else HttpContext.createNodeJsContext( req, res, urlFilters );
			this.execute( context ).handle( function(result) switch result {
				case Failure( err ): next( new express.Error(err.toString()) );
				default: next( null );
			});
		};
		app.use( ufAppMiddleware );
		app.listen( port );
	}
	#end

	/**
	Use `neko.Web.cacheModule` to speed up requests if using neko and not using `-debug`.

	Using `cacheModule` will cause your app to execute normally on the first load, but then:

	- Keep the module loaded in memory on the server for subsequent page loads
	- Keep static variables initialised, so their values are kept between requests
	- Skip straight to our `executeRequest` function for each new request

	A few things to note:

	- This will have no effect on platforms other than Neko.
	- This will have no effect if you compile with `-debug`.
	- If you have multiple simultaneous requests, mod_neko may load up several instances of the module, and keep all of them cached, and pick one for each request.
	- Using `nekotools server` fails to clear the cache after you re-compile. You can either restart the server, or compile with `-debug` to avoid this problem.
	**/
	public function useModNekoCache():Void {
		#if (neko && !debug)
			neko.Web.cacheModule( executeRequest );
		#end
	}

	/**
	Add a URL filter to be used in `HttpContext.getRequestUri` and `HttpContext.generateUri`.
	This will take effect from the next request to execute, it will not affect a currently executing request.
	**/
	public function addUrlFilter( filter:UFUrlFilter ):Void {
		HttpError.throwIfNull( filter, "filter" );
		urlFilters.push( filter );
	}

	/**
	Remove existing URL filters.
	This will take effect from the next request to execute, it will not affect a currently executing request.
	**/
	public function clearUrlFilters():Void {
		urlFilters = [];
	}

	/**
	Set the relative path to the content directory.
	This will take effect from the next request to execute, it will not affect a currently executing request.
	**/
	public function setContentDirectory( relativePath:String ):Void {
		pathToContentDir = relativePath;
	}
}
