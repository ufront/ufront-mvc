package ufront.web.context;

import haxe.EnumFlags;
import haxe.io.Path;
import haxe.PosInfos;
import minject.Injector;
import ufront.auth.NobodyAuthHandler;
import ufront.auth.UFAuthUser;
import ufront.log.Message;
import ufront.log.MessageList;
import ufront.web.session.VoidSession;
import ufront.web.url.UrlDirection;
import thx.error.NullArgument;
import ufront.web.url.filter.UFUrlFilter;
import thx.error.AbstractMethod;
import ufront.web.session.*;
import ufront.auth.*;
import ufront.web.url.*;
import ufront.web.url.filter.*;
import tink.CoreApi;
using ufront.core.InjectionTools;

/**
	A context describing the current Http request, response and session.
**/
class HttpContext 
{
	#if (php || neko)
		/**
			Create a HttpContext for Neko or PHP environments.
			If request and response are not supplied, they will created.
			The rest of the parameters are passed directly to the `HttpContext` constructor.
		**/
		public static function createSysContext( ?request:HttpRequest, ?response:HttpResponse, ?appInjector:Injector, ?session:UFHttpSession, ?auth:UFAuthHandler<UFAuthUser>, ?urlFilters:Array<UFUrlFilter>, ?relativeContentDir="uf-content" ) {
			if( null==request ) request = HttpRequest.create();
			if( null==response ) response = HttpResponse.create();
			return new HttpContext( request, response, appInjector, session, auth, urlFilters, relativeContentDir );
		}
	#elseif (nodejs && !macro)
		/**
			Create a HttpContext for the NodeJS environment, using the `js-kit` haxelib.
			The native express-js request and response objects must be supplied.
			The rest of the parameters are passed directly to the `HttpContext` constructor.
		**/
		public static function createNodeJSContext( req:js.npm.express.Request, res:js.node.http.ServerResponse, ?appInjector:Injector, ?session:UFHttpSession, ?auth:UFAuthHandler<UFAuthUser>, ?urlFilters:Array<UFUrlFilter>, ?relativeContentDir="uf-content" ) {
			var request:HttpRequest = new nodejs.ufront.web.context.HttpRequest( req );
			var response:HttpResponse = new nodejs.ufront.web.context.HttpResponse( res );
			return new HttpContext( request, response, appInjector, session, auth, urlFilters, relativeContentDir );
		}
	#end

	/**
		Create a HttpContext object using the explicitly supplied objects.

		For creating a context for each platform see `createSysContext` and `createNodeJSContext`.
		
		@param request (required) The current `HttpRequest`.
		@param response (required) The current `HttpResponse`.
		@param appInjector (optional) The HttpApplication injector, which will be the parent injector for this request - all appInjector mappings will be shared with this context's injector. If null no parent injector will be used.
		@param session (optional) The current session. If null, we will attempt to get a `UFHttpSession` from the injector. If that fails, we will use a `VoidSession`.
		@param auth (optional) The current authentication handler. If null, we will attempt to get a `UFAuthHandler` from the injector. If that fails, we will use a `NobodyAuthHandler`, which is appropriate for a visitor who has no permissions.
		@param urlFilters (optional) The URL Filters to use on the current request. If null, an empty array (no filters) will be used.
		@param relativeContentDir (optional) The path to the content directory, relative to the script directory. Default is "uf-content".
	**/
	public function new( request:HttpRequest, response:HttpResponse, ?appInjector:Injector, ?session:UFHttpSession, ?auth:UFAuthHandler<UFAuthUser>, ?urlFilters:Array<UFUrlFilter>, ?relativeContentDir="uf-content" ) {
		NullArgument.throwIfNull( response );
		NullArgument.throwIfNull( request );
		
		this.request = request;
		this.response = response;
		this.urlFilters = ( urlFilters!=null ) ? urlFilters : [];
		this.relativeContentDir = relativeContentDir;
		this.actionContext = new ActionContext( this );
		this.messages = [];
		this.completion = new EnumFlags<RequestCompletion>();

		this.injector = (appInjector!=null) ? appInjector.createChildInjector() : new Injector();
		injector.mapValue( HttpContext, this );
		injector.mapValue( HttpRequest, request );
		injector.mapValue( HttpResponse, response );
		injector.mapValue( ActionContext, actionContext );
		injector.mapValue( MessageList, new MessageList(messages) );

		if ( session!=null ) this.session = session;
		if ( this.session==null ) 
			try this.session = injector.getInstance( UFHttpSession )
			catch(e:Dynamic) ufLog('Failed to load UFHttpSession: $e. Using VoidSession instead.');
		if ( this.session==null ) this.session = new VoidSession();
		injector.inject( UFHttpSession, this.session );

		if ( auth!=null ) this.auth = auth;
		if ( this.auth==null ) 
			try this.auth = injector.getInstance( UFAuthHandler )
			catch(e:Dynamic) ufLog('Failed to load UFAuthHandler: $e. Using NobodyAuthHandler instead.');
		if ( this.auth==null ) this.auth = new NobodyAuthHandler();
		injector.inject( UFAuthHandler, this.auth );
	}

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
		This means all mappings at the application level will be available in the request injector.
	**/
	public var injector(default,null):Injector;

	/** The current HttpRequest **/
	public var request(default,null):HttpRequest;

	/** The current HttpResponse **/
	public var response(default,null):HttpResponse;

	/** 
		The current session.
		Either set during the constructor or created via dependency injection.
	**/
	public var session(default,null):UFHttpSession;

	/**
		The current session ID.

		This is a shortcut for `session.id`, but will return null if `session` is null.
	**/
	public var sessionID(get,null):Null<String>;

	/**
		The current auth handler.
		Either set during the constructor or created via dependency injection.
	**/
	public var auth(default,null):UFAuthHandler<UFAuthUser>;

	/**
		The current user.

		This is a shortcut for `auth.currentUser`, but will return null if `auth` is null.
	**/
	public var currentUser(get,null):Null<UFAuthUser>;

	/**
		The current user.

		This is a shortcut for `auth.currentUser.id`, but will return null if `auth` or `auth.currentUser` is null.
	**/
	public var currentUserID(get,null):Null<String>;

	/** The `ActionContext` used in processing the request. Will be null until the application has found a handler for the request. **/
	public var actionContext(default,null):ActionContext;

	/**
		The completion progress of the current request. Setting these values will affect the flow of the request.
		
		For example, if a middleware restores a response from a cached entry matching the current request, it may want to skip the `RequestHandler` and any `ResponseMiddleware`:

		```
		// Skip remaining request middleware, and the request handler (this will then skip to the response middleware)
		ctx.completion.set( CRequestMiddlewareComplete );
		ctx.completion.set( CRequestHandlerComplete );
		```

		Another example is if you have a controller or some code that writes directly to the output, not the response object, in which case you want to skip the log, flush, middleware etc.  (This is the case with the `dbadmin` tool)

		```
		ctx.completion.set( CRequestHandlerComplete );
		ctx.completion.set( CResponseMiddlewareComplete );
		ctx.completion.set( CLogComplete );
		ctx.completion.set( CFlushComplete );
		```

		These values are updated by HttpApplication and various middleware and handlers, or you can update them manually.
	**/
	public var completion:EnumFlags<RequestCompletion>;

	/** The URL filters to be used for `getRequestUri()` and `generateUri()` **/
	public var urlFilters(default,null):Iterable<UFUrlFilter>;

	var _requestUri:String;

	/**
		Gets the filtered request URI. 

		It uses the request uri found in the supplied `HttpRequest`, but applies the Url Filters to it.  
		For example, if you use `PathInfoUrlFilter` to filter `index.n?path=/home/` into `/home/`, this will return the filtered result.
	**/
	public function getRequestUri():String {
		if( null==_requestUri ) {
			var url = PartialUrl.parse( request.uri );
			for( filter in urlFilters )
				filter.filterIn( url, request );
			_requestUri = url.toString();
		}
		return _requestUri;
	}

	/**
		Takes a URI and runs it through the given filters in reverse.

		For example, if you use `PathInfoUrlFilter` this could turn `/home/` into `index.n?path=/home/`.  
		This is useful so your code contains the simple URIs, but at runtime they are transformed into the correct form depending on the environment.
	**/
	public function generateUri( uri:String ):String {
		var uriOut = VirtualUrl.parse( uri );
		var filters:Array<UFUrlFilter> = cast urlFilters;
		var i = filters.length - 1;
		while( i>=0 )
			filters[i--].filterOut( uriOut, request );
		return uriOut.toString();
	}

	/**
		Sets the URL filters.  Should only be used before the request has begun processing.
	**/
	public function setUrlFilters( filters ) {
		urlFilters = ( filters!=null ) ? filters : [];
		_requestUri = null;
	}

	/**
		Get the path of the content directory.

		This is a directory that ufront has write-access to, and should preferably not be available for general Http access.

		It can be used to store sessions, log files, cache, uploaded files etc.
		
		The value is essentially `${request.scriptDirectory}/$relativeContentDir/`, where `relativeContentDir` is the value that was supplied to the constructor.

		If using `ufront.application.UfrontApplication`, this value can be set with the `contentDirectory` setting in your `ufront.web.Configuration` initialization settings.

		The trailing slash is always included.
	**/
	public var contentDirectory(get,null):String;

	var relativeContentDir:String;
	var _contentDir:String;
	function get_contentDirectory() {
		if ( _contentDir==null ) {
			if (request.scriptDirectory!=null) 
				_contentDir = Path.addTrailingSlash(request.scriptDirectory) + Path.addTrailingSlash( relativeContentDir );
			else
				_contentDir = Path.addTrailingSlash( relativeContentDir );

			_contentDir = Path.normalize( _contentDir );
		}
		return _contentDir;
			
	}
	
	/**
		Commit the session data, if there is any.

		Will return a future letting you know when the session commit has been completed
	**/
	public function commitSession():Surprise<Noise,String> {
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

	/**
		A collection of messages that were traced during this request.
	**/
	public var messages:Array<Message>;

	inline function get_sessionID() {
		return (null!=session) ? session.id : null;
	}

	inline function get_currentUser() {
		return (null!=auth) ? auth.currentUser : null;
	}

	inline function get_currentUserID() {
		return (auth!=null && auth.currentUser!=null) ? auth.currentUser.userID : null;
	}
}

enum RequestCompletion {
	CRequestMiddlewareComplete;
	CRequestHandlersComplete;
	CResponseMiddlewareComplete;
	CLogHandlersComplete;
	CFlushComplete;
	CErrorHandlersComplete;
}