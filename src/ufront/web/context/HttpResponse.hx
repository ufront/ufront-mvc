package ufront.web.context;

import haxe.io.Bytes;
import haxe.io.BytesOutput;
import haxe.io.Output;
import ufront.core.OrderedStringMap;
import ufront.web.HttpError;
import haxe.ds.StringMap;

/**
The response that will be sent to the browser

Please see the docs for each platform implementation for any specific details:

- `neko.ufront.web.context.HttpResponse`
- `php.ufront.web.context.HttpResponse`
- `js.ufront.web.context.HttpResponse`
- `nodejs.ufront.web.context.HttpResponse`
**/
class HttpResponse {
	/**
	Create a `HttpResponse` using the platform specific implementation.

	Currently PHP, Neko and Client JS are supported.

	For NodeJS, please use:

	```
	new nodejs.ufront.web.HttpResponse(res); // An express.Response object.
	```

	Other platforms will get the default implementation, which will mostly work, except for `this.flush()`, which is what actually writes the HTTP response output.
	Calling `this.flush()` on a non-supported platform will throw an error.
	**/
	public static function create():HttpResponse {
		return
			#if php new php.ufront.web.context.HttpResponse();
			#elseif neko new neko.ufront.web.context.HttpResponse();
			#elseif (js && !nodejs) new js.ufront.web.context.HttpResponse();
			#elseif (js && nodejs) throw "Please use `new nodejs.ufront.web.HttpResponse(res)` instead";
			#else new HttpResponse();
			#end
	}

	static inline var CONTENT_TYPE = "Content-type";
	static inline var LOCATION = "Location";
	static inline var DEFAULT_CONTENT_TYPE = "text/html";
	static inline var DEFAULT_CHARSET = "utf-8";
	static inline var DEFAULT_STATUS = 200;
	static inline var MOVED_PERMANENTLY = 301;
	static inline var FOUND = 302;
	static inline var UNAUTHORIZED = 401;
	static inline var NOT_FOUND = 404;
	static inline var INTERNAL_SERVER_ERROR = 500;

	/**
	Get or set the HTTP "Content-type" header.

	The default value is `text/html`.
	**/
	public var contentType(get, set):String;

	/**
	Location to redirect to.
	Will add or remove a "Location" header from the HTTP headers.
	**/
	public var redirectLocation(get, set):Null<String>;

	/**
	Get or set the `charset` used in the HTTP "Content-type" header (when the type is `text/*`).

	The default value is `utf-8`.
	**/
	public var charset:String;

	/**
	The HTTP response status code.

	The default value is `200`.
	**/
	public var status:Int;

	var _buff:StringBuf;
	var _headers:OrderedStringMap<String>;
	var _cookies:StringMap<HttpCookie>;
	var _flushed:Bool;

	/**
	Create a new (blank) `HttpResponse`.

	Please note, you should generally use a platform specific `HttpResponse` implementation.
	**/
	public function new() {
		clear();
		_flushed = false;
	}

	/**
	Prevent the response from flushing.

	This is useful if some code has written to the output manually, (using `Sys.print` or similar), rather than writing to the response.
	**/
	public function preventFlush():Void {
		_flushed = true;
	}

	/**
	Write the output to the client response.

	This includes writing the cookies, the HTTP headers and then the content.

	Once it has been flushed, no futher HTTP headers can be set, and the content cannot be cleared - it is already sent to the client.

	Therefore you should try to only call `flush()` at the end of your request.
	This is managed automatically if you are using `HttpApplication`, `UfrontApplication` etc.

	This is an abstract method, it is implemented differently on each platform.
	It will throw a `NotImplemented` error if you are not using a platform-specific implementation.
	**/
	public function flush():Void { throw HttpError.notImplemented(); }

	/**
	Reset the HttpResponse to a blank state.

	This will clear the headers, cookies and content, and reset `this.contentType`, `this.charset` and `this.status`.
	**/
	public function clear():Void {
		clearCookies();
		clearHeaders();
		clearContent();
		contentType = null;
		charset = DEFAULT_CHARSET;
		status = DEFAULT_STATUS;
	}

	/**
	Clear any cookies set in this response so far.
	**/
	public function clearCookies():Void {
		_cookies = new StringMap();
	}

	/**
	Clear the content set in this response so far.
	**/
	public function clearContent():Void {
		_buff = new StringBuf();
	}

	/**
	Clear the HTTP headers set in this response so far.
	**/
	public function clearHeaders():Void {
		_headers = new OrderedStringMap();
	}

	/**
	Write a string to the HTTP response.
	**/
	public function write( s:String ):Void {
		if( null!=s )
			_buff.add( s );
	}

	/**
	Write a single character to the HTTP response.
	**/
	public function writeChar( c:Int ):Void {
		_buff.addChar( c );
	}

	/**
	Write a number of bytes to the HTTP response.
	**/
	public function writeBytes( b:Bytes, pos:Int, len:Int ):Void {
		_buff.add( b.getString(pos, len) );
	}

	/**
	Set a HTTP header on the response.
	**/
	public function setHeader( name:String, value:String ):Void {
		HttpError.throwIfNull( name );
		HttpError.throwIfNull( value );
		_headers.set( name, value );
	}

	/**
	Set a HTTP Cookie on the response.
	**/
	public function setCookie( cookie:HttpCookie ):Void {
		_cookies.set( cookie.name, cookie );
	}

	/**
	Get the current content output (`String`) of this response.
	**/
	public function getBuffer():String {
		return _buff.toString();
	}

	/**
	Get the `StringMap` of Cookies set in this response
	**/
	public function getCookies():StringMap<HttpCookie> {
		return _cookies;
	}

	/**
	Get the `OrderedStringMap` of HTTP headers set in this response.

	An `OrderedStringMap` is basically the same as a `StringMap`, but it preserves the order of the items (headers in this case).
	**/
	public function getHeaders():OrderedStringMap<String> {
		return _headers;
	}

	/**
	Set the HTTP Response Code to `FOUND` (302) and set the `redirectLocation`, which will set the `Location` HTTP header.

	If URL is null, the `Location` header will be removed.
	**/
	public function redirect( url:String ):Void {
		status = FOUND;
		redirectLocation = url;
	}

	/**
	Set the HTTP Response Code to `DEFAULT_STATUS` (200).
	**/
	public function setOk():Void {
		status = DEFAULT_STATUS;
	}

	/**
	Set the HTTP Response Code to `UNAUTHORIZED` (401).
	**/
	public function setUnauthorized():Void {
		status = UNAUTHORIZED;
	}

	/**
	Ask the browser to retrieve a username/password from the user.

	This is a shortcut for `setUnauthorized()` and `setHeader("WWW-Authenticate", "Basic realm="+message)`.
	**/
	public function requireAuthentication( message:String ) {
		setUnauthorized();
		setHeader( "WWW-Authenticate", 'Basic realm="$message"' );
	}

	/**
	Set the HTTP Response Code to `NOT_FOUND` (404).
	**/
	public function setNotFound():Void {
		status = NOT_FOUND;
	}

	/**
	Set the HTTP Response Code to `INTERNAL_SERVER_ERROR` (500).
	**/
	public function setInternalError():Void {
		status = INTERNAL_SERVER_ERROR;
	}

	/**
	Set the HTTP Response Code to `MOVED_PERMANENTLY` (301) and set the `redirectLocation`, which will set the `Location` HTTP header.

	If URL is null, the `Location` header will be removed.
	**/
	public function permanentRedirect( url:String ):Void {
		status = MOVED_PERMANENTLY;
		redirectLocation = url;
	}

	/**
	A shortcut to tell whether the current status indicates this response is a redirect (`true`) or not (`false`).
	**/
	public function isRedirect():Bool {
		return Math.floor( status/100 ) == 3;
	}

	/**
	A shortcut to tell whether the current status indicates this response is a permanent redirect (`true`) or not (`false`)
	**/
	public function isPermanentRedirect():Bool {
		return status == MOVED_PERMANENTLY;
	}

	@:keep
	function hxSerialize( s:haxe.Serializer ) {
		s.serialize( _buff.toString() );
		s.serialize( _headers );
		s.serialize( _cookies );
		s.serialize( _flushed );
	}

	@:keep
	function hxUnserialize( u:haxe.Unserializer ) {
		_buff = new StringBuf();
		_buff.add( u.unserialize() );
		_headers = u.unserialize();
		_cookies = u.unserialize();
		_flushed = u.unserialize();
	}

	function get_contentType():String {
		return _headers.get( CONTENT_TYPE );
	}

	function set_contentType(v:String):String {
		if ( null==v )
			_headers.set( CONTENT_TYPE, DEFAULT_CONTENT_TYPE )
		else
			_headers.set( CONTENT_TYPE, v );
		return v;
	}

	function get_redirectLocation():String {
		return _headers.get( LOCATION );
	}

	function set_redirectLocation( v:String ):String {
		if ( null==v )
			_headers.remove( LOCATION )
		else
			_headers.set( LOCATION, v );
		return v;
	}
}
