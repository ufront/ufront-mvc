package ufront.web.context;
import thx.error.AbstractMethod;
import haxe.io.Bytes;
import haxe.ds.StringMap;
import thx.error.NotImplemented;
import ufront.web.upload.UFHttpUploadHandler;

/**
	A description of the current HttpRequest.

	This base class is mostly abstract methods, each platform must implement the key details.
**/
class HttpRequest
{
	/**
		Create a `HttpRequest` using the platform specific implementation.

		Currently supports PHP and Neko only.
	**/
	public static function create():HttpRequest
	{
		return 
			#if php 
				new php.ufront.web.context.HttpRequest();
			#elseif 
				neko new neko.ufront.web.context.HttpRequest();
			#else
				throw new NotImplemented();
			#end
	}

	/**
		A simple hash of all the parameters supplied in this request.

		The parameters are collected in the following order:

		- query-string parameters
		- cookies
		- post values
	**/
	@:isVar public var params(get, null) : Map<String,String>;
	function get_params()
	{
		if (null == params) {
			params = new Map<String,String>();
			for (map in [query,cookies,post]) {
				for (key in map.keys()) {
					params.set(key, map[key]);
				}
			}
		}
		return params;
	}

	/**
		The GET query parameters.  

		Will return an empty String if there are no GET parameters.
	**/
	public var queryString(get, null) : String;
	function get_queryString() return throw new AbstractMethod();

	/**
		The POST query parameters.

		Will return an empty String if there are no GET parameters.
	**/
	public var postString(get, null) : String;
	function get_postString() return throw new AbstractMethod();

	/**
		The GET query parameters for this request.
	**/
	public var query(get, null) : Map<String,String>;
	function get_query() return throw new AbstractMethod();

	/**
		The POST parameters for this request.
	**/
	public var post(get, null) : Map<String,String>;
	function get_post() return throw new AbstractMethod();

	/**
		The Cookie parameters for this request.
	**/
	public var cookies(get, null) : Map<String,String>;
	function get_cookies() return throw new AbstractMethod();

	/**
		The host name of the current server
	**/
	public var hostName(get, null) : String;
	function get_hostName() return throw new AbstractMethod();

	/**
		The Client's IP address
	**/
	public var clientIP(get, null) : String;
	function get_clientIP() return throw new AbstractMethod();

	/**
		The Uri requested in this HTTP request.

		This is the URI before any filters have been applied.
	**/
	public var uri(get, null) : String;
	function get_uri() return throw new AbstractMethod();

	/**
		The client headers supplied in the request.  
	**/
	public var clientHeaders(get, null) : Map<String,String>;
	function get_clientHeaders() return throw new AbstractMethod();

	/**
		Information about the user agent that made the request.
	**/
	public var userAgent(get, null) : UserAgent;
	function get_userAgent() return throw new AbstractMethod();

	/**
		The HTTP method used for the request.

		Usually "get" or "post", but can be other things. 

		Case sensitivity depends on the environement.
	**/
	public var httpMethod(get, null) : String;
	function get_httpMethod() return throw new AbstractMethod();

	/**
		The path of the currently executing script.

		This is the path to your `index` file, not to the current class or controller.

		It will usually be an absolute path, but depending on the environment it may be relative.

		@todo confirm this always has a traling slash.  It appears to...
	**/
	public var scriptDirectory(get, null) : String;
	function get_scriptDirectory() return throw new AbstractMethod();

	/**
		Gives the username and password supplied by the "Authorization" client header.

		If no "Authorization" header was specified, it will return null.

		If "Authorization" header was specified, but it did not have exactly two parameters, it will throw an exception.

		TODO: document how to trigger this authorization header.
	**/
	public var authorization(get, null) : { user : String, pass : String };
	function get_authorization() return throw new AbstractMethod();

	/**
		TODO: document this.  May need Franco's help to explain it...
	**/
	public function setUploadHandler(handler : UFHttpUploadHandler) throw new AbstractMethod();

	/**
		Things not implemented yet but which would be handy:
	**/

	// urlReferrrer
	//public var acceptTypes(get, null) : Array<String>;
	//public var sessionId(get, null) : String;

	/**
	 * never has trailing slash. If the application is in the server root the path will be emppty ""
	 */
	//public var applicationPath(get, null) : String;
	//public var broswer(get, setBrowser) : HttpBrowserCapabilities;
	//public var encoding(get, setEncoding) : String;
	//public var contentLength(get, null) : Int;
	//public var contentType(get, null) : String;
	//public var mimeType(get, setMimeType) : String;
	//public var files(get, null) : List<HttpPostedFile>;
	//public var httpMethod(get, null) : String;
	//public var isAuthenticated(get, null) : String;
	/**
	 * evaluates to true if the IP address is 127.0.0.1 or the same as the client ip address
	 */
	//public var isLocal(get, null) : String;
	//public var isSecure(get, null) : String;

	//public var userAgent(get, null) : String;
	//public var userHostAddress(get, null) : String;
	//public var userHostName(get, null) : String;
	//public var userLanguages(get, null) : Array<String>;
}