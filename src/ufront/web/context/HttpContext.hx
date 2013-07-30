package ufront.web.context;
import ufront.auth.IAuthUser;
import ufront.web.url.UrlDirection;
import thx.error.NullArgument;
import ufront.web.url.filter.IUrlFilter;
import thx.error.AbstractMethod;
import ufront.web.session.IHttpSessionState;
import ufront.web.result.ActionResult;
import ufront.auth.IAuthHandler;
import ufront.web.url.*;
import ufront.web.url.filter.*;

/**
	A context describing the current Http request, response and session.
**/
class HttpContext 
{
	/**
		Create a HttpContext using the usual Http environment.

		`request` and `response`, if not supplied, will both be set up by their classes' "get_instance" method, which has platform specific implementations.
	   
		`session` and `auth` will be null if not supplied.

		`urlFilters` will be an empty array if not supplied.
	**/
	public static function createWebContext( ?request:HttpRequest, ?response:HttpResponse, ?session:IHttpSessionState, ?auth:IAuthHandler<IAuthUser>, ?urlFilters:Array<IUrlFilter> ) {
		if(null == request)
			request = HttpRequest.instance;
		if(null == response)
			response = HttpResponse.instance;
		// import ufront.web.session.FileSession;
		// if (null == sessionpath)
			// sessionpath = request.scriptDirectory + "../_sessions";
		return new HttpContext(request, response, session, auth, urlFilters );
	}

	/**
		Create a HttpContext by explicitly supplying the request, response and session.

		This is useful for mocking a context.  For real usage, it may be easier to use `createWebContext`.

		`request` and `response` are required.  `session` and `auth` are optional, and will default to null.

		`urlFilters` will be used for `getRequestUri()` and `generateUri()`.  By default it is an empty array.
	**/
	public function new( request:HttpRequest, response:HttpResponse, ?session:IHttpSessionState, ?auth:IAuthHandler<IAuthUser>, ?urlFilters:Array<IUrlFilter> ) {
		completed = false;
		NullArgument.throwIfNull(response);
		NullArgument.throwIfNull(request);
		this.request = request;
		this.response = response;
		this.session = session;
		this.auth = auth;
		this.urlFilters = (urlFilters!=null) ? urlFilters : [];
	}

	/** The current HttpRequest **/
	public var request(default, null):HttpRequest;

	/** The current HttpResponse **/
	public var response(default, null):HttpResponse;

	/** The current session **/
	public var session(default, null):Null<IHttpSessionState>;

	/** The current auth handler **/
	public var auth(default, null):Null<IAuthHandler<IAuthUser>>;

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
		Dispose of this HttpContext.

		Currently just disposes of the given `session`.
	**/
	public function dispose():Void {
		if (session!=null) session.dispose();
	}
}