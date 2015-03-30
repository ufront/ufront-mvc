package ufront.web.context;
import thx.core.error.AbstractMethod;
import haxe.io.Bytes;
import haxe.ds.StringMap;
import thx.core.error.NotImplemented;
import ufront.web.upload.FileUpload;
import ufront.core.MultiValueMap;
using tink.CoreApi;
using StringTools;

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
			#elseif neko
				new neko.ufront.web.context.HttpRequest();
			#elseif (js && !nodejs)
				new js.ufront.web.context.HttpRequest();
			#elseif (js && nodejs)
				throw "Please use `new nodejs.ufront.web.HttpRequest(req)` instead";
			#else
				throw new NotImplemented();
			#end
	}

	/**
		A simple hash of all the parameters supplied in this request.

		The parameters are collected in the following order:

		- cookies
		- query-string parameters
		- post values

		with the latter taking precedence over the former.
		For example, if both a cookie and a post variable define a parameter `name`, calling `request.params["name"]` will show the POST value.
		In that example, if you would like to access all the various values of `name`, you can use `request.params.getAll("name")` or separately access `request.cookies` or `request.post`.
	**/
	@:isVar public var params(get, null):MultiValueMap<String>;
	function get_params():MultiValueMap<String> {
		if ( null==params ) {
			params = MultiValueMap.combine( [cookies,query,post] );
		}
		return params;
	}

	/**
		The GET query parameters.

		Will return an empty String if there are no GET parameters.
	**/
	public var queryString(get, null):String;
	function get_queryString():String return throw new AbstractMethod();

	/**
		The POST query parameters.

		Will return an empty String if there are no GET parameters.
	**/
	public var postString(get, null):String;
	function get_postString():String return throw new AbstractMethod();

	/**
		The GET query parameters for this request.
	**/
	public var query(get, null):MultiValueMap<String>;
	function get_query():MultiValueMap<String> return throw new AbstractMethod();

	/**
		The POST parameters for this request.

		Please note that if the request is a multipart request, and `parseMultipart` has not been called, it will be called to fetch all the post data from the various parts.
		Because `parseMultipart` can only be called once, this will prevent you from being able to process any file uploads.
		If you need access to file uploads, please ensure `parseMultipart` is called before `post` is accessed.
		This can be achieved using upload middleware.

		If any files were uploaded, they will appear in the "post" values with their parameter name, and the value will contain the original filename of the upload.
	**/
	public var post(get, null):MultiValueMap<String>;
	function get_post():MultiValueMap<String> return throw new AbstractMethod();

	/**
		File uploads that were part of a POST / multipart request.

		Please note this is not populated automatically, you must use some request middleware to process the multipart data and populate the `files` with appropriate FileUploads.
	**/
	public var files(get, null):MultiValueMap<FileUpload>;
	function get_files():MultiValueMap<FileUpload> {
		if ( null==files ) {
			files = new MultiValueMap();
		}
		return files;
	}

	/**
		The Cookie parameters for this request.
	**/
	public var cookies(get, null):MultiValueMap<String>;
	function get_cookies():MultiValueMap<String> return throw new AbstractMethod();

	/**
		The host name of the current server
	**/
	public var hostName(get, null):String;
	function get_hostName():String return throw new AbstractMethod();

	/**
		The Client's IP address
	**/
	public var clientIP(get, null):String;
	function get_clientIP():String return throw new AbstractMethod();

	/**
		The Uri requested in this HTTP request.

		This is the URI before any filters have been applied.
	**/
	public var uri(get, null):String;
	function get_uri():String return throw new AbstractMethod();

	/**
		The client headers supplied in the request.
	**/
	public var clientHeaders(get, null):MultiValueMap<String>;
	function get_clientHeaders():MultiValueMap<String> return throw new AbstractMethod();

	/**
		Information about the user agent that made the request.
	**/
	public var userAgent(get, null):UserAgent;
	function get_userAgent():UserAgent {
		if ( userAgent==null )
			userAgent = UserAgent.fromString( clientHeaders.get("User-Agent") );
		return userAgent;
	}

	/**
		The HTTP method used for the request.

		Usually "get" or "post", but can be other things.

		Case sensitivity depends on the environement.
	**/
	public var httpMethod(get, null):String;
	function get_httpMethod():String return throw new AbstractMethod();

	/**
		The path of the currently executing script.

		This is the path to your `index` file, not to the current class or controller.

		It will usually be an absolute path, but depending on the environment it may be relative.

		@todo confirm this always has a traling slash.  It appears to...
	**/
	public var scriptDirectory(get, null):String;
	function get_scriptDirectory():String return throw new AbstractMethod();

	/**
		Gives the username and password supplied by the "Authorization" client header.

		If no "Authorization" header was specified, it will return null.

		If "Authorization" header was specified, but it did not have exactly two parameters, it will throw an exception.

		To trigger the login box to open on the browser, use `context.response.requireAuthentication("Please login")`.
	**/
	public var authorization(get, null):{ user:String, pass:String };
	function get_authorization():{ user:String, pass:String } return throw new AbstractMethod();

	/**
		Check if the current request is a multipart/form-data request.

		This is a shortcut for: `clientHeaders["Content-Type"].startsWith("multipart/form-data")`
	**/
	public function isMultipart():Bool {
		return clientHeaders.exists("Content-Type") && clientHeaders["Content-Type"].startsWith("multipart/form-data");
	}

	/**
		Parse the multipart data of this request.

		> Please note, if you merely wish to access file uploads, it is probably better to use an existing `ufront.app.RequestMiddleware` that parses multipart data and gives access to the uploads through `request.files`.
		> Calling parseMultipart() manually is mostly intended for people developing new file-upload middleware.

		If a POST request contains multipart data, `parseMultipart` must be called in order to have access to both the POST parameters and to uploaded files.

		Accessing `httpRequest.post` on a multipart request will call `parseMultipart()` but not process any file uploads.
		Because of this, it is recommended that you use a `ufront.app.RequestMiddleware` very early in your request, before `request.post` is ever called, so that you can parse your file uploads, even if you do not handle them until later.

		In each platform's implementation of `parseMultipart()`, it should take care of parsing post variables to `request.post`, and then call the `onPart`, `onData` and `onEndPart` for each file upload.

		You should only call `parseMultipart()` a maximum of once per request, and an exception will be thrown if you attempt to call it more than once.

		If this method is called on a request which was not multipart encoded, the result is unspecified.

		@param onPart (optional) - called once at the start of each new file: `onPart( paramName:String, origFileName:String )`
		@param onData (optional) - called multiple times (in order) for each file: `onData( bytes:haxe.io.Bytes, pos:Int, length:Int )`
		@param onEndPart (optional) - called after all data for a part has been received.

		It is safe to assume that only one of the callbacks will be running at a time, and that they will run in order for each file.

		Even though the method signiatures here require returning a `tink.core.Future`, these will be ignored on some platforms, such as neko.  Check the documentation on the specific HttpRequest implementation for details.
	**/
	public function parseMultipart( ?onPart:OnPartCallback, ?onData:OnDataCallback, ?onEndPart:OnEndPartCallback ):Surprise<Noise,Error> return throw new AbstractMethod();

	/**
		Things not implemented yet but which would be handy:
	**/

	/**
	 * never has trailing slash. If the application is in the server root the path will be empty ""
	 */
	//public var applicationPath(get, null):String;
	//public var broswer(get, setBrowser):HttpBrowserCapabilities;
	//public var encoding(get, setEncoding):String;
	//public var contentLength(get, null):Int;
	//public var contentType(get, null):String;
	//public var mimeType(get, setMimeType):String;
	//public var files(get, null):List<HttpPostedFile>;
	//public var httpMethod(get, null):String;
	//public var isAuthenticated(get, null):String;
	/**
	 * evaluates to true if the IP address is 127.0.0.1 or the same as the client ip address
	 */
	//public var isLocal(get, null):String;
	//public var isSecure(get, null):String;
	//public var environment(get, null):String; // mod_neko, mod_tora, mod_php, browserjs, nodejs etc

	//public var userAgent(get, null):String;
	//public var userHostAddress(get, null):String;
	//public var userHostName(get, null):String;
	//public var userLanguages(get, null):Array<String>;
}

/**
	`function onPart(paramName:String, origFileName:String):Surprise<Noise,Error>`
**/
typedef OnPartCallback = String->String->Surprise<Noise,Error>;

/**
	`function onData(bytes:Bytes, pos:Int, length:Int):Surprise<Noise,Error>`
**/
typedef OnDataCallback = Bytes->Int->Int->Surprise<Noise,Error>;

/**
	`function onEnd():Surprise<Noise,Error>`
**/
typedef OnEndPartCallback = Void->Surprise<Noise,Error>;
