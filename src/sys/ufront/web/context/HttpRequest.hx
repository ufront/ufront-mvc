package sys.ufront.web.context;

#if neko
	import neko.Web;
#elseif php
	import php.Web;
	import php.NativeArray;
	import php.Lib;
#end
import haxe.io.Bytes;
import ufront.web.upload.*;
import ufront.web.UserAgent;
import ufront.web.HttpError;
import ufront.core.MultiValueMap;
import haxe.ds.StringMap;
import ufront.web.context.HttpRequest.OnPartCallback;
import ufront.web.context.HttpRequest.OnDataCallback;
import ufront.web.context.HttpRequest.OnEndPartCallback;
using ufront.core.AsyncTools;
using tink.CoreApi;
using StringTools;

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
class HttpRequest extends ufront.web.context.HttpRequest {

	public function new() {
		_parsed = false;
	}

	override function get_queryString() {
		if ( queryString==null ) {
			queryString = Web.getParamsString();
			if ( queryString==null )
				queryString = "";

			var indexOfHash = queryString.indexOf("#");
			if ( indexOfHash>-1 ) {
				queryString = queryString.substring( 0, indexOfHash );
			}

			queryString = queryString.urlDecode();
		}
		return queryString;
	}

	override function get_postString() {
		if ( postString==null ) {
			postString = (httpMethod=="GET") ? "" : Web.getPostData();
			if ( postString==null )
				postString = "";
			postString = postString.urlDecode();
		}
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
		if ( !isMultipart() )
			return SurpriseTools.success();

		// Prevent this running more than once.
		if (_parsed)
			throw HttpError.internalServerError( "parseMultipart() has been called more than once." );

		_parsed = true;

		// Default values, prepare for processing
		if ( onPart==null ) onPart = function(_,_) return Success(Noise).asFuture();
		if ( onData==null ) onData = function(_,_,_) return Success(Noise).asFuture();
		if ( onEndPart==null ) onEndPart = function() return Success(Noise).asFuture();

		post = new MultiValueMap();
		var noParts:Bool = true,
		    isFile:Bool = false,
		    partName:String = null,
		    fileName:String = null,
		    currentContent:String = null,
		    callbackFutures = [],
		    errors = [];

		// callbacks for processing data
		function processCallbackResult( surprise:Surprise<Noise,Error> ) {
			callbackFutures.push( surprise );
			surprise.handle( function(outcome) {
				switch outcome {
					case Failure(err): errors.push( err.toString() );
					default:
				}
			});
		}
		function doEndOfPart() {
			if ( isFile ) {
				processCallbackResult( onEndPart() );
			}
			else if ( currentContent!=null ) {
				post.add( partName, currentContent.urlDecode() );
			}
		}
		function doPart( newPartName:String, newPartFilename:String ) {
			doEndOfPart();
			noParts = false;
			currentContent = null;
			partName = newPartName.urlDecode();
			isFile = false;
			if ( newPartFilename!=null && newPartFilename!="" ) {
				fileName = newPartFilename.urlDecode();
				post.add(partName, fileName);
				processCallbackResult( onPart(partName,fileName) );
				isFile = true;
			}
		};
		function doData( bytes:Bytes, pos:Int, len:Int ) {
			if ( isFile ) {
				if (len > 0) processCallbackResult( onData(bytes,pos,len) );
			}
			else {
				if ( currentContent==null ) currentContent = "";
				currentContent += bytes.getString(pos,len);
			}
		};

		// Call "parse_multipart_data" using the callbacks above
		try {
			#if php
				// Haxe's Web.parseMultipart function can't handle post values that share the same name in a multipart request.
				// We have a Ufront specific workaround, we support multiple values on a parameter, but only 1 level - no recursive PHP associative arrays.
				WebOverride.parseMultipart( doPart, doData );
			#else
				Web.parseMultipart( doPart, doData );
			#end
		}
		catch ( e:Dynamic ) {
			var stack = haxe.CallStack.toString( haxe.CallStack.exceptionStack() );
			var err = 'Failed to parse multipart data: $e\n$stack';
			errors.push( err );
		}

		// Finish everything up, check there are no errors, return accordingly.
		if ( noParts==false ) doEndOfPart();
		if ( callbackFutures.length>0 ) {
			return Future.ofMany( callbackFutures ).flatMap( function(_) {
				return
					if ( errors.length==0 ) Success(Noise).asFuture()
					else Failure(Error.withData('Error parsing multipart request data', errors)).asFuture();
			});
		}
		else return Success(Noise).asFuture();
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
			else if ( isMultipart() ) {
				if ( _parsed==false )
					parseMultipart();
			}
			else {
				post = getMultiValueMapFromString( postString );
			}
		}
		return post;
	}

	override function get_cookies() {
		if ( cookies==null ) {
			cookies = MultiValueMap.fromMap( Web.getCookies() );
		}
		return cookies;
	}

	override function get_hostName() {
		if ( hostName==null )
			hostName = Web.getHostName();
		return hostName;
	}

	override function get_clientIP() {
		if ( clientIP==null )
			clientIP = Web.getClientIP();
		return clientIP;
	}

	override function get_uri() {
		if ( uri==null ) {
			uri = Web.getURI();
			#if neko
				// mod_neko has a peculiarity where mod_rewrite still passes "index.n" to the uri parameter, but only if the url is "/".
				if( uri.endsWith("/index.n") )
					uri = uri.substr( 0, uri.lastIndexOf("/")+1 );
				// nekotools also needs a URI decode.
				if (Sys.executablePath().indexOf('nekotools') > -1) {
					uri = uri.urlDecode();
				}
			#elseif php
				// PHP does not decode the URI.
				uri = uri.urlDecode();
			#end
		}
		return uri;
	}

	override function get_clientHeaders() {
		if ( clientHeaders==null ) {
			clientHeaders = new MultiValueMap();
			#if php
				// php.Web.getClientHeaders() uses `$_SERVER`, which mutates the header names. (Uppercased, replace `-` with `_`).
				var headers:StringMap<String> = php.Lib.hashOfAssociativeArray( untyped __php__("apache_request_headers()") );
				for( name in headers.keys() ) {
					for ( val in headers.get(name).split(",") ) {
						clientHeaders.add( name, val.trim() );
					}
				}
			#else
			for ( header in Web.getClientHeaders() ) {
				for ( val in header.value.split(",") ) {
					clientHeaders.add( header.header, val.trim() );
				}
			}
			#end
		}
		return clientHeaders;
	}

	override function get_httpMethod() {
		if ( httpMethod==null ) {
			httpMethod = Web.getMethod();
			if ( httpMethod==null ) httpMethod = "";
		}
		return httpMethod;
	}

	override function get_scriptDirectory() {
		if ( scriptDirectory==null )
			scriptDirectory = Web.getCwd();
		return scriptDirectory;
	}

	override function get_authorization() {
		if ( authorization==null ) {
			authorization = Web.getAuthorization();
			if ( authorization==null )
				authorization = { user:null, pass:null };
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
				map.add( name, val );
			}
		}
		return map;
	}
}

#if php
private class WebOverride {
	/**
		Parse the multipart data. Call `onPart` when a new part is found
		with the part name and the filename if present
		and `onData` when some part data is readed. You can this way
		directly save the data on hard drive in the case of a file upload.
	**/
	public static function parseMultipart( onPart : String -> String -> Void, onData : Bytes -> Int -> Int -> Void ) : Void {
		var a : NativeArray = untyped __var__("_POST");
		if(untyped __call__("get_magic_quotes_gpc"))
			untyped __php__("reset($a); while(list($k, $v) = each($a)) $a[$k] = stripslashes((string)$v)");
		var post = Lib.hashOfAssociativeArray(a);

		for (key in post.keys())
		{
			onPart(key, "");
			var v:Dynamic = post.get(key);
			// Start Ufront Specific: check for an array here, and drill down 1 level only.
			// The original Haxe version only called onData() assuming `v` was a String, which it is not always.
			if (untyped __call__("is_array",v)) {
				var map = Lib.hashOfAssociativeArray(v);
				var first = true;
				for (val in map) {
					if (!first)
						onPart(key, "");
					onData(Bytes.ofString(val), 0, untyped __call__("strlen", val));
					first = false;
				}
			}
			else onData(Bytes.ofString(v), 0, untyped __call__("strlen", v));
			// End Ufront Specific.
		}

		if(!untyped __call__("isset", __php__("$_FILES"))) return;
		var parts : Array<String> = untyped __call__("new _hx_array",__call__("array_keys", __php__("$_FILES")));
		for(part in parts) {
			var info : Dynamic = untyped __php__("$_FILES[$part]");
			var tmp : String = untyped info['tmp_name'];
			var file : String = untyped info['name'];
			var err : Int = untyped info['error'];

			if(err > 0) {
				switch(err) {
					case 1: throw "The uploaded file exceeds the max size of " + untyped __call__('ini_get', 'upload_max_filesize');
					case 2: throw "The uploaded file exceeds the max file size directive specified in the HTML form (max is" + untyped __call__('ini_get', 'post_max_size') + ")";
					case 3: throw "The uploaded file was only partially uploaded";
					case 4: continue; // No file was uploaded
					case 6: throw "Missing a temporary folder";
					case 7: throw "Failed to write file to disk";
					case 8: throw "File upload stopped by extension";
				}
			}
			onPart(part, file);
			if ("" != file)
			{
				var h = untyped __call__("fopen", tmp, "r");
				var bsize = 8192;
				while (!untyped __call__("feof", h)) {
					var buf : String = untyped __call__("fread", h, bsize);
					var size : Int = untyped __call__("strlen", buf);
					onData(Bytes.ofString(buf), 0, size);
				}
				untyped __call__("fclose", h);
			}
		}
	}
}
#end
