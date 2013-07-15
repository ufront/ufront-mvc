package ufront.web.context;
import ufront.web.url.UrlDirection;
import thx.error.NullArgument;
import ufront.web.url.filter.IUrlFilter;
import thx.error.AbstractMethod;
import ufront.web.session.FileSession;
import ufront.web.session.IHttpSessionState;
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
	   
		`session` will be set up using `FileSession.create`, with the supplied `sessionPath`.

	**/
	public static function createWebContext(?sessionpath : String, ?request : HttpRequest, ?response : HttpResponse)
	{
		if(null == request)
			request = HttpRequest.instance;
		if(null == response)
			response = HttpResponse.instance;
		if (null == sessionpath)
			sessionpath = request.scriptDirectory + "../_sessions";
		return new HttpContext(request, response, FileSession.create(sessionpath));
	}

	/**
		Create a HttpContext by explicitly supplying the request, response and session.

		This is useful for mocking a context.  For real usage, it may be easier to use `createWebContext`
	**/
	public function new(request : HttpRequest, response : HttpResponse, session : IHttpSessionState)
	{
		_urlFilters = [];
		NullArgument.throwIfNull(session);
		NullArgument.throwIfNull(response);
		NullArgument.throwIfNull(request);
		this.request = request;
		this.response = response;
		this.session = session;
	}

	public var request(get, null) : HttpRequest;
	public var response(get, null) : HttpResponse;
	public var session(get, null) : IHttpSessionState;

	var _requestUri : String;
	/**
		Gets the filtered request URI. 

		It uses the request uri found in the supplied `HttpRequest`, but applies the Url Filters to it.  
		For example, if you use `PathInfoUrlFilter` to filter `index.n?path=/home/` into `/home/`, this will return the filtered result.
	**/
	public function getRequestUri() : String
	{
		if(null == _requestUri)
		{
			var url = PartialUrl.parse(request.uri);
			for(filter in _urlFilters)
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
	public function generateUri(uri : String) : String
	{
		var uriOut = VirtualUrl.parse(uri);
		var i = _urlFilters.length - 1;
		while(i >= 0)
			_urlFilters[i--].filterOut(uriOut, request);
		return uriOut.toString();
	}

	var _urlFilters : Array<IUrlFilter>;
	/**
		Add a URL filter to be used by `getRequestUri` and `generateUri`
	**/
	public function addUrlFilter(filter : IUrlFilter)
	{
		NullArgument.throwIfNull(filter);
		_requestUri = null;
		_urlFilters.push(filter);
		return this;
	}

	/**
		Remove existing URL filters
	**/
	public function clearUrlFilters()
	{
		_requestUri = null;
		_urlFilters = [];
	}
	
	/**
		Dispose of this HttpContext.

		Currently just disposes of the given `session`.
	**/
	public function dispose():Void
	{
		session.dispose();
	}
	
	function get_request() return request;
	function get_response() return response;
	function get_session() return session;
}