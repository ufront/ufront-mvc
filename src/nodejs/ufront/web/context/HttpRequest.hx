package nodejs.ufront.web.context;

import haxe.io.Bytes;
import ufront.web.upload.*;
import ufront.web.context.HttpRequest.OnPartCallback;
import ufront.web.context.HttpRequest.OnDataCallback;
import ufront.web.context.HttpRequest.OnEndPartCallback;
import ufront.web.UserAgent;
import ufront.core.*;
import haxe.ds.StringMap;
import ufront.core.AsyncTools;
import ufront.web.HttpError;
using tink.CoreApi;
using StringTools;

/**
An implementation of `ufront.web.context.HttpRequest` for NodeJS, based on `express.Request`.

Platform quirks with `HttpRequest` and NodeJS:

- `clientHeaders` will have all keys in lower case.
- `query`, `post` and `cookies` currently only support one value per name.
- When you have a parameter  named `user.email`, Express JS tries to convert it into a "user" object with a field "email". We undo that, and expose it as "user.email".
- `postString` has not been implemented yet.
- `parseMultipart` has not been implemented yet. Pull requests using https://www.npmjs.com/package/multer are welcome.


@author Franco Ponticelli, Jason O'Neil
**/
class HttpRequest extends ufront.web.context.HttpRequest {
	#if !macro

	var req:express.Request;

	public function new( req:express.Request ) {
		this.req = req;
	}

	override function get_queryString() {
		if ( queryString==null ) {
			queryString = req.originalUrl.substr( req.originalUrl.indexOf("?")+1 );
			var hashIndex = queryString.indexOf("#");
			if ( hashIndex>-1 )
				queryString = queryString.substr( 0,hashIndex+1 );
		}
		return queryString;
	}

	override function get_postString() {
		if ( postString==null ) {
			if ( httpMethod=="GET" )
				postString = "";
			else
				throw HttpError.internalServerError( 'HttpRequest.postString() not implemented on NodeJS' );
		}
		return postString;
	}

	var _parsed:Bool = false;
	// TODO: implement using https://www.npmjs.com/package/multer
	override public function parseMultipart( ?onPart:OnPartCallback, ?onData:OnDataCallback, ?onEndPart:OnEndPartCallback ):Surprise<Noise,Error> {
		if ( !isMultipart() )
			return SurpriseTools.success();

		if (_parsed)
			return throw HttpError.internalServerError('HttpRequest.parseMultipart() can only been called once');

		_parsed = true;

		var post = get_post();
		throw HttpError.internalServerError( 'HttpRequest.parseMultipart() not implemented on NodeJS' );
	}

	override function get_query() {
		if ( query==null )
			query = getMapFromObject( req.query );
		return query;
	}

	override function get_post() {
		if ( post==null )
			post = getMapFromObject( req.body );
		return post;
	}

	override function get_cookies() {
		if ( cookies==null )
			cookies = getMapFromObject( untyped req.headers.cookie );
		return cookies;
	}

	override function get_hostName() {
		if ( hostName==null )
			hostName = req.hostname;
		return hostName;
	}

	override function get_clientIP() {
		if ( clientIP==null )
			clientIP = req.ip;
		return clientIP;
	}

	override function get_uri() {
		if ( uri==null )
			uri = req.path.urlDecode();
		return uri;
	}

	override function get_clientHeaders() {
		if ( clientHeaders==null )
			clientHeaders = cast getMapFromObject( untyped req.headers );
		return clientHeaders;
	}

	override function get_httpMethod() {
		if ( httpMethod==null )
			httpMethod = untyped req.method;
		return httpMethod;
	}

	override function get_scriptDirectory() {
		if ( scriptDirectory==null )
			scriptDirectory = js.Node.__dirname + "/";
		return scriptDirectory;
	}

	override function get_authorization() {
		if ( authorization==null ) {
			authorization = { user:null, pass:null };
			var reg = ~/^Basic ([^=]+)=*$/;
			var h = clientHeaders.get( "Authorization" );
			if( h!=null && reg.match(h) ){
				var val = reg.matched( 1 );
				val = new js.node.Buffer(val, 'base64').toString( "utf-8" );
				var a = val.split(":");
				if( a.length!=2 ){
					throw HttpError.badRequest( "Unable to decode username and password" );
				}
				authorization = {user: a[0],pass: a[1]};
			}
		}
		return authorization;
	}

	static function getMapFromObject( obj:Dynamic, ?prefix:String="", ?caseSensitive:Bool=true, ?m:MultiValueMap<String> ):MultiValueMap<String> {
		if ( m==null )
			m = new MultiValueMap();

		if ( obj!=null ) for ( fieldName in Reflect.fields(obj) ) {
			var val = Reflect.field(obj,fieldName);
			var fieldName = (prefix!="") ? '$prefix.$fieldName' : fieldName;
			var name = (caseSensitive) ? fieldName : fieldName.toLowerCase();
			switch Type.typeof( val ) {
				// TODO: if we have q[]=1&q[]=2, how do we get both values?
				// Perhaps using obj.forEach(), not sure how to do that from Haxe.
				case TObject:
					getMapFromObject( val, name, caseSensitive, m );
				default:
					if(Std.is(val, Array)) for(v in (val:Array<Dynamic>))
						m.add( name, StringTools.urlDecode('$v') );
					else
						m.add( name, name == "__x" ? '$val' : StringTools.urlDecode('$val') );
			}
		}

		return m;
	}

	#end
}
