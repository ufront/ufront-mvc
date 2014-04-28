package ufront.web.context;

import haxe.EnumFlags;
import haxe.io.Path;
import haxe.PosInfos;
import minject.Injector;
import ufront.auth.UFAuthUser;
import ufront.log.Message;
import ufront.web.url.UrlDirection;
import thx.error.NullArgument;
import ufront.web.url.filter.UFUrlFilter;
import thx.error.AbstractMethod;
import ufront.web.session.*;
import ufront.auth.*;
import ufront.web.url.*;
import ufront.web.url.filter.*;
import tink.CoreApi;
using Types;

/**
	A context describing the current Http request, response and session.
**/
class HttpContext 
{
	/**
		Create a HttpContext using the usual Http environment.

		`request` and `response`, if not supplied, will both be set up by their classes' "create" methods, which have platform specific implementations.
	   
		`session` and `auth` will be null if not supplied.

		`urlFilters` will be an empty array if not supplied.
	**/
	public static function create( ?injector:Injector, ?request:HttpRequest, ?response:HttpResponse, ?session:UFHttpSessionState, ?auth:UFAuthHandler<UFAuthUser>, ?urlFilters:Array<UFUrlFilter>, ?contentDir="uf-content" ) {
		if( null==injector )
			injector = new Injector();
		if( null==request )
			request = HttpRequest.create();
		if( null==response )
			response = HttpResponse.create();
		return new HttpContext( injector, request, response, session, auth, urlFilters, contentDir );
	}

	/**
		Create a HttpContext by explicitly supplying the request, response and session.

		This is useful for mocking a context.  For real usage, it may be easier to use `create`.

		`request` and `response` are required.  `session` and `auth` are optional, and will default to null.

		`urlFilters` will be used for `getRequestUri()` and `generateUri()`.  By default it is an empty array.

		`contentDir` is used to help specify the path of `contentDirectory`, relative to `request.scriptDirectory`.  Default value is `uf-content`
	**/
	public function new( injector:Injector, request:HttpRequest, response:HttpResponse, ?session:UFHttpSessionState, ?auth:UFAuthHandler<UFAuthUser>, ?urlFilters:Array<UFUrlFilter>, ?contentDir="uf-content" ) {

		NullArgument.throwIfNull( injector );
		NullArgument.throwIfNull( response );
		NullArgument.throwIfNull( request );
		
		this.injector = injector;
		this.request = request;
		this.response = response;
		this._session = session;
		this._auth = auth;
		this.urlFilters = ( urlFilters!=null ) ? urlFilters : [];
		this.contentDir = contentDir;

		this.sessionFactory = injector.getInstance( UFSessionFactory );
		this.authFactory = injector.getInstance( UFAuthFactory );
		
		messages = [];
		completion = new EnumFlags<RequestCompletion>();
	}

	/** An injector that is available to the current request **/
	public var injector:Injector;

	/** The current HttpRequest **/
	public var request(default, null):HttpRequest;

	/** The current HttpResponse **/
	public var response(default, null):HttpResponse;

	/** 
		The current session.

		If no session is provided, but `sessionFactory` is set, that will be used to create a session.
	**/
	public var session(get, null):UFHttpSessionState;

	/**
		The current session ID.

		This is a shortcut for `session.id`, but will return null if `session` is null.
	**/
	public var sessionID(get, null):String;

	/**
		The current auth handler.

		If no auth handler is provided, but authFactory is set, that will be used to create a session.
	**/
	public var auth(get, null):UFAuthHandler<UFAuthUser>;

	/**
		The current user.

		This is a shortcut for `auth.currentUser`, but will return null if `auth` is null.
	**/
	public var currentUser(get, null):UFAuthUser;

	/**
		The current user.

		This is a shortcut for `auth.currentUser.id`, but will return null if `auth` or `auth.currentUser` is null.
	**/
	public var currentUserID(get, null):String;

	/** The `ActionContext` used in processing the request. Will be null until the application has processed it's dispatch **/
	public var actionContext:ActionContext;

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

	var sessionFactory:UFSessionFactory;
	var authFactory:UFAuthFactory;

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
		
		The value is essentially `${request.scriptDirectory}/${contentDir}/`, where `contentDir` is the value that was supplied to the constructor.

		If using `ufront.application.UfrontApplication`, this value can be set with the `contentDirectory` setting in your `ufront.web.Configuration` initialization settings.

		The trailing slash is always included.
	**/
	public var contentDirectory(get,null):String;

	var contentDir:String;
	function get_contentDirectory() {
		return Path.addTrailingSlash( request.scriptDirectory ) + Path.addTrailingSlash( contentDir );
	}
	
	/**
		Commit the session data, if there is any.

		Will return a future letting you know when the session commit has been completed
	**/
	public function commitSession():Surprise<Noise,String> {
		return
			if ( _session!=null ) _session.commit();
			else Future.sync( Success(Noise) );
	}

	/**
		Returns true if the session for this context has been set.

		Testing `session!=null` does not have the same effect because the session getter will initiate itself before the null check takes place.
	**/
	public inline function isSessionActive():Bool {
		return _session!=null;
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

	var _session:UFHttpSessionState;
	function get_session() {
		if( null==_session && sessionFactory!=null )
			_session = sessionFactory.create( this );
		return _session;
	}

	var _auth:UFAuthHandler<UFAuthUser>;
	function get_auth() {
		if( null==_auth && authFactory!=null && session!=null )
			_auth = authFactory.create( this );
		return _auth;
	}

	inline function get_sessionID() {
		return (null!=_session) ? _session.id : null;
	}

	inline function get_currentUser() {
		return (null!=auth) ? auth.currentUser : null;
	}

	inline function get_currentUserID() {
		return (null!=auth && null!=auth.currentUser) ? auth.currentUser.userID : null;
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