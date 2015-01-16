package ufront.app;

import ufront.web.url.filter.UFUrlFilter;
import ufront.core.Sync;
import minject.Injector;
import ufront.app.UFMiddleware;
import ufront.web.context.HttpContext;
import ufront.web.HttpError;
import ufront.auth.*;
import ufront.log.Message;
import thx.core.error.NullArgument;
import haxe.PosInfos;
import tink.core.Error.Pos;
using tink.CoreApi;
using ufront.core.InjectionTools;

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
		- An ICacheStore implementation
		- An IMailer implementation

		etc.

		This will be made available to the following:

		- Any Middleware - see `ufront.app.UFMiddleware` - for example, RemotingModule, DispatchModule or CacheModule
		- Any request handlers, error or log handlers - see `ufront.app.UFRequestHandler` and `ufront.app.UFErrorHandler`
		- Any child injectors, for example, "controllerInjector" or "apiInjector" in `UfrontApplication`

		By default, any handlers or middleware you add will be added to the injector also.
	**/
	public var injector:Injector;

	/**
		Middleware to be used in the application, before the request is processed.
	**/
	public var requestMiddleware(default,null):Array<UFRequestMiddleware>;

	/**
		Handlers that can process this request and write a response.

		Examples:

		 - `ufront.handler.DispatchHandler`
		 - `ufront.handler.RemotingHandler`
		 - StaticHandler (share static files over HTTP)
		 - SASS handler (compile *.css requests from *.sass files using the SASS compiler)
	**/
	public var requestHandlers(default,null):Array<UFRequestHandler>;

	/**
		Middleware to be used in the application, after the request is processed.
	**/
	public var responseMiddleware(default,null):Array<UFResponseMiddleware>;

	/**
		Log handlers to use for traces, logs, warnings and errors.

		These may write to log files, trace to the browser console etc.
	**/
	public var logHandlers(default,null):Array<UFLogHandler>;

	/**
		Error handlers to use if unhandled exceptions or Failures occur.

		These may write to log files, help with debugging, present error pages to the browser etc.
	**/
	public var errorHandlers(default,null):Array<UFErrorHandler>;

	/**
		UrlFilters for the current application.
		These will be used in the HttpContext for `getRequestUri` and `generateUri`.
		See `addUrlFilter()` and `clearUrlFilters()` below.
		Modifying this list will take effect at the beginning of the next `execute()` request.
	**/
	public var urlFilters(default,null):Array<UFUrlFilter>;

	/**
		Messages (traces, logs, warnings, errors) that are not associated with a specific request.
	**/
	public var messages:Array<Message>;

	/**
		A future trigger, for internal use, that lets us tell if all our modules (middleware and handlers) are ready for use
	**/
	var modulesReady:Surprise<Noise,Error>;

	/** A position representing the current module.  Useful for diagnosing if something in our async chain never completed. **/
	var currentModule:Pos;

	/** The (relative) path to the content directory. **/
	var pathToContentDir:String = null;

	/**
		Start a new HttpApplication

		Depending on the platform, this may run multiple requests or it may be created per request.

		The constructor will initialize each of the events, and add a single `onPostLogRequest` event handler to make sure logs are not executed twice in the event of an error.

		After creating the application, you can initialize the modules and then execute requests with a given HttpContext.
	**/
	@:access(ufront.web.context.HttpContext)
	public function new() {
		// Set up injector
		injector = new Injector();
		injector.mapValue( Injector, injector );

		// Set up modules
		requestMiddleware = [];
		requestHandlers = [];
		responseMiddleware = [];
		logHandlers = [];
		errorHandlers = [];

		// Set up URL Filters...
		urlFilters = [];

		// Set up custom trace.  Will save messages to the `messages` array, and let modules log as they desire.
		messages = [];
		haxe.Log.trace = function(msg:Dynamic, ?pos:PosInfos) {
			messages.push({ msg: msg, pos: pos, type: Trace });
		}
	}

	/**
		Shortcut to map a class or value into `injector`.

		See `ufront.core.InjectorTools.inject()` for details on how the injections are applied.

		This method is chainable.
	**/
	public function inject<T>( cl:Class<T>, ?val:T, ?cl2:Class<T>, ?singleton:Bool=false, ?named:String ):HttpApplication {
		injector.inject( cl, val, cl2, singleton, named );
		return this;
	}

	/**
		Perform `init()` on any handlers or middleware that require it
	**/
	public function init():Surprise<Noise,Error> {
		if ( modulesReady==null ) {
			var futures = [];
			for ( module in getModulesThatRequireInit() )
				futures.push( module.init(this) );
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
		Perform `dispose()` on any handlers or middleware that require it
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
		Add one or more `UFRequestMiddleware` items to this HttpApplication. This method is chainable.
	**/
	inline public function addRequestMiddleware( ?middlewareItem:UFRequestMiddleware, ?middleware:Iterable<UFRequestMiddleware>, ?first:Bool=false ):HttpApplication
		return addModule( requestMiddleware, middlewareItem, middleware, first );

	/**
		Add one or more `UFRequestHandler`s to this HttpApplication. This method is chainable.
	**/
	inline public function addRequestHandler( ?handler:UFRequestHandler, ?handlers:Iterable<UFRequestHandler>, ?first:Bool=false ):HttpApplication
		return addModule( requestHandlers, handler, handlers, first );

	/**
		Add one or more `UFErrorHandler`s to this HttpApplication. This method is chainable.
	**/
	inline public function addErrorHandler( ?handler:UFErrorHandler, ?handlers:Iterable<UFErrorHandler>, ?first:Bool=false ):HttpApplication
		return addModule( errorHandlers, handler, handlers, first );

	/**
		Add one or more `UFRequestMiddleware` items to this HttpApplication. This method is chainable.
	**/
	inline public function addResponseMiddleware( ?middlewareItem:UFResponseMiddleware, ?middleware:Iterable<UFResponseMiddleware>, ?first:Bool=false ):HttpApplication
		return addModule( responseMiddleware, middlewareItem, middleware, first );

	/**
		Add some `UFRequestMiddleware` to this HttpApplication. This method is chainable.
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
		Execute the request

		Ṫhis involves:

		- Setting the URL filters on the HttpContext.
		- Firing all `UFRequestMiddleware`, in order
		- Using the various `UFRequestHandler`s, until one of them is able to handle and process our request.
		- Firing all `UFResponseMiddleware`, in order
		- Logging any messages (traces, logs, warnings, errors) that occured during the request
		- Flushing the response to the browser and concluding the request

		If errors occur (an unhandled exception or `ufront.core.Outcome.Failure` is returned by one of the modules), we will run through each of the `UFErrorHandler`s.
		These may print a nice error message, provide recover, diagnostics, logging etc.

		Each module can modify `HttpContext.completion` to cause certain parts of the request life-cycle to be skipped.
	**/
	@:access(ufront.web.context.HttpContext)
	public function execute( httpContext:HttpContext ):Surprise<Noise,Error> {

		httpContext.setUrlFilters( urlFilters );

		var reqMidModules = HttpApplicationMacros.prepareModules(requestMiddleware,"requestIn");
		var reqHandModules = HttpApplicationMacros.prepareModules(requestHandlers,"handleRequest");
		var resMidModules = HttpApplicationMacros.prepareModules(responseMiddleware,"responseOut");
		var logHandModules = HttpApplicationMacros.prepareModules(logHandlers,"log",[_,messages]);

		// Here `>>` does a Future flatMap, so each call to `executeModules()` returns a Future, once that Future is done, it does the next `executeModules()`.
		// The final future returned is for once the `flush()` call has completed, which will happen once all the modules have finished.

		var allDone =
			init() >>
			function (n:Noise) return executeModules( reqMidModules, httpContext, CRequestMiddlewareComplete ) >>
			function (n:Noise) return executeModules( reqHandModules, httpContext, CRequestHandlersComplete ) >>
			function (n:Noise) return executeModules( resMidModules, httpContext, CResponseMiddlewareComplete) >>
			function (n:Noise) return executeModules( logHandModules, httpContext, CLogHandlersComplete ) >>
			function (n:Noise) return clearMessages() >>
			function (n:Noise) return flush( httpContext );

		// We need an empty handler to make sure all the `executeModules` calls above fire correctly.
		// This may be tink_core trying to be clever with Lazy evaluation, and never performing the `flatMap` if it is never handled.
		allDone.handle( function() {} );

		#if (debug && (neko || php))
			// Do a quick check that the async code actually completed, and if not, inform which module dropped the ball.
			// For now we are only testing sync targets, in future we may provide a "timeout" on async targets to perform a similar test.
			if ( httpContext.completion.has(CFlushComplete)==false ) {
				// We need to prevent macro-time seeing this code as "Pos" for them is "haxe.macro.Pos" not "haxe.PosInfos"
				var msg =
				    'Async callbacks never completed for URI ${httpContext.getRequestUri()}:  ' +
				    'The last active module was ${currentModule.className}.${currentModule.methodName}';
				throw msg;
			}
		#end

		return allDone;
	}

	/**
		Given a collection of modules (middleware or handlers, anything that returns Future<Void>),
		execute the modules one at a time, waiting for each to finish before starting the next one.

		If a `RequestCompletion` flag is provided, modules will not run if the request has that completion
		flag already set.  Once all the modules have run, it will set the flag.

		Usage:

		`requestHandlersDone:Future<Noise> = executeModules( requestHandlers.map(function (r) return new Pair(Type.getClassName(Type.getClass(r)), r.handleRequest)), httpContext, CRequestHandler );`

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

			var errHandlerModules = HttpApplicationMacros.prepareModules(errorHandlers,"handleError",[err]);
			var resMidModules = HttpApplicationMacros.prepareModules(responseMiddleware,"responseOut");
			var logHandModules = HttpApplicationMacros.prepareModules(logHandlers,"log",[_,messages]);

			var allDone =
				executeModules( errHandlerModules, ctx, CErrorHandlersComplete ) >>
				function (n:Noise) {
					// Mark the handler as complete.  (It will continue on with the Middleware, Logging and Flushing stages)
					ctx.completion.set( CRequestHandlersComplete );
					return Sync.success();
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
			//   - the "flush" stage...
			// rethrow the error, and hopefully they'll come to this line number and figure out what happened.
			var msg = 'You had an error after your error handler had already run.  Last active module: ${currentModule.className}.${currentModule.methodName}';
			throw '$msg. \n$err. \nError data: ${err.data}';
		}
	}

	function clearMessages():Surprise<Noise,Error> {
		for ( i in 0...messages.length ) {
			messages.pop();
		}
		return Sync.success();
	}

	function flush( ctx:HttpContext ):Noise {
		if ( !ctx.completion.has(CFlushComplete) ) {
			ctx.response.flush();
			ctx.completion.set(CFlushComplete);
		}
		return Noise;
	}

	#if (php || neko)
		/**
			Create a HTTPContext for the current request and execute it.

			This will ensure that the current injector and it's mappings are included in the HttpContext.
			Available on PHP and Neko.
		**/
		public function executeRequest() {
			var context =
				if ( pathToContentDir!=null ) HttpContext.createSysContext( this.injector, urlFilters, pathToContentDir )
				else HttpContext.createSysContext( this.injector, urlFilters );
			this.execute( context );
		}
	#elseif nodejs
		/**
			Start a HTTP server using `js.npm.Express`, listening on the specified port.
			Includes the `js.npm.connect.Static` and `js.npm.connect.BodyParser` middleware.
			Will create a HttpContext and execute each request.

			@param port The port to listen on (default 2987).

			NodeJS only.
		**/
		public function listen( ?port:Int=2987 ):Void {
			var app = new js.npm.Express();
			app.use( new js.npm.connect.Static('.') );
			app.use( new js.npm.connect.BodyParser() );
			app.use( function(req:js.npm.express.Request,res:js.npm.express.Response,next:?String->Void) {
				var context:HttpContext = 
					if ( pathToContentDir!=null ) HttpContext.createNodeJSContext( req, res, urlFilters, pathToContentDir )
					else HttpContext.createNodeJSContext( req, res, urlFilters );
				this.execute( context ).handle( function(result) switch result {
					case Failure( err ): next( err.toString() );
					default: next();
				});
			});
			app.listen( port );
		}
	#end
	
	/**
		Use `neko.Web.cacheModule` to speed up requests if using neko and not using `-debug`.
		
		Using `cacheModule` will cause your app to execute normally on the first load, but subsequent loads will:
		
		- Keep the module loaded
		- Keep static variables initialised
		- Skip straight to our `executeRequest` function for each new request
		
		A few things to note:
		
		- This will have no effect on platforms other than Neko.
		- This will have no effect if you compile with `-debug`.
		- If you have multiple simultaneous requests, mod_neko may load up several instances of the module, and keep all of them cached, and pick one for each request.
		- Using `nekotools server` sometimes fails to clear the cache after you re-compile. You can either restart the server, or compile with `-debug` to avoid this problem.
	**/
	public function useModNekoCache():Void {
		#if (neko && !debug)
			neko.Web.cacheModule( executeRequest );
		#end
	}

	/**
		Add a URL filter to be used in the HttpContext for `getRequestUri` and `generateUri`
	**/
	public function addUrlFilter( filter:UFUrlFilter ):Void {
		NullArgument.throwIfNull( filter );
		urlFilters.push( filter );
	}

	/**
		Remove existing URL filters
	**/
	public function clearUrlFilters():Void {
		urlFilters = [];
	}

	/**
		Set the relative path to the content directory.
	**/
	public function setContentDirectory( relativePath:String ):Void {
		pathToContentDir = relativePath;
	}
}
