package js.ufront.web.context;

import haxe.io.Bytes;
import thx.core.Error;
import ufront.web.upload.*;
import ufront.web.UserAgent;
import ufront.core.MultiValueMap;
import haxe.ds.StringMap;
import ufront.web.context.HttpRequest.OnPartCallback;
import ufront.web.context.HttpRequest.OnDataCallback;
import ufront.web.context.HttpRequest.OnEndPartCallback;
import ufront.core.Sync;
import js.Browser.*;
using tink.CoreApi;
using thx.core.Strings;
using StringTools;

/**
	An implementation of HttpRequest for Client Side JS.

	@author Jason O'Neil
**/
class HttpRequest extends ufront.web.context.HttpRequest {

	public function new() {}

	override function get_queryString() {
		if ( queryString==null ) {
			// Get the query string from document.location, but ignore the leading "?" character.
			queryString = document.location.search.substr( 1 );

			var indexOfHash = queryString.indexOf( "#" );
			if ( indexOfHash>-1 ) {
				queryString = queryString.substring( 0, indexOfHash );
			}
		}
		return queryString;
	}

	override function get_postString() {
		if ( httpMethod=="GET" )
			return "";
		if ( null==postString ) {
			postString = window.history.state.post;
		}
		return postString;
	}

	/**
		`parseMultipart` is not implemented for ufront-client-mvc, and will always return a success with no action taken.
	**/
	override public function parseMultipart( ?onPart:OnPartCallback, ?onData:OnDataCallback, ?onEndPart:OnEndPartCallback ):Surprise<Noise,Error> {
		return Sync.success();
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
			httpMethod = Reflect.hasField(window.history.state, "post") ? "POST" : "GET";
		}
		return httpMethod;
	}

	override function get_scriptDirectory() {
		if ( scriptDirectory==null ) {
			// This does not make much sense on the client.
			throw 'Cannot access request.scriptDirectory in ufront-client-mvc';
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
