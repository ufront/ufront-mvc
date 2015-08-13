package js.ufront.web.context;

import haxe.io.Bytes;
import ufront.web.upload.*;
import ufront.web.UserAgent;
import ufront.web.HttpError;
import ufront.core.MultiValueMap;
import haxe.ds.StringMap;
import ufront.web.context.HttpRequest.OnPartCallback;
import ufront.web.context.HttpRequest.OnDataCallback;
import ufront.web.context.HttpRequest.OnEndPartCallback;
import ufront.core.AsyncTools;
import js.Browser.*;
using tink.CoreApi;
using StringTools;

/**
An implementation of `ufront.web.context.HttpRequest` for client-side JS.

A browser side `HttpRequest` reads the current state from `Browser.document` and `Browser.window`.

It works with the `PushState` library to be able to emulate multiple requests without reloading the page.
The `PushState` library also allows us to fake a `POST` request.

Platform quirks with `HttpRequest` and client-side JS:

- `this.httpMethod`, `this.post` and `this.postString` - Implemented using `PushState` and faking a post request.
- `this.clientHeaders` - Not implemented: Not accessible in a browser environment. Will always be an empty Map.
- `this.authorization` - Not implemented: HTTP Headers not accessible in a browser environment.
- `this.userAgent` - Not implemented: HTTP Headers not accessible in a browser environment. This could be worked-around if there is demand.
- `this.clientIP` - Not implemented: Not accessible from in a browser environment. Will always return "127.0.0.1".
- `this.scriptDirectory` - Not implemented: It does not make sense in a browser environment.
- `this.parseMultipart()` - Not implemented: This is not implemented, though may be possible using the HTML5 File Api.

@author Franco Ponticelli, Jason O'Neil
**/
class HttpRequest extends ufront.web.context.HttpRequest {

	public function new() {}

	override function get_queryString() {
		if ( queryString==null ) {
			// Get the query string from document.location, but ignore the leading "?" character.
			queryString = document.location.search.substr( 1 );
		}
		return queryString;
	}

	override function get_postString() {
		if ( httpMethod=="GET" )
			return "";
		if ( null==postString ) {
			postString = window.history.state.__postData;
		}
		return postString;
	}

	/**
	Not implemented for `ufront-client-mvc`.
	This will always return a success with no action taken.
	**/
	override public function parseMultipart( ?onPart:OnPartCallback, ?onData:OnDataCallback, ?onEndPart:OnEndPartCallback ):Surprise<Noise,Error> {
		return SurpriseTools.success();
	}

	override function get_query() {
		if ( query==null )
			query = getMultiValueMapFromString(queryString);
		return query;
	}

	override function get_post() {
		if ( null==post ) {
			post =
				if ( httpMethod=="GET" ) new MultiValueMap();
				else getMultiValueMapFromString( postString, true );
		}
		return post;
	}

	override function get_cookies() {
		if ( cookies==null ) {
			cookies = new MultiValueMap();
			for ( cookie in document.cookie.split(";") ) {
				cookie = cookie.trim();
				var parts = cookie.split("=");
				cookies.add( parts[0], parts[1] );
			}
		}
		return cookies;
	}

	override function get_hostName() {
		if ( hostName==null )
			hostName = document.location.hostname;
		return hostName;
	}

	/**
	Client IP address isn't available in pure JS, we would need to read the result from the server.
	**/
	override function get_clientIP() {
		if ( clientIP==null )
			clientIP = "127.0.0.1";
		return clientIP;
	}

	override function get_uri() {
		if ( uri==null ) {
			uri = document.location.pathname.urlDecode();
		}
		return uri;
	}

	override function get_clientHeaders() {
		if ( clientHeaders==null ) {
			clientHeaders = new StringMap();
			// TODO: decide if we want to emulate any headers, such as `referrer` and `user-agent`, which we can fetch from the browser.
		}
		return clientHeaders;
	}

	override function get_httpMethod() {
		if ( httpMethod==null ) {
			var state = window.history.state;
			httpMethod = state!=null && Reflect.hasField(window.history.state,"__postData") ? "POST" : "GET";
		}
		return httpMethod;
	}

	override function get_scriptDirectory() {
		if ( scriptDirectory==null ) {
			// This does not make much sense on the client.
			throw HttpError.internalServerError( 'Cannot access request.scriptDirectory in ufront-client-mvc' );
		}
		return scriptDirectory;
	}

	override function get_authorization() {
		// It's not possible to get HTTP Auth from Javascript.
		return null;
	}

	static function getMultiValueMapFromString(s:String, ?decodeRequired=false):MultiValueMap<String> {
		var map = new MultiValueMap();
		for (part in s.split("&")) {
			var index = part.indexOf("=");
			if ( index>0 ) {
				var name = part.substr(0,index);
				var val = part.substr(index+1);
				if ( decodeRequired )
					val = val.urlDecode();
				map.add( name, val );
			}
		}
		return map;
	}
}
