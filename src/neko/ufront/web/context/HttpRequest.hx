package neko.ufront.web.context;

/**
 * ...
 * @author Franco Ponticelli
 */

import haxe.io.Bytes;
import thx.error.Error;
import thx.sys.Lib;
import ufront.web.upload.*;
import ufront.web.UserAgent;
import ufront.core.MultiValueMap;
import haxe.ds.StringMap;
import ufront.web.context.HttpRequest.OnPartCallback;
import ufront.web.context.HttpRequest.OnDataCallback;
import ufront.web.context.HttpRequest.OnEndPartCallback;
import ufront.core.Sync;
using tink.CoreApi;
using Strings;
using StringTools;

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
			queryString = (v!=null) ? new String(v):null;
			if( v == null )
				queryString = null;
			else
				queryString = new String(v);
			if (null == queryString)
				queryString = "";
		}
		return queryString;
	}
	
	override function get_postString()
	{
		if (httpMethod == "GET")
			return "";
		if (null == postString) {
			var v = _get_post_data();
			if( v == null )
				postString = null;
			else
				postString = new String(v);
			if (null == postString)
				postString = "";
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
		// Prevent this running more than once.
		if (_parsed) return throw new Error('parseMultipart() can only been called once');
		_parsed = true;

		// Default values, prepare for processing
		if ( onPart==null ) onPart = function(_,_) return Sync.of( Success(Noise) );
		if ( onData==null ) onData = function(_,_,_) return Sync.of( Success(Noise) );
		if ( onEndPart==null ) onEndPart = function() return Sync.of( Success(Noise) );
		var post = get_post(),
		    noParts = true,
		    isFile = false, 
		    partName = null,
		    fileName = null,
		    lastWasFile = false,
		    currentContent = null,
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
			if ( lastWasFile ) processCallbackResult( onEndPart() );
			else if ( currentContent!=null ) post.add( partName, currentContent );
		}
		function doPart( partName:String, fileName:String ) {
			doEndOfPart();
			noParts = false;
			isFile = null!=fileName && ""!=fileName;
			currentContent = null;
			partName = partName.urlDecode();
			if (isFile) {
				post.add(partName, fileName);
				processCallbackResult( onPart(partName,fileName) );
				lastWasFile = true;
			} else {
				lastWasFile = false;
			}
		};
		function doData( bytes:Bytes, pos:Int, len:Int ) {
			if ( isFile ) {
				if (len > 0) processCallbackResult( onData(bytes,pos,len) );
			}
			else {
				if ( currentContent==null ) currentContent = "";
				currentContent += bytes.readString(pos,len);
			}
		};

		// Call mod_neko's "parse_multipart_data" using the callbacks above
		try {
			_parse_multipart(
				function(p,f) { doPart(new String(p),if( f == null ) null else new String(f)); },
				function(buf,pos,len) { doData(new haxe.io.Bytes(untyped __dollar__ssize(buf),buf),pos,len); }
			);
		}
		catch ( e:Dynamic ) errors.push( 'Failed to run _parse_multipart: $e' );

		// Finish everything up, check there are no errors, return accordingly.
		if ( noParts==false ) doEndOfPart();
		if ( callbackFutures.length>0 ) {
			return Future.ofMany( callbackFutures ).flatMap( function(_) {
				return
					if ( errors.length==0 ) Sync.of( Success(Noise) )
					else Sync.of( Failure(Error.withData('Error parsing multipart request data', errors)) );
			});
		}
		else return Sync.of( Success(Noise) );
	}
	
	override function get_query()
	{
		if (null == query)
			query = getHashFromString(queryString);
		return query;
	}
	
	override function get_userAgent()
	{
		if (null == userAgent)
			userAgent = UserAgent.fromString(clientHeaders.get("User-Agent"));
		return userAgent;
	}
	
	override function get_post()
	{
		if (httpMethod == "GET")
			return new MultiValueMap();
		if (null == post)
		{
			post = getHashFromString(postString);
			if ( Lambda.empty(post) && _parsed==false )
				parseMultipart();
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
				clientHeaders.add(new String(v[0]), new String(v[1]));
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
	
	override function get_authorization()
	{
		if (null == authorization)
		{
			authorization = { user:null, pass:null };
			var h = clientHeaders.get("Authorization");
			var reg = ~/^Basic ([^=]+)=*$/;
			if( h != null && reg.match(h) ){
				var val = reg.matched(1);
				untyped val = new String(_base_decode(val.__s,"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/".__s));
				var a = val.split(":");
				if( a.length != 2 ){
					throw new Error("Unable to decode authorization.");
				}
				authorization.user = a[0];
				authorization.pass = a[1];
			}
		}
		return authorization;
	}
	
	static var paramPattern = ~/^([^=]+)=(.*?)$/;
	static function getHashFromString(s:String):MultiValueMap<String>
	{
		var qm = new MultiValueMap();
		for (part in s.split("&"))
		{
			if (!paramPattern.match(part))
				continue;
			qm.add(
				StringTools.urlDecode(paramPattern.matched(1)),
				StringTools.urlDecode(paramPattern.matched(2)));
		}
		return qm;
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