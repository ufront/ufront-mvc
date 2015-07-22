package ufront.web.context;

#if !macro
	import haxe.EnumFlags;
	import haxe.io.Path;
	import haxe.PosInfos;
	import minject.Injector;
	import ufront.auth.NobodyAuthHandler;
	import ufront.auth.UFAuthUser;
	import ufront.log.Message;
	import ufront.log.MessageList;
	import ufront.web.url.filter.UFUrlFilter;
	import ufront.web.session.*;
	import ufront.auth.*;
	import ufront.web.url.*;
	import ufront.web.url.filter.*;
	import tink.CoreApi;
	using ufront.core.InjectionTools;
#end

/**
A context object holding all the information relevant to the current request.

A single `HttpApplication` object can serve multiple requests, but each request is given a `HttpContext` holding together all the parts of the request.

This `HttpContext` is used throughout the request lifecycle and different parts of the application - being available in controllers, middleware, request handlers, error handlers and more.
**/
class HttpContext {

	#if (php || neko || (js && !nodejs))
		/**
		Create a HttpContext for the current environment.

		If request and response are not supplied, they will created.
		The rest of the parameters are passed directly to the `HttpContext` constructor.

		On NodeJS please use `HttpContext.createNodeJsContext()` instead.
		**/
		public static function createContext( ?request:HttpRequest, ?response:HttpResponse, ?appInjector:Injector, ?session:UFHttpSession, ?auth:UFAuthHandler, ?urlFilters:Array<UFUrlFilter>, ?relativeContentDir="uf-content" ) {
			if( null==request ) request = HttpRequest.create();
			if( null==response ) response = HttpResponse.create();
			return new HttpContext( request, response, appInjector, session, auth, urlFilters, relativeContentDir );
		}
	#elseif (js && nodejs && !macro)
		/**
		Create a HttpContext for the NodeJS environment, using the [express][1] haxelib.

		The native express-js request and response objects must be supplied.

		The rest of the parameters are passed directly to the `HttpContext` constructor.

		[1]: https://github.com/abedev/hxexpress
		**/
		public static function createNodeJsContext( req:express.Request, res:express.Response, ?appInjector:Injector, ?session:UFHttpSession, ?auth:UFAuthHandler, ?urlFilters:Array<UFUrlFilter>, ?relativeContentDir="uf-content" ) {
			var request:HttpRequest = new nodejs.ufront.web.context.HttpRequest( req );
			var response:HttpResponse = new nodejs.ufront.web.context.HttpResponse( res );
			return new HttpContext( request, response, appInjector, session, auth, urlFilters, relativeContentDir );
		}
	#end

	/**
	An dependency injector for the current request.

	By default, mappings are provided for the following classes:

	- `ufront.web.context.HttpContext`
	- `ufront.web.context.HttpRequest`
	- `ufront.web.context.HttpResponse`
	- `ufront.web.context.ActionContext`
	- `ufront.log.MessageList`
	- `ufront.web.session.UFHttpSession` (and the implementation class used for the session).
	- `ufront.auth.UFAuthHandler` (and the implementation class used for the auth handler).

	When used in a HttpApplication, each call to `execute` will set the application's injector as this context's parent injector.
	This means all mappings at the application level will be available in the request injector too.
	**/
	public var injector(default,null):Injector;

	/** The current `HttpRequest`. **/
	public var request(default,null):HttpRequest;

	/** The current `HttpResponse`. **/
	public var response(default,null):HttpResponse;

	/**
	The current session.

	If this is not set during the constructor, then a `UFHttpSession` will be injected.
	If that fails, a `VoidSession` will be used.
	**/
	public var session(default,null):UFHttpSession;

	/**
	The current session ID.

	This is a shortcut for `session.id`, but with extra null checking.
	**/
	public var sessionID(get,null):Null<String>;

	/**
	The current auth handler.

	If this is not set during the constructor, then a `UFAuthHandler` will be injected.
	If that fails, a `NobodyAuthHandler` will be used.
	**/
	public var auth(default,null):UFAuthHandler;

	/**
	The current user.

	This is a shortcut for `auth.currentUser`, but with extra null checking.
	**/
	public var currentUser(get,null):Null<UFAuthUser>;

	/**
	The current user ID.

	This is a shortcut for `auth.currentUser.id`, but with extra null checking.
	**/
	public var currentUserID(get,null):Null<String>;

	/**
	The `ActionContext` used in processing the request.

	This holds information about which action the current request is taking, and what result it returned.
	See `ActionContext` for more details.

	There is one `ActionContext` for each `HttpContext`, and it is created during the `HttpContext` constructor.
	**/
	public var actionContext(default,null):ActionContext;

	/**
	The completion progress of the current request. Setting these values will affect the flow of the request.

	For example, if a middleware restores a response from a cached entry matching the current request, it may want to skip the `RequestHandler` and any `ResponseMiddleware`:

	```haxe
	// Skip remaining request middleware, and the request handler (this will then skip to the response middleware)
	ctx.completion.set( CRequestMiddlewareComplete );
	ctx.completion.set( CRequestHandlerComplete );
	```

	Another example is if you have a controller or some code that writes directly to the output, not the response object, in which case you want to skip the log, flush, middleware etc.
	(This is the case with the `dbadmin` tool.)

	```haxe
	ctx.completion.set( CRequestHandlerComplete );
	ctx.completion.set( CResponseMiddlewareComplete );
	ctx.completion.set( CLogComplete );
	ctx.completion.set( CFlushComplete );
	```

	These values are updated by `HttpApplication` and various middleware and handlers, or you can update them manually.
	**/
	public var completion:EnumFlags<RequestCompletion>;

	/**
	The URL filters to be used for `this.getRequestUri()` and `this.generateUri()`.

	This value is set during the constructor.

	If you wish to change the filters after the request has begun, it is recommended you use `this.setUrlFilters()`.
	This will ensure that the uri for `getRequestUri` is not cached with the old filters.
	**/
	public var urlFilters(default,null):Array<UFUrlFilter>;

	/**
	A collection of messages that were traced during this request.
	**/
	public var messages:Array<Message>;

	/**
	Get the path of the content directory.

	This is a directory that ufront has write-access to, and should preferably not be available for general Http access.

	It can be used to store sessions, log files, cache, uploaded files etc.

	The value is essentially `${request.scriptDirectory}/$relativeContentDir/`, where `relativeContentDir` is the value that was supplied to the constructor.

	If using `ufront.application.UfrontApplication`, this value can be set with the `contentDirectory` setting in your `ufront.web.Configuration` initialization settings.

	The trailing slash is always included.
	**/
	public var contentDirectory(get,null):String;

	var _requestUri:String;
	var _relativeContentDir:String;
	var _contentDir:String;

	/**
	Create a HttpContext object using the supplied objects.

	For creating a context for each platform see `createContext` and `createNodeJSContext`.

	During the constructor, several items are initiated:

	- All of the parameters passed to the constructor are used.
	- `this.actionContext` is setup with a new `ActionContext`.
	- `this.injector` is setup, either as a child of the supplied `appInjector`, or as a brand new injector.
	- If the session is not supplied, an attempt will be made to inject a `UFHttpSession`. If that fails, a `VoidSession` will be used.
	- If the auth handler is not supplied, an attempt will be made to inject a `UFAuthHandler`. If that fails, a `NobodyAuthHandler` will be used.
	- Most of the parts of our context are mapped into the request injector. See the documentation of `this.injector` for more details.

	@param request (required) The current `HttpRequest`.
	@param response (required) The current `HttpResponse`.
	@param appInjector (optional) The `HttpApplication.injector`, which will be the parent injector for our request injector.
	@param session (optional) An existing session to be used. If not supplied one will be injected.
	@param auth (optional) An existing authentication handler to be used. If not supplied, one will be injected.
	@param urlFilters (optional) The URL Filters to use on the current request. If null, no filters will be used.
	@param relativeContentDir (optional) The path to the content directory, relative to the script directory. The default is "uf-content".
	**/
	public function new( request:HttpRequest, response:HttpResponse, ?appInjector:Injector, ?session:UFHttpSession, ?auth:UFAuthHandler, ?urlFilters:Array<UFUrlFilter>, ?relativeContentDir="uf-content" ) {
		HttpError.throwIfNull( response );
		HttpError.throwIfNull( request );

		this.request = request;
		this.response = response;
		this.urlFilters = ( urlFilters!=null ) ? urlFilters : [];
		this._relativeContentDir = relativeContentDir;
		this.actionContext = new ActionContext( this );
		this.messages = [];
		this.completion = new EnumFlags<RequestCompletion>();

		this.injector = (appInjector!=null) ? appInjector.createChildInjector() : new Injector();
		injector.map( HttpContext ).toValue( this );
		injector.map( HttpRequest ).toValue( request );
		injector.map( HttpResponse ).toValue( response );
		injector.map( ActionContext ).toValue( actionContext );
		injector.map( MessageList ).toValue( new MessageList(messages) );
		injector.map( Injector ).toValue( injector );

		if ( session!=null ) this.session = session;
		if ( this.session==null )
			try this.session = injector.getValue( UFHttpSession )
			catch(e:Dynamic) ufLog('Failed to load UFHttpSession: $e. Using VoidSession instead.'+haxe.CallStack.toString(haxe.CallStack.exceptionStack()));
		if ( this.session==null ) this.session = new VoidSession();
		injector.map( UFHttpSession ).toValue( this.session );
		injector.mapRuntimeTypeOf( this.session ).toValue( this.session );

		if ( auth!=null ) this.auth = auth;
		if ( this.auth==null )
			try this.auth = injector.getValue( UFAuthHandler )
			catch(e:Dynamic) ufLog('Failed to load UFAuthHandler: $e. Using NobodyAuthHandler instead.'+haxe.CallStack.toString(haxe.CallStack.exceptionStack()));
		if ( this.auth==null ) this.auth = new NobodyAuthHandler();
		injector.map( UFAuthHandler ).toValue( this.auth );
		injector.mapRuntimeTypeOf( this.auth ).toValue( this.auth );
	}

	/**
	Gets the filtered request URI.

	It uses the supplied `HttpRequest.uri`, but applies any of our `this.urlFilters` to transform the raw URI into a normalized state.

	For example, if you use `PathInfoUrlFilter` to filter `index.n?path=/home/`, this would return the normalized URI `/home/`.
	**/
	public function getRequestUri():String {
		if( null==_requestUri ) {
			var url = PartialUrl.parse( request.uri );
			for( filter in urlFilters )
				filter.filterIn( url );
			_requestUri = url.toString();
		}
		return _requestUri;
	}

	/**
	Takes a normalized ("clean") URI and applies filters to make it work with the server environment.

	For example, if you use `PathInfoUrlFilter` this could turn `/home/` into `index.n?path=/home/`.

	This is useful so your code contains the simple URIs, but at runtime they are transformed into the correct form depending on the environment.
	**/
	public function generateUri( uri:String, ?isPhysical:Bool=false ):String {
		var uriOut = VirtualUrl.parse( uri, isPhysical );
		var i = urlFilters.length - 1;
		while( i>=0 )
			urlFilters[i--].filterOut( uriOut );
		return uriOut.toString();
	}

	/**
	Sets the URL filters.

	It is recommended to keep the URL filters stable through a request, so try to set them as early as possible.
	They can be set during the constructor.
	**/
	public function setUrlFilters( filters ) {
		urlFilters = ( filters!=null ) ? filters : [];
		_requestUri = null;
	}

	/**
	Commit the session data, if there is any.

	@return A future letting you know when the session commit has been completed succesfully, or if an error was encountered.
	**/
	public function commitSession():Surprise<Noise,Error> {
		return
			if ( session!=null ) session.commit();
			else Future.sync( Success(Noise) );
	}

	/**
	A trace statement that will be associated with this HttpContext

	Because of the static nature of Haxe's `trace` (it always uses `haxe.Log.trace`, and that does not have access to information about our request), it can be hard to differentiate which traces belong to which requests.

	A workaround is to call HttpContext's ufTrace(), store our messages here, and output them at the end of the request.  You can call `httpContext.ufTrace(someValue)` just like you would any other trace, and the traces will be displayed as normal at the end of the request.

	Inline shortcuts are provided from `ufront.web.Controller` and `ufront.api.UFApi` so that you can call ufTrace() and it points to this method.
	**/
	public inline function ufTrace( msg:Dynamic, ?pos:PosInfos ) {
		messages.push({ msg: msg, pos: pos, type:Trace });
	}

	/**
	Create a Log message on the current request.

	Similar to ufTrace, except that the message is noted to be a Log, which may be displayed differently by the tracing module.
	**/
	public inline function ufLog( msg:Dynamic, ?pos:PosInfos ) {
		messages.push({ msg: msg, pos: pos, type:Log });
	}

	/**
	Create a Warning message on the current request.

	Similar to ufTrace, except that the message is noted to be a Warning, which may be displayed differently by the tracing module.
	**/
	public inline function ufWarn( msg:Dynamic, ?pos:PosInfos ) {
		messages.push({ msg: msg, pos: pos, type:Warning });
	}

	/**
	Create a Error message on the current request.

	Similar to ufTrace, except that the message is noted to be a Error, which may be displayed differently by the tracing module.

	Please note this does not throw or catch errors, it merely outputs a message to the log and marks that message as an error.
	It may be sensible to use it in your error handling code, but not _as_ your error handling code.
	**/
	public inline function ufError( msg:Dynamic, ?pos:PosInfos ) {
		messages.push({ msg: msg, pos: pos, type:Error });
	}

	public function toString() {
		return 'HttpContext';
	}

	inline function get_sessionID() {
		return (null!=session) ? session.id : null;
	}

	inline function get_currentUser() {
		return (null!=auth) ? auth.currentUser : null;
	}

	inline function get_currentUserID() {
		return (auth!=null && auth.currentUser!=null) ? auth.currentUser.userID : null;
	}

	function get_contentDirectory() {
		if ( _contentDir==null ) {
			if ( request.scriptDirectory!=null )
				_contentDir = Path.addTrailingSlash(request.scriptDirectory) + Path.addTrailingSlash( _relativeContentDir );
			else
				_contentDir = Path.addTrailingSlash( _relativeContentDir );
		}
		return _contentDir;

	}
}

/**
An enum describing which stages of the request have been completed.

This is used with `HttpContext.completion`, to help our apps know which stages of the request still need to be executed, and which are completed (or can be skipped).
**/
enum RequestCompletion {
	/** The "Request Middleware" stage is complete, no further `UFRequestMiddleware` modules need to run. **/
	CRequestMiddlewareComplete;
	/** The "Request Handler" stage is complete, no further `UFRequestHandler` modules need to run. **/
	CRequestHandlersComplete;
	/** The "Response Middleware" stage is complete, no further `UFResponseMiddleware` modules need to run. **/
	CResponseMiddlewareComplete;
	/** The "Logging" stage is complete, no further `UFLogHandler` modules need to run. **/
	CLogHandlersComplete;
	/** The "Flush" stage is complete, the `HttpResponse` does not need to be flushed. **/
	CFlushComplete;
	/** The Error Handlers have run, if any further error are encountered do not attempt to handle them. **/
	CErrorHandlersComplete;
}
