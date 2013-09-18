package ufront.web.context;
import haxe.io.Bytes;
import haxe.io.BytesOutput;
import haxe.io.Output;
import thx.collection.HashList;
import thx.error.NullArgument;
import thx.error.NotImplemented;
import haxe.ds.StringMap;

/**
	The response that will be sent to the browser
**/
class HttpResponse
{
	/**
		Create a `HttpResponse` using the platform specific implementation.

		Currently PHP and Neko are supported.  Other platforms will get the default implementation, which will mostly work, except for flush(), which actually writes the HTTP response output.
	**/
	public static function create():HttpResponse
	{
		return
			#if php
				new php.ufront.web.context.HttpResponse();
			#elseif neko
				new neko.ufront.web.context.HttpResponse();
			#else
				// use the default implementation.  `flush()` won't work...
				new HttpResponse();
			#end
	}
	
	/** "Content-type" **/
	static inline var CONTENT_TYPE = "Content-type";
	
	/** "Location" **/
	static inline var LOCATION = "Location";
	
	/** "text/html" **/
	static inline var DEFAULT_CONTENT_TYPE = "text/html";
	
	/** "utf-8" **/
	static inline var DEFAULT_CHARSET = "utf-8";
	
	/** 200 **/
	static inline var DEFAULT_STATUS = 200;
	
	/** 301 **/
	static inline var MOVED_PERMANENTLY = 301;
	
	/** 302 **/
	static inline var FOUND = 302;
	
	/** 401 **/
	static inline var UNAUTHORIZED = 401;
	
	/** 404 **/
	static inline var NOT_FOUND = 404;
	
	/** 500 **/
	static inline var INTERNAL_SERVER_ERROR = 500;
	
	/** Get or set the Http "Content-type" header. **/
	public var contentType(get, set):String;

	/** Location to redirect to. Will add or remove a "Location" header from the HTTP headers **/
	public var redirectLocation(get, set):String;

	/** Get or set the `charset` used in the HTTP "Content-type" header when the type is "text/*" **/
	public var charset:String;

	/** The HTTP Response code.  See the inline static vars for common values **/
	public var status:Int;

	var _buff:StringBuf;
	var _headers:HashList<String>;
	var _cookies:StringMap<HttpCookie>;

	/**
		Use DEFAULT_CHARSET, DEFAULT_STATUS.  contentType is null by default.
	**/
	public function new() {
		clear();
		contentType = null;
		charset = DEFAULT_CHARSET;
		status = DEFAULT_STATUS;
	}

	/**
		Write the output to the response.  

		This includes writing the cookies, the HttpHeaders and then the content.

		This is an abstract method, it is implemented differently on each platform.

		It will throw NotImplemented() unless a subclass overrides this method.
	**/
	public function flush():Void { throw new NotImplemented(); }

	/**
		Will clear existing headers, cookies and content
	**/
	public function clear() {
		clearCookies();
		clearHeaders();
		clearContent();
	}

	/**
		Clear any cookies set in this response so far.
	**/
	public function clearCookies() {
		_cookies = new StringMap();
	}

	/**
		Clear the content set in this response so far.
	**/
	public function clearContent() {
		_buff = new StringBuf();
	}

	/**
		Clear the headers set in this response so far.
	**/
	public function clearHeaders() {
		_headers = new HashList();
	}

	/**
		Write a string to the HTTP response
	**/
	public function write( s:String ) {
		if( null!=s )
			_buff.add( s );
	}

	/**
		Write a single character to the HTTP response
	**/
	public function writeChar( c:Int ) {
		_buff.addChar( c );
	}

	/**
		Write a number of bytes to the HTTP response
	**/
	public function writeBytes( b:Bytes, pos:Int, len:Int ) {
		_buff.add( b.readString(pos, len) );
	}

	/**
		Set a HTTP Header on the response
	**/
	public function setHeader( name:String, value:String ) {
		NullArgument.throwIfNull( name );
		NullArgument.throwIfNull( value );
		_headers.set( name, value );
	}

	/**
		Set a HTTP Cookie on the response
	**/
	public function setCookie( cookie:HttpCookie ) {
		_cookies.set( cookie.name, cookie );
	}

	/**
		Get the current content output (String) of this response
	**/
	public function getBuffer():String {
		return _buff.toString();
	}

	/**
		Get the `StringMap` of Cookies set in this response
	**/
	public function getCookies() {
		return _cookies;
	}

	/**
		Get the `HashList` of HTTP headers set in this response.

		A HashList is basically a StringMap, but it preserves the order of the items (headers in this case)
	**/
	public function getHeaders() {
		return _headers;
	}

	/**
		Set the HTTP Response Code to `FOUND` (302) and set the `redirectLocation`, which will set the `Location` HTTP header.

		If URL is null, the `Location` header will be removed.
	**/
	public function redirect( url:String ) {
		status = FOUND;
		redirectLocation = url;
	}

	/**
		Set the HTTP Response Code to `DEFAULT_STATUS` (200)
	**/
	public function setOk() {
		status = DEFAULT_STATUS;
	}

	/**
		Set the HTTP Response Code to `UNAUTHORIZED` (401)
	**/
	public function setUnauthorized() {
		status = UNAUTHORIZED;
	}

	/**
		Set the HTTP Response Code to `NOT_FOUND` (404)
	**/
	public function setNotFound() {
		status = NOT_FOUND;
	}

	/**
		Set the HTTP Response Code to `INTERNAL_SERVER_ERROR` (500)
	**/
	public function setInternalError() {
		status = INTERNAL_SERVER_ERROR;
	}

	/**
		Set the HTTP Response Code to `MOVED_PERMANENTLY` (301) and set the `redirectLocation`, which will set the `Location` HTTP header.

		If URL is null, the `Location` header will be removed.
	**/
	public function permanentRedirect( url:String ) {
		status = MOVED_PERMANENTLY;
		redirectLocation = url;
	}

	/**
		A shortcut to tell whether the current status indicates this response is a redirect (true) or not (false)
	**/
	public function isRedirect() {
		return Math.floor( status/100 ) == 3;
	}

	/**
		A shortcut to tell whether the current status indicates this response is a permanent redirect (true) or not (false)
	**/
	public function isPermanentRedirect() {
		return status == MOVED_PERMANENTLY;
	}

	function get_contentType() {
		return _headers.get( CONTENT_TYPE );
	}

	function set_contentType(v:String) {
		if ( null==v )
			_headers.set( CONTENT_TYPE, DEFAULT_CONTENT_TYPE )
		else
			_headers.set( CONTENT_TYPE, v );
		return v;
	}

	function get_redirectLocation() {
		return _headers.get( LOCATION );
	}

	function set_redirectLocation( v:String ) {
		if ( null==v )
			_headers.remove( LOCATION )
		else
			_headers.set( LOCATION, v );
		return v;
	}
}