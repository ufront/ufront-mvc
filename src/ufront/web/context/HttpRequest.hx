package ufront.web.context;
import haxe.io.Bytes;
import haxe.ds.StringMap;
import ufront.web.upload.UFFileUpload;
import ufront.core.MultiValueMap;
import ufront.web.HttpError;
using tink.CoreApi;
using StringTools;

/**
A description of the current HTTP request coming from the client.

A HttpRequest object holds all the information about the current request coming from the client.

This includes:

- The URI of this request. See `this.uri`.
- The HTTP method of the current request . See `this.httpMethod`.
- The IP address of the client making the request . See `this.clientIP`.
- The host name of the current server . See `this.hostName`.
- The directory on the web server that the script is running from. See `this.scriptDirectory`.
- The username and password included in this request . See `this.authorization`.
- The query (or "GET") parameters included in the current request. See `this.query`.
- The raw string of query parameters. See `this.queryString`.
- The post parameters included in the current request. See `this.post`.
- The raw string of post parameters. See `this.postString`.
- The cookies included in this request. See `this.cookies`.
- A map of all parameters in the request, whether they are from `query`, `post` or `cookies`. See `this.params`.
- The HTTP headers sent as aprt of the client's request. See `this.clientHeaders`.
- A user agent object that attempts to make sense of the user agent string. See `this.userAgent`.
- The file uploads included in this request. See `this.files`.
- Is the current request a multipart request (form upload)? See `this.isMultipart()`.
- Attempt to process the upload data included in this request. See `this.parseMultipart()`.

__Array Parameters__

HTML forms and HTTP requests allow you to have multiple values for the same name.
`HttpRequest` uses `MultiValueMap` to allow you to access either a single value or a collection of values for a given name easily.

There are some platform differences to take note of:

- For PHP, multiple values in HTTP requests are only supported if the parameter name ends with `[]`.
- Because of the PHP limitation, other platforms (neko etc) ignore a `[]` at the end of a parameter name.
- When trying to access the values of an input such as `<select name="people[]">...</select>` you should use `HttpRequest.params["people"]`, not including the trailing `[]` in the parameter name.
- Complex lists, such as the following, are not supported: `<input name="person[1][firstName]" />`, only simple "[]" is supported: `<input name="person[]">`

__Platform Implementations__

This base class is mostly abstract methods, each platform must implement the key details.

You can use `HttpRequest.create()` to create the appropriate sub-class for most platforms.
With NodeJS however, where you should use:

```
new nodejs.ufront.web.HttpRequest(req); // An express.Request object.
```

Please see the docs for each platform implementation for any specific details:

- `neko.ufront.web.context.HttpRequest`
- `php.ufront.web.context.HttpRequest`
- `js.ufront.web.context.HttpRequest`
- `nodejs.ufront.web.context.HttpRequest`
**/
class HttpRequest {
	/**
	Create a `HttpRequest` using the platform specific implementation.

	Currently supports PHP, Neko and client JS.
	**/
	public static function create():HttpRequest {
		return
			#if php new php.ufront.web.context.HttpRequest();
			#elseif neko new neko.ufront.web.context.HttpRequest();
			#elseif (js && !nodejs) new js.ufront.web.context.HttpRequest();
			#elseif (js && nodejs) throw "Please use `new nodejs.ufront.web.HttpRequest(req)` instead";
			#else throw HttpError.notImplemented();
			#end
	}

	/**
	A `MultiValueMap` of all the parameters supplied in this request.

	The parameters are collected in the following order:

	- cookies
	- query-string parameters
	- post values

	with the latter taking precedence over the former.

	For example, if both a cookie and a post variable define a parameter `name`, calling `request.params["name"]` will show the POST value.
	In that example, if you would like to access all the various values of `name`, you can use `request.params.getAll("name")` or separately access `request.cookies["name"]` or `request.post["name"]`.
	**/
	@:isVar public var params(get, null):MultiValueMap<String>;
	function get_params():MultiValueMap<String> {
		if ( null==params ) {
			params = MultiValueMap.combine( [cookies,query,post] );
		}
		return params;
	}

	/**
	The raw query string in a GET request.

	This is the part of the URL following a `?` character.

	Will return an empty String if there are no GET parameters.
	**/
	public var queryString(get, null):String;
	function get_queryString():String return throw HttpError.abstractMethod();

	/**
	The raw post string in a POST request.

	Will return an empty String if there are no POST parameters.
	**/
	public var postString(get, null):String;
	function get_postString():String return throw HttpError.abstractMethod();

	/**
	The query parameters included in this request for this request.

	These are the parameters supplied in the URL, following the `?` character.
	**/
	public var query(get, null):MultiValueMap<String>;
	function get_query():MultiValueMap<String> return throw HttpError.abstractMethod();

	/**
	The POST parameters for this request.

	If there are no POST parameters, or this is a GET request, this will return an empty map.

	> **Note:** If the request is a multipart request, and `parseMultipart` has not been called, it will be called to fetch all the post data from the various parts.
	> Because `parseMultipart` can only be called once, this will prevent you from being able to process any file uploads.
	>
	> If you need access to file uploads, please ensure `parseMultipart` is called before `post` is accessed.
	> This can be achieved easily by using upload middleware at the start of your request to check for any uploads.
	>
	> If any files were uploaded, they will appear in the "post" values with their parameter name, and the value will contain the original filename of the upload.
	**/
	public var post(get, null):MultiValueMap<String>;
	function get_post():MultiValueMap<String> return throw HttpError.abstractMethod();

	/**
	File uploads that were part of a POST / multipart request.

	Please note this is not populated automatically, you must use some request middleware to process the multipart data and populate the `files` field with appropriate `UFFileUpload` objects.
	**/
	public var files(get, null):MultiValueMap<UFFileUpload>;
	function get_files():MultiValueMap<UFFileUpload> {
		if ( null==files ) {
			files = new MultiValueMap();
		}
		return files;
	}

	/**
	The Cookies that were included with this request.
	**/
	public var cookies(get, null):MultiValueMap<String>;
	function get_cookies():MultiValueMap<String> return throw HttpError.abstractMethod();

	/**
	The host name of the current server.
	**/
	public var hostName(get, null):String;
	function get_hostName():String return throw HttpError.abstractMethod();

	/**
	The Client's IP address.
	**/
	public var clientIP(get, null):String;
	function get_clientIP():String return throw HttpError.abstractMethod();

	/**
	The Uri requested in this HTTP request.

	This is the URI before any filters have been applied.

	See `HttpContext.getRequestUri()` for a filtered version of the URI.
	**/
	public var uri(get, null):String;
	function get_uri():String return throw HttpError.abstractMethod();

	/**
	The HTTP headers supplied by the client in this request.
	**/
	public var clientHeaders(get, null):MultiValueMap<String>;
	function get_clientHeaders():MultiValueMap<String> return throw HttpError.abstractMethod();

	/**
	Information about the User-Agent that made this request, based on the "User-Agent" HTTP header.

	Please see `UserAgent` for more information.
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
	function get_httpMethod():String return throw HttpError.abstractMethod();

	/**
	The path of the currently executing script.

	This is the path to your `index` file, not to the current class or controller.

	It will usually be an absolute path, but depending on the environment it may be relative.

	This path will always include a trailing slash.
	**/
	public var scriptDirectory(get, null):String;
	function get_scriptDirectory():String return throw HttpError.abstractMethod();

	/**
	Gives the username and password supplied by the `Authorization` client header.

	If no `Authorization` header was specified, it will return null.

	If `Authorization` header was specified, but it did not have exactly two parameters, it will throw an exception.

	To trigger the login box to open on the browser, use `HttpResponse.requireAuthentication("Please login")`.
	**/
	public var authorization(get, null):{ user:String, pass:String };
	function get_authorization():{ user:String, pass:String } return throw HttpError.abstractMethod();

	/**
	Check if the current request is a `multipart/form-data` request.

	This is a shortcut for: `clientHeaders["Content-Type"].startsWith("multipart/form-data")`.
	**/
	public function isMultipart():Bool {
		return clientHeaders.exists("Content-Type") && clientHeaders["Content-Type"].startsWith("multipart/form-data");
	}

	/**
	Parse the multipart data of this request.

	> **Note:** If you merely wish to access file uploads, it is probably better to use an existing `RequestMiddleware` that parses multipart data and gives access to the uploads through `HttpRequest.files`.
	> Calling `parseMultipart()` manually is mostly intended for people developing new file-upload middleware.

	If a POST request contains multipart data, `parseMultipart` must be called in order to have access to both the POST parameters and to uploaded files.

	Accessing `HttpRequest.post` on a multipart request will call `parseMultipart()` but not process any file uploads.
	Because of this, it is recommended that you use a `RequestMiddleware` very early in your request, before `HttpRequest.post` is ever called, so that you can parse your file uploads, even if you do not handle them until later.

	In each platform's implementation of `parseMultipart()`, it will take care of parsing post variables to `HttpRequest.post`, and then call the `onPart`, `onData` (multiple times) and `onEndPart` for each file upload.

	You should only call `parseMultipart()` a maximum of once per request, and an exception will be thrown if you attempt to call it more than once.

	If this method is called on a request which was not multipart encoded, the result is unspecified.

	It is safe to assume that only one of the callbacks will be running at a time, and that they will run in order for each file.

	Even though the method signiatures here require returning a `Future`, these will be ignored on some platforms, such as neko.
	Check the documentation on the specific `HttpRequest` implementation for details.

	@param onPart (optional) - called once at the start of each new file. See `OnPartCallback`.
	@param onData (optional) - called multiple times (in order) for each file. See `OnDataCallback`.
	@param onEndPart (optional) - called after all data for a part has been received. See `OnEndPartCallback`.
	**/
	public function parseMultipart( ?onPart:OnPartCallback, ?onData:OnDataCallback, ?onEndPart:OnEndPartCallback ):Surprise<Noise,Error> return throw HttpError.abstractMethod();
}

/**
A callback to process the start of a new file upload.

This will always be followed by one or more `OnDataCallback` calls.

```
function onPart(paramName:String, origFileName:String):Surprise<Noise,Error> {
  // ...
}
```

Please note, not all platforms will support asynchronous operations in these callbacks.
Please see the documentation on each platforms implementation of `HttpRequest` for details.
**/
typedef OnPartCallback = String->String->Surprise<Noise,Error>;

/**
A callback to process a chunk of data for a file upload.

This will follow an `OnPartCallback` call, and may be called multiple times for each file.
Once all the data has been processed, the `OnEndPartCallback` will be called.

```
function onData(bytes:Bytes, pos:Int, length:Int):Surprise<Noise,Error> {
  // ...
}
```

Please note, not all platforms will support asynchronous operations in these callbacks.
Please see the documentation on each platforms implementation of `HttpRequest` for details.
**/
typedef OnDataCallback = Bytes->Int->Int->Surprise<Noise,Error>;

/**
A callback to process the end of a file upload.

This will be called once all the data has been processed and all `OnDataCallback` calls are complete.

```
function onEnd():Surprise<Noise,Error> {
  // ...
}
```

Please note, not all platforms will support asynchronous operations in these callbacks.
Please see the documentation on each platforms implementation of `HttpRequest` for details.
**/
typedef OnEndPartCallback = Void->Surprise<Noise,Error>;
