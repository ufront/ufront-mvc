package ufront.test;

import ufront.web.context.HttpRequest;
import ufront.web.UserAgent;
import ufront.core.MultiValueMap;
import ufront.core.CaseInsensitiveMultiValueMap;
import ufront.web.upload.UFFileUpload;
import tink.CoreApi;
import ufront.web.HttpError;

/**
A mock HttpRequest class that allows you to emulate HTTP requests.

This is used throughout by `ufront.test.TestUtils`.

Each property has a corresponding setter method, for example `params` and `setParams()`.

The setter methods return the `MockHttpRequest`, and can be used in a fluid way:

```haxe
var request =
	new MockHttpRequest( "/index.html" )
	.setHttpMethod( "POST" )
	.setPost([ "name": "Jason O'Neil" ])
	.setCookies([ "sessionID": "0" ])
	.setIsMultipart( false );
```
**/
class MockHttpRequest extends HttpRequest {

	/**
	Create a new MockHttpRequest, optionally specifying the uri.
	If the uri is not specified, the default "/" will be used.
	**/
	public function new( ?uri:String="/" ) {
		setQueryString( "" );
		setPostString( "" );
		setQuery( new Map() );
		setPost( new Map() );
		setFiles( new Map() );
		setCookies( new Map() );
		setHostName( "localhost" );
		setClientIP( "127.0.0.1" );
		setUri( uri );
		setClientHeaders( new CaseInsensitiveMultiValueMap() );
		setUserAgent( UserAgent.fromString("Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:43.0) Gecko/20100101 Firefox/43.0") );
		setHttpMethod( "GET" );
		setScriptDirectory( "/var/www/" );
		setAuthorization( null );
		setIsMultipart( false );
	}

	/**
	Set a custom `params` map.
	If you do not set this, `params` will default to the combined values of `post`, `query`, and `cookies` the first time it is accessed.
	**/
	public function setParams( params:MultiValueMap<String> ):MockHttpRequest {
		this.params = params;
		return this;
	}

	override function get_queryString():String return queryString;
	public function setQueryString( qs:String ):MockHttpRequest {
	queryString = qs;
	return this;
	}

	override function get_postString():String return postString;
	public function setPostString( ps:String ):MockHttpRequest {
		this.postString = ps;
		return this;
	}

	override function get_query():MultiValueMap<String> return query;
	public function setQuery( query:MultiValueMap<String> ):MockHttpRequest {
		this.query = query;
		return this;
	}

	override function get_post():MultiValueMap<String> return post;
	public function setPost( post:MultiValueMap<String> ):MockHttpRequest {
		this.post = post;
		return this;
	}

	override function get_files():MultiValueMap<UFFileUpload> return files;
	public function setFiles( files:MultiValueMap<UFFileUpload> ):MockHttpRequest {
		this.files = files;
		return this;
	}

	override function get_cookies():MultiValueMap<String> return cookies;
	public function setCookies( cookies:MultiValueMap<String> ):MockHttpRequest {
		this.cookies = cookies;
		return this;
	}

	override function get_hostName():String return hostName;
	public function setHostName( hostName:String ):MockHttpRequest {
		this.hostName = hostName;
		return this;
	}

	override function get_clientIP():String return clientIP;
	public function setClientIP( clientIP:String ):MockHttpRequest {
		this.clientIP = clientIP;
		return this;
	}

	override function get_uri():String return uri;
	public function setUri( uri:String ):MockHttpRequest {
		this.uri = uri;
		return this;
	}

	override function get_clientHeaders():CaseInsensitiveMultiValueMap<String> return clientHeaders;
	public function setClientHeaders( clientHeaders:CaseInsensitiveMultiValueMap<String> ):MockHttpRequest {
		this.clientHeaders = clientHeaders;
		return this;
	}

	override function get_userAgent():UserAgent return userAgent;
	public function setUserAgent( userAgent:UserAgent ):MockHttpRequest {
		this.userAgent = userAgent;
		return this;
	}

	override function get_httpMethod():String return httpMethod;
	public function setHttpMethod( httpMethod:String ):MockHttpRequest {
		this.httpMethod = httpMethod;
		return this;
	}

	override function get_scriptDirectory():String return scriptDirectory;
	public function setScriptDirectory( scriptDirectory:String ):MockHttpRequest {
		this.scriptDirectory = scriptDirectory;
		return this;
	}

	override function get_authorization():{ user:String, pass:String } return authorization;
	public function setAuthorization( authorization:{ user:String, pass:String } ):MockHttpRequest {
		this.authorization = authorization;
		return this;
	}

	public function setIsMultipart( isMultipart:Bool ):MockHttpRequest {
		if ( isMultipart )
			clientHeaders.set( "Content-Type", "multipart/form-data; charset=UTF-8" );
		else
			clientHeaders.set( "Content-Type", "application/x-www-form-urlencoded; charset=UTF-8" );
		return this;
	}

	/**
	Please note, `parseMultipart` is not supported and cannot be mocked.
	You can instead use `this.setPost` and `this.setFiles` to mock the higher level API.
	**/
	override public function parseMultipart( ?onPart:OnPartCallback, ?onData:OnDataCallback, ?onEndPart:OnEndPartCallback ):Surprise<Noise,Error> return throw HttpError.wrap( "parseMultipart is not supported in MockHttpRequest" );
}
