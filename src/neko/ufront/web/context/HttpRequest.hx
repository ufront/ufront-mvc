package neko.ufront.web.context;

import haxe.io.Bytes;
import thx.Error;
import neko.Lib;
import ufront.web.upload.*;
import ufront.web.UserAgent;
import ufront.core.MultiValueMap;
import haxe.ds.StringMap;
import ufront.web.context.HttpRequest.OnPartCallback;
import ufront.web.context.HttpRequest.OnDataCallback;
import ufront.web.context.HttpRequest.OnEndPartCallback;
using ufront.core.AsyncTools;
using tink.CoreApi;
using thx.Strings;
using StringTools;

/**
	An implementation of HttpRequest for mod_neko and mod_tora.

	@author Franco Ponticelli, Jason O'Neil
**/
class HttpRequest extends ufront.web.context.HttpRequest
{
	public static function encodeName(s:String)
	{
		return s.urlEncode().replace('.', '%2E');
	}

	public function new()
	{
		_init();
		_parsed = false;
	}

	override function get_queryString()
	{
		if (null == queryString) {
			var v = _get_params_string();
			queryString = (v!=null) ? new String(v).urlDecode() : "";

			var indexOfHash = queryString.indexOf("#");
			if (indexOfHash>-1) {
				queryString = queryString.substring( 0, indexOfHash );
			}
		}
		return queryString;
	}

	override function get_postString()
	{
		if (httpMethod == "GET")
			return "";
		if (null == postString) {
			var v = _get_post_data();
			postString = (v!=null) ? new String(v).urlDecode() : "";
		}
		return postString;
	}

	var _parsed:Bool;

	/**
		parseMultipart implementation method for mod_neko.

		Please see documentation on `ufront.web.context.HttpRequest.parseMultipart` for general information.

		Specific implementation details for neko:

		- This uses the `parse_multipart_data` function from the `mod_neko` NDLL, which is also used by `neko.Web.parseMultipart`.
		- Because of this, `onPart` and `onData` will run synchronously - the moment the callback finishes, the next callback will continue.
		- We suggest on neko you only use callbacks which can run synchronously.
		- `onEndPart` will not be called until all `onPart` and `onData` functions have finished firing.
		-
	**/
	override public function parseMultipart( ?onPart:OnPartCallback, ?onData:OnDataCallback, ?onEndPart:OnEndPartCallback ):Surprise<Noise,Error>
	{
		if ( !isMultipart() )
			return SurpriseTools.success();

		// Prevent this running more than once.
		if (_parsed)
			throw "parseMultipart() has been called more than once.";

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
			// Sys.println( 'PART $partName : FILE $newPartFilename <br />' );
			if ( null!=newPartFilename ) {
				if ( ""!=newPartFilename ) {
					fileName = newPartFilename.urlDecode();
					post.add(partName, fileName);
					processCallbackResult( onPart(partName,fileName) );
					isFile = true;
				}
			}
		};
		function doData( bytes:Bytes, pos:Int, len:Int ) {
			if ( isFile ) {
				// Sys.println( 'Is a file, do something!<br />' );
				if (len > 0) processCallbackResult( onData(bytes,pos,len) );
			}
			else {
				if ( currentContent==null ) currentContent = "";
				currentContent += bytes.getString(pos,len);

				// Sys.println( 'Append content: $currentContent<br />' );
			}
		};

		// Call mod_neko's "parse_multipart_data" using the callbacks above
		try {
			_parse_multipart(
				function(p,f) {
					var partName = new String(p);
					var fileName = if( f == null ) null else new String(f);
					doPart( partName, fileName );
				},
				function(buf,pos,len) {
					var data = untyped new haxe.io.Bytes(__dollar__ssize(buf),buf);
					doData(data,pos,len);
				}
			);
		}
		catch ( e:Dynamic ) {
			var err = 'Failed to parse multipart data: $e';
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

	override function get_query()
	{
		if (null == query)
			query = getMultiValueMapFromString(queryString);
		return query;
	}

	override function get_post()
	{
		if (httpMethod == "GET")
			return new MultiValueMap();
		if ( null==post ) {
			if ( isMultipart() ) {
				if ( _parsed==false ) parseMultipart();
			}
			else {
				post = getMultiValueMapFromString(postString);
			}
		}
		return post;
	}

	override function get_cookies()
	{
		if (null == cookies)
		{
			var p = _get_cookies();
			cookies = new MultiValueMap();
			var k = "";
			while( p != null ) {
				untyped k.__s = p[0];
				cookies.add(k,new String(p[1]));
				p = untyped p[2];
			}
		}
		return cookies;
	}

	override function get_hostName()
	{
		if (null == hostName)
			hostName = new String(_get_host_name());
		return hostName;
	}

	override function get_clientIP()
	{
		if (null == clientIP)
			clientIP = new String(_get_client_ip());
		return clientIP;
	}

	/**
	 *  @todo the page processor removal is quite hackish
	 */
	override function get_uri()
	{
		if (null == uri) {
			uri = new String(_get_uri());
			if(uri.endsWith(".n")) {
				var p = uri.split("/");
				p.pop();
				uri = p.join("/") + "/";
			}
		}
		return uri;
	}

	override function get_clientHeaders()
	{
		if (null == clientHeaders)
		{
			clientHeaders = new StringMap();
			var v = _get_client_headers();
			while( v != null ) {
				var headerName = new String(v[0]);
				var headerValues = new String(v[1]);
				for ( val in headerValues.split(",") ) {
					clientHeaders.add( headerName, val.trim() );
				}
				v = cast v[2];
			}
		}
		return clientHeaders;
	}

	override function get_httpMethod()
	{
		if (null == httpMethod)
		{
			httpMethod = new String(_get_http_method());
			if (null == httpMethod) httpMethod = "";
		}
		return httpMethod;
	}

	override function get_scriptDirectory()
	{
		if (null == scriptDirectory)
		{
			scriptDirectory = new String(_get_cwd());
		}
		return scriptDirectory;
	}

	override function get_authorization() {
		if ( authorization==null ) {
			authorization = { user:null, pass:null };
			var reg = ~/^Basic ([^=]+)=*$/;
			var h = clientHeaders.get( "Authorization" );
			if( h!=null && reg.match(h) ){
				var val = reg.matched( 1 );
				val = untyped new String( _base_decode(val.__s,"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/".__s) );
				var a = val.split(":");
				if( a.length != 2 ){
					throw "Unable to decode authorization.";
				}
				authorization = {user: a[0],pass: a[1]};
			}
		}
		return authorization;
	}

	static function getMultiValueMapFromString(s:String):MultiValueMap<String> {
		var map = new MultiValueMap();
		for (part in s.split("&")) {
			var index = part.indexOf("=");
			if ( index>0 ) {
				var name = part.substr(0,index);
				var val = part.substr(index+1);
				map.add( name, val );
			}
		}
		return map;
	}

	static var _get_params_string:Dynamic;
	static var _get_post_data:Dynamic;
	static var _get_cookies:Dynamic;
	static var _get_host_name:Dynamic;
	static var _get_client_ip:Dynamic;
	static var _get_uri:Dynamic;
	static var _get_client_headers:Dynamic;
	static var _get_cwd:Dynamic;
	static var _get_http_method:Dynamic;
	static var _parse_multipart:Dynamic;
	static var _base_decode = Lib.load("std","base_decode",2);
	static var _inited = false;
	static function _init()
	{
		if(_inited)
			return;
		_inited = true;
		var get_env = Lib.load("std", "get_env", 1);
		var ver = untyped get_env("MOD_NEKO".__s);
		var lib = "mod_neko" + if ( ver == untyped "1".__s ) "" else ver;
		_get_params_string = Lib.load(lib, "get_params_string", 0);
		_get_post_data = Lib.load(lib, "get_post_data", 0);
		_get_cookies = Lib.load(lib, "get_cookies", 0);
		_get_host_name = Lib.load(lib, "get_host_name", 0);
		_get_client_ip = Lib.load(lib, "get_client_ip", 0);
		_get_uri = Lib.load(lib, "get_uri", 0);
		_get_client_headers = Lib.loadLazy(lib, "get_client_headers", 0);
		_get_cwd = Lib.load(lib, "cgi_get_cwd", 0);
		_get_http_method = Lib.loadLazy(lib,"get_http_method",0);
		_parse_multipart = Lib.loadLazy(lib, "parse_multipart_data", 2);
	}
}
