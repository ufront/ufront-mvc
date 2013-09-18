package ufront.web.context;
import haxe.PosInfos;
import hxevents.Async;
import ufront.auth.IAuthUser;
import ufront.log.Message;
import ufront.web.url.UrlDirection;
import thx.error.NullArgument;
import ufront.web.url.filter.IUrlFilter;
import thx.error.AbstractMethod;
import ufront.web.session.IHttpSessionState;
import ufront.web.result.ActionResult;
import ufront.auth.IAuthHandler;
import ufront.web.url.*;
import ufront.web.url.filter.*;
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
	public static function create( ?request:HttpRequest, ?response:HttpResponse, ?session:IHttpSessionState, ?auth:IAuthHandler<IAuthUser>, ?sessionFactory:HttpContext->IHttpSessionState, ?authFactory:HttpContext->IAuthHandler<IAuthUser>, ?urlFilters:Array<IUrlFilter> ) {
		if( null==request )
			request = HttpRequest.create();
		if( null==response )
			response = HttpResponse.create();
		// import ufront.web.session.FileSession;
		// if (null == sessionpath)
			// sessionpath = request.scriptDirectory + "../_sessions";
		return new HttpContext(request, response, session, auth, sessionFactory, authFactory, urlFilters );
	}

	/**
		Create a HttpContext by explicitly supplying the request, response and session.

		This is useful for mocking a context.  For real usage, it may be easier to use `create`.

		`request` and `response` are required.  `session` and `auth` are optional, and will default to null.

		`urlFilters` will be used for `getRequestUri()` and `generateUri()`.  By default it is an empty array.
	**/
	public function new( request:HttpRequest, response:HttpResponse, ?session:IHttpSessionState, ?auth:IAuthHandler<IAuthUser>, ?sessionFactory:HttpContext->IHttpSessionState, ?authFactory:HttpContext->IAuthHandler<IAuthUser>, ?urlFilters:Array<IUrlFilter> ) {
		completed = false;
		NullArgument.throwIfNull(response);
		NullArgument.throwIfNull(request);
		this.request = request;
		this.response = response;
		this.sessionFactory = sessionFactory;
		this.authFactory = authFactory;
		this._session = session;
		this._auth = auth;
		this.urlFilters = (urlFilters!=null) ? urlFilters : [];
		messages = [];
	}

	/** The current HttpRequest **/
	public var request(default, null):HttpRequest;

	/** The current HttpResponse **/
	public var response(default, null):HttpResponse;

	/** 
		The current session.

		If no session is provided, but `sessionFactory` is set, that will be used to create a session.
	**/
	public var session(get, null):IHttpSessionState;

	/**
		The current auth handler 

		If no auth handler is provided, but authFactory is set, that will be used to create a session.
	**/
	public var auth(get, null):IAuthHandler<IAuthUser>;

	/** The `ActionContext` used in processing the request. Will be null until the application has processed it's dispatch **/
	public var actionContext:ActionContext;

	/** The `ActionResult` that came from processing the request. Will be null until the action has been executed. **/
	public var actionResult:ActionResult;

	/** When true, the event chain in `HttpApplication` will stop firing and begin it's conclusion **/
	public var completed:Bool;

	/** Returns true if the log has been dispatched already for the current request (Read only) **/
	public var logDispatched(default,null):Bool;

	/** Returns true if the response has been flushed already for the current request (Read only) **/
	public var flushed(default,null):Bool;

	/** The URL filters to be used for `getRequestUri()` and `generateUri()` **/
	public var urlFilters(default,null):Iterable<IUrlFilter>;

	var sessionFactory:HttpContext->IHttpSessionState;
	var authFactory:HttpContext->IAuthHandler<IAuthUser>;

	var _requestUri:String;

	/**
		Gets the filtered request URI. 

		It uses the request uri found in the supplied `HttpRequest`, but applies the Url Filters to it.  
		For example, if you use `PathInfoUrlFilter` to filter `index.n?path=/home/` into `/home/`, this will return the filtered result.
	**/
	public function getRequestUri():String {
		if(null == _requestUri) {
			var url = PartialUrl.parse(request.uri);
			for(filter in urlFilters)
				filter.filterIn(url, request);
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
		var uriOut = VirtualUrl.parse(uri);
		var filters:Array<IUrlFilter> = cast urlFilters;
		var i = filters.length - 1;
		while(i >= 0)
			filters[i--].filterOut(uriOut, request);
		return uriOut.toString();
	}

	/**
		Sets the URL filters.  Should only be used before the request has begun processing.
	**/
	public function setUrlFilters( filters ) {
		urlFilters = (filters!= null) ? filters : [];
		_requestUri = null;
	}
	
	/**
		Commit the session data, if there is any.

		If async is provided, on completion of the session commit `async.complete()` will be called
	**/
	public function commitSession( ?async:Async ):Void {
		if (_session!=null) {
			session.ifIs(IHttpSessionStateAsync, function(s) {
				NullArgument.throwIfNull( async );
				s.commit( async );
			});
			session.ifIs(IHttpSessionStateSync, function(s) {
				s.commit();
				if (async!=null) async.completed();
			});
		}
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

		Inline shortcuts are provided from `ufront.web.Controller` and `ufront.remoting.RemotingApiClass` so that you can call ufTrace() and it points to this method.
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
	
	/**
		Dispose of this HttpContext.
	**/
	public function dispose():Void {
		request = null;
		response = null;
		session = null;
		auth = null;
		actionContext = null;
		actionResult = null;
		urlFilters = null;
	}

	var _session:IHttpSessionState;
	function get_session() {
		if( null==_session && sessionFactory!=null )
			_session = sessionFactory( this );
		return _session;
	}

	var _auth:IAuthHandler<IAuthUser>;
	function get_auth() {
		if( null==_auth && authFactory!=null && session!=null )
			_auth = authFactory( this );
		return _auth;
	}
}