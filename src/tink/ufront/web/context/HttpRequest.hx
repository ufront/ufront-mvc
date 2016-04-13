package tink.ufront.web.context;

import haxe.io.Bytes;
import ufront.web.upload.*;
import ufront.web.UserAgent;
import ufront.web.HttpError;
import ufront.web.url.*;
import ufront.core.*;
import haxe.ds.StringMap;
import haxe.crypto.Base64;
import ufront.web.context.HttpRequest.OnPartCallback;
import ufront.web.context.HttpRequest.OnDataCallback;
import ufront.web.context.HttpRequest.OnEndPartCallback;
import tink.http.Request;

using haxe.io.Path;
using ufront.core.AsyncTools;
using tink.CoreApi;
using StringTools;
using Lambda;

/**
	An implementation of `ufront.web.context.HttpRequest` for Neko and PHP, based on the `neko.Web` and `php.Web` API.

	Supported servers on Neko:

	- `mod_neko` on Apache.
	- `mod_tora` on Apache.
	- `mod_tora` with FastCGI support (for Nginx etc).
	- `nekotools server`

	Platform quirks:

	- Neko: `HttpRequest.parseMultipart` completely fails on `nekotools server`.
	  If you are using uploads in your app, it is recomended to have a development environment using a more thoroughly tested server.
	- Neko and PHP: `HttpRequest.parseMultipart` callbacks **must** function synchronously, despite the fact they are supposed to return a `Future`.

	@author Franco Ponticelli, Jason O'Neil
**/
@:allow(ufront)
class HttpRequest extends ufront.web.context.HttpRequest {

	var request:IncomingRequest;
	
	public function new(request) {
		this.request = request;
	}

	override function get_queryString() {
		if ( queryString==null ) {
			queryString = PartialUrl.parse(request.header.uri).query.map(function(q) return q.name + (q.value != null ? '=' + q.value : '')).join('&');
			
			if ( queryString==null )
				queryString = "";

			var indexOfHash = queryString.indexOf("#");
			if ( indexOfHash>-1 ) {
				queryString = queryString.substring( 0, indexOfHash );
			}
		}
		return queryString;
	}
	
	public function setPostString(v) postString = v;

	override function get_postString() {
		if(postString == null) postString = "";
		return postString;
	}

	var _parsed:Bool;

	/**
		`HttpRequest.parseMultipart()` implementation method for mod_neko.

		Please see documentation on `ufront.web.context.HttpRequest.parseMultipart` for general information.

		Specific implementation details for neko:

		- This uses the `parse_multipart_data` function from the `mod_neko` NDLL, which is also used by `neko.Web.parseMultipart`.
		- Because of this, `onPart` and `onData` will run synchronously - the moment the callback finishes, the next callback will continue.
		- We suggest on neko you only use callbacks which can run synchronously.
		- `onEndPart` will not be called until all `onPart` and `onData` functions have finished firing.
	**/
	override public function parseMultipart( ?onPart:OnPartCallback, ?onData:OnDataCallback, ?onEndPart:OnEndPartCallback ):Surprise<Noise,Error> {
		// if ( !isMultipart() )
		// 	return SurpriseTools.success();
		// 
		// // Prevent this running more than once.
		// if (_parsed)
		// 	throw HttpError.internalServerError( "parseMultipart() has been called more than once." );
		// 
		// _parsed = true;
		// 
		// // Default values, prepare for processing
		// if ( onPart==null ) onPart = function(_,_) return Success(Noise).asFuture();
		// if ( onData==null ) onData = function(_,_,_) return Success(Noise).asFuture();
		// if ( onEndPart==null ) onEndPart = function() return Success(Noise).asFuture();
		// 
		// post = new MultiValueMap();
		// var noParts:Bool = true,
		//     isFile:Bool = false,
		//     partName:String = null,
		//     fileName:String = null,
		//     currentContent:String = null,
		//     callbackFutures = [],
		//     errors = [];
		// 
		// // callbacks for processing data
		// function processCallbackResult( surprise:Surprise<Noise,Error> ) {
		// 	callbackFutures.push( surprise );
		// 	surprise.handle( function(outcome) {
		// 		switch outcome {
		// 			case Failure(err): errors.push( err.toString() );
		// 			default:
		// 		}
		// 	});
		// }
		// function doEndOfPart() {
		// 	if ( isFile ) {
		// 		processCallbackResult( onEndPart() );
		// 	}
		// 	else if ( currentContent!=null ) {
		// 		post.add( partName, currentContent );
		// 	}
		// }
		// function doPart( newPartName:String, newPartFilename:String ) {
		// 	doEndOfPart();
		// 	noParts = false;
		// 	currentContent = null;
		// 	partName = newPartName.urlDecode();
		// 	isFile = false;
		// 	if ( newPartFilename!=null && newPartFilename!="" ) {
		// 		fileName = newPartFilename.urlDecode();
		// 		post.add(partName, fileName);
		// 		processCallbackResult( onPart(partName,fileName) );
		// 		isFile = true;
		// 	}
		// };
		// function doData( bytes:Bytes, pos:Int, len:Int ) {
		// 	if ( isFile ) {
		// 		if (len > 0) processCallbackResult( onData(bytes,pos,len) );
		// 	}
		// 	else {
		// 		if ( currentContent==null ) currentContent = "";
		// 		currentContent += bytes.getString(pos,len);
		// 	}
		// };
		// 
		// // Call "parse_multipart_data" using the callbacks above
		// try {
		// 	#if php
		// 		// Haxe's Web.parseMultipart function can't handle post values that share the same name in a multipart request.
		// 		// We have a Ufront specific workaround, we support multiple values on a parameter, but only 1 level - no recursive PHP associative arrays.
		// 		WebOverride.parseMultipart( doPart, doData );
		// 	#else
		// 		Web.parseMultipart( doPart, doData );
		// 	#end
		// }
		// catch ( e:Dynamic ) {
		// 	var stack = haxe.CallStack.toString( haxe.CallStack.exceptionStack() );
		// 	var err = 'Failed to parse multipart data: $e\n$stack';
		// 	errors.push( err );
		// }
		// 
		// // Finish everything up, check there are no errors, return accordingly.
		// if ( noParts==false ) doEndOfPart();
		// if ( callbackFutures.length>0 ) {
		// 	return Future.ofMany( callbackFutures ).flatMap( function(_) {
		// 		return
		// 			if ( errors.length==0 ) Success(Noise).asFuture()
		// 			else Failure(Error.withData('Error parsing multipart request data', errors)).asFuture();
		// 	});
		// }
		// else 
		return Success(Noise).asFuture();
	}

	override function get_query() {
		if ( query==null )
			query = getMultiValueMapFromString(queryString);
		return query;
	}

	override function get_post() {
		if ( post==null ) {
			if ( httpMethod=="GET" ) {
				post = new MultiValueMap();
			}
			// else if ( isMultipart() ) {
			// 	if ( _parsed==false )
			// 		parseMultipart();
			// }
			else {
				// if( clientHeaders['Content-Type'].startsWith('application/json') )
				// 	request.body.asGoodSurprise()
				post = getMultiValueMapFromString( postString );
			}
		}
		return post;
	}

	override function get_cookies() {
		if ( cookies==null ) {
			cookies = new CaseInsensitiveMultiValueMap();
			var cookieHeader = clientHeaders['Cookie'];
			if( cookieHeader!=null ) {
				for(cookie in cookieHeader.split(';')) {
					var tuple = cookie.ltrim().split('=');
					if(tuple.length < 2) continue;
					cookies.add(tuple[0], tuple[1]);
				}
			}
		}
		return cookies;
	}

	override function get_hostName() {
		if ( hostName==null )
			hostName = clientHeaders['Host'];
		return hostName;
	}

	override function get_clientIP() {
		if ( clientIP==null )
			clientIP = request.clientIp.indexOf('ffff') != -1 ? request.clientIp.split(':').pop() : request.clientIp;
		return clientIP;
	}

	override function get_uri() {
		if ( uri==null )
			uri = '/' + PartialUrl.parse(request.header.uri).segments.join('/').urlDecode();
		return uri;
	}

	override function get_clientHeaders() {
		if ( clientHeaders==null ) {
			clientHeaders = new CaseInsensitiveMultiValueMap();
			for( header in request.header.fields ) {
				// on nodejs, multiple header values of the same name are joined with ", "
				// (see: https://nodejs.org/api/http.html#http_message_headers)
				// we split them and add multiple entries to the MultiValueMap
				#if nodejs for(value in (header.value:String).split(', ')) #end
				clientHeaders.add( header.name, #if nodejs value #else header.value #end );
			}
		}
		return clientHeaders;
	}

	override function get_httpMethod() {
		if ( httpMethod==null ) {
			httpMethod = request.header.method;
			if ( httpMethod==null ) httpMethod = "";
		}
		return httpMethod;
	}

	override function get_scriptDirectory() {
		if ( scriptDirectory==null )
			scriptDirectory = 
				#if (haxe_ver >= 3.3)
					Sys.programPath().directory().addTrailingSlash();
				#elseif nodejs
					js.Node.__dirname.addTrailingSlash();
				#elseif sys
					Sys.getCwd().addTrailingSlash();
				#end
					
		return scriptDirectory;
	}

	override function get_authorization() {
		if ( authorization==null ) {
			var authHeader = clientHeaders['Authorization'];
			if(authHeader == null)
				authorization = { user:null, pass:null };
			else {
				var encoded = authHeader.split(' ')[1];
				var decoded = Base64.decode(encoded).toString().split(':');
				authorization = { user: decoded[0], pass: decoded[1] };
			}
		}
		return authorization;
	}

	static function getMultiValueMapFromString( s:String ):MultiValueMap<String> {
		var map = new MultiValueMap();
		for ( part in s.split("&") ) {
			var index = part.indexOf("=");
			if ( index>0 ) {
				var name = part.substr(0,index);
				var val = part.substr(index+1);
				map.add( name.urlDecode(), val.urlDecode() );
			}
		}
		return map;
	}
}