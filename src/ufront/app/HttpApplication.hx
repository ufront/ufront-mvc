package ufront.app;

#if macro
	import haxe.macro.Expr;
	using tink.MacroApi;
#end
import ufront.web.url.filter.UFUrlFilter;
import ufront.core.Sync;
import minject.Injector;
import ufront.app.UFMiddleware;
import ufront.web.context.HttpContext;
import ufront.auth.*;
import ufront.web.HttpError;
import ufront.log.Message;
import thx.error.NullArgument;
import haxe.PosInfos;
import tink.core.Error.Pos;
using tink.CoreApi;

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
	var modulesReady:Surprise<Noise,HttpError>;

	/** A position representing the current module.  Useful for diagnosing if something in our async chain never completed. **/
	var currentModule:Pos;

	///// End Events /////

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
		Shortcut to map a class into `injector`.  

		- If `val` is supplied, `injector.mapValue( cl, val, ?named )` will be used
		- Otherwise, if `singleton` is true, `injector.mapSingleton( cl, ?named )`
		- Otherwise, `injector.mapClass( cl, cl2, ?named )`

		Singleton is false by default.

		If `cl2` is not supplied, but `mapSingleton` or `mapClass` is used, `cl` will be used in it's place.

		If a name is supplied, the mapping will be for that specific name.

		This method is chainable.
	**/
	public function inject<T>( cl:Class<T>, ?val:T, ?cl2:Class<T>, ?singleton=false, ?named:String ):HttpApplication {
		if ( val!=null ) injector.mapValue( cl, val, named )
		else {
			if (cl2==null) 
				cl2 = cl;
			if ( singleton ) 
				injector.mapSingleton( cl, named );
			else 
				injector.mapClass( cl, cl2, named );
		}
		return this;
	}

	/**
		Perform `init()` on any handlers or middleware that require it
	**/
	public function init():Surprise<Noise,HttpError> {
		if ( modulesReady==null ) {
			var futures = [];
			for ( module in getModulesThatRequireInit() )
				futures.push( module.init(this) );
			modulesReady = Future.ofMany( futures ).map( function(outcomes:Array<Outcome<Noise,HttpError>>) { 
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
	public function dispose():Surprise<Noise,HttpError> {
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
	inline public function addRequestMiddleware( ?middlewareItem:UFRequestMiddleware, ?middleware:Iterable<UFRequestMiddleware> ):HttpApplication
		return addModule( requestMiddleware, middlewareItem, middleware );

	/**
		Add one or more `UFRequestHandler`s to this HttpApplication. This method is chainable.
	**/
	inline public function addRequestHandler( ?handler:UFRequestHandler, ?handlers:Iterable<UFRequestHandler> ):HttpApplication
		return addModule( requestHandlers, handler, handlers );

	/**
		Add one or more `UFErrorHandler`s to this HttpApplication. This method is chainable.
	**/
	inline public function addErrorHandler( ?handler:UFErrorHandler, ?handlers:Iterable<UFErrorHandler> ):HttpApplication
		return addModule( errorHandlers, handler, handlers );

	/**
		Add one or more `UFRequestMiddleware` items to this HttpApplication. This method is chainable.
	**/
	inline public function addResponseMiddleware( ?middlewareItem:UFResponseMiddleware, ?middleware:Iterable<UFResponseMiddleware> ):HttpApplication
		return addModule( responseMiddleware, middlewareItem, middleware );

	/**
		Add some `UFRequestMiddleware` to this HttpApplication. This method is chainable.
	**/
	inline public function addLogHandler( ?logger:UFLogHandler, ?loggers:Iterable<UFLogHandler> ):HttpApplication
		return addModule( logHandlers, logger, loggers );

	function addModule<T>( modulesArr:Array<T>, ?newModule:T, ?newModules:Iterable<T> ):HttpApplication {
		if (newModule!=null) { 
			injector.injectInto( newModule ); 
			modulesArr.push( newModule ); 
		};
		if (newModules!=null) for (newModule in newModules) { 
			injector.injectInto( newModule ); 
			modulesArr.push( newModule ); 
		};
		return this;
	}

	/** 
		Execute the request

		Ṫhis involves:
	
		- Creating the HttpContext if not supplied, and set the URL filters
		- Firing all `UFRequestMiddleware`, in order
		- Using the various `UFRequestHandler`s, until one of them is able to handle and process our request.
		- Firing all `UFResponseMiddleware`, in order
		- Logging any messages (traces, logs, warnings, errors) that occured during the request
		- Flushing the response to the browser and concluding the request

		If errors occur (an unhandled exception or `ufront.core.Outcome.Failure`), we will run through each of the `UFErrorHandler`s.  These may print a nice error message, provide diagnostic / logging tools etc. 

		If at any point errors occur, the chain stops, and `onApplicationError` is triggered, followed by running `_conclude()`
		If at any point this HttpApplication is marked as complete, the chain stops and `_conclude()` is run.
	**/
	@:access(ufront.web.context.HttpContext)
	public function execute( ?httpContext:HttpContext ):Surprise<Noise,HttpError> {
		
		if (httpContext == null) httpContext = HttpContext.create( injector, urlFilters );
		else httpContext.setUrlFilters( urlFilters );

		var reqMidModules = prepareModules(requestMiddleware,"requestIn");
		var reqHandModules = prepareModules(requestHandlers,"handleRequest");
		var resMidModules = prepareModules(responseMiddleware,"responseOut");
		var logHandModules = prepareModules(logHandlers,"log",[_,messages]);
		
		// Here `>>` does a Future flatMap, so each call to `executeModules()` returns a Future,
		// once that Future is done, it does the next `executeModules()`.  The final future returned
		// is for once the `flush()` call has completed, which will happen once all the modules are done
		
		var allDone = 
			init() >>
			function (n:Noise) return executeModules( reqMidModules, httpContext, CRequestMiddlewareComplete ) >>
			function (n:Noise) return executeModules( reqHandModules, httpContext, CRequestHandlersComplete ) >>
			function (n:Noise) return executeModules( resMidModules, httpContext, CResponseMiddlewareComplete) >> 
			function (n:Noise) return executeModules( logHandModules, httpContext, CLogHandlersComplete ) >>
			function (n:Noise) return flush( httpContext );

		// Why does nothing happen unless there is a handle applied?  Need to ask Juraj...
		allDone.handle( function() {} );

		#if (debug && (neko || php))
			// Do a quick check that the async code actually completed, and if not, inform which module dropped the ball.
			// For now we are only testing sync targets, in future we may provide a "timeout" on async targets to perform a similar test.
			if ( httpContext.completion.has(CFlushComplete)==false ) {
				// We need to prevent macro-time seeing this code as "Pos" for them is "haxe.macro.Pos" not "haxe.PosInfos"
				var msg = 'Async callbacks never completed.  ';
				#if !macro
					msg += 'The last active module was ${currentModule.className}.${currentModule.methodName}(${currentModule.customParams.join(", ")})';
				#end
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

		Returns a future that will prove
	**/
	function executeModules( modules:Array<Pair<HttpContext->Surprise<Noise,HttpError>,Pos>>, ctx:HttpContext, ?flag:RequestCompletion ):Surprise<Noise,HttpError> {
		var done:FutureTrigger<Outcome<Noise,HttpError>> = Future.trigger();
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
						#if (debug && !macro) ctx.ufLog( 'Caught error $e while executing module ${currentModule.className}.${currentModule.methodName} in HttpApplication.executeModules()' ); #end
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
	function handleError( err:HttpError, ctx:HttpContext, doneTrigger:FutureTrigger<Outcome<Noise,HttpError>> ):Void {
		if ( !ctx.completion.has(CErrorHandlersComplete) ) {

			var errHandlerModules = prepareModules(errorHandlers,"handleError",[err]);

			var allDone = 
				executeModules( errHandlerModules, ctx, CErrorHandlersComplete ) >>
				function (n:Noise) {
					// Mark the handler as complete.  (It will continue on with the Middleware, Logging and Flushing stages)
					ctx.completion.set( CErrorHandlersComplete );
					ctx.completion.set( CRequestHandlersComplete );
					return Sync.success();
				};

			allDone.handle( doneTrigger.trigger.bind(Failure(err)) );
		}
		else {
			// This is bad: we are in `handleError` after `handleError` has already been called...
			// This means an error was thrown in one of:
			//   - the ErrorHandlers
			//   - the LogHandlers
			//   - the "flush" stage...
			// rethrow the error, and hopefully they'll come to this line number and figure out what happened.
			var msg = 'You had an error after your error handler had already run.  Last active module: $currentModule.';
			throw '$msg  $err. Error data: ${err.data}';
		}
	}

	function flush( ctx:HttpContext ):Noise {
		if ( !ctx.completion.has(CFlushComplete) ) {
			ctx.response.flush();
			ctx.completion.set(CFlushComplete);
		}
		return Noise;
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
		Given a bunch of modules (handlers,middleware) and the name of the method on that 
		module, return a 

		`Array<Pair<(HttpContext->Surprise<Noise,HttpError>),PosInfos>>` 

		so we can execute them all in the same way.
	**/
	static macro function prepareModules( modules:ExprOf<Array<Dynamic>>, methodName:String, ?bindArgs:ExprOf<Array<Dynamic>> ):ExprOf<Array<Pair<HttpContext->Surprise<Noise,HttpError>,PosInfos>>> {
		
		var argsToBind:Array<Expr>;
		var argsForPos:Array<Dynamic> = [];

		switch bindArgs.expr {
			case EArrayDecl( args ):
				argsToBind = args;
				for ( a in args ) {
					if ( !a.isWildcard() ) 
						argsForPos.push( a );
					else
						argsForPos.push( "{HttpContext}" );
				}
			default:
				argsToBind = [];
				argsForPos = [];
		}

		var fakePos:Expr = macro HttpError.fakePosition( m, $v{methodName}, $v{argsForPos} );
		var boundMethod:Expr = macro m.$methodName.bind( $a{argsToBind} );

		return macro $modules.map( function(m) return new Pair($boundMethod,$fakePos) );
	}
}