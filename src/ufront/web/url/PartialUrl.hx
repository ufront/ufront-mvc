package ufront.web.url;

/**
A `PartialUrl` is an object representing a URL, but including only the path, the querystring (following a `?`), and the segment (following a `#`).
It does not include the protocol, the domain name, the port, or any inline authentication.

It is used by Ufront to filter URLs received from the web server, into a normalized format which the app can use for routing etc.

The related `VirtualUrl` is used for the reverse operation: transforming a normalized URL from the app into a raw path recognisable by the web server.
**/
class PartialUrl {
	/** The segments in the URL path, separated by a `/`. **/
	public var segments:Array<String>;

	/** The parts of the query string, following a `?` character. **/
	public var query:Array<{ name:String, value:String, encoded:Bool }>;

	/** The fragment or anchor link, which follows a `#` character. **/
	public var fragment:String;

	/**
	Create an empty `PartialUrl` object.
	See `PartialUrl.parse()` for iniating a URL from a `String`.
	**/
	function new() {
		segments = [];
		query    = [];
		fragment = null;
	}

	/** Parse a URL into a `PartialUrl` object. **/
	public static function parse(url:String):PartialUrl {
		var u = new PartialUrl();
		feed( u, url );
		return u;
	}

	/** Process a URL string and feed it into the given `PartialUrl` object. **/
	static function feed(u:PartialUrl, url:String) {
		var parts = url.split( "#" );
		if( parts.length>1 )
			u.fragment = parts[1];
		parts = parts[0].split( "?" );
		if( parts.length>1 ) {
			var pairs = parts[1].split( "&" );
			for( s in pairs ) {
				var pair = s.split( "=" );
				u.query.push({ name:pair[0], value:pair[1], encoded:true });
			}
		}
		var segments = parts[0].split( "/" );
		if( segments[0]=="" )
			segments.shift();
		if( segments.length==1 && segments[0]=="" )
			segments.pop();
		u.segments = segments;
	}

	/** Print the current `query` into a query string, being sure to encode any values correctly. **/
	public function queryString():String {
		var params = [];
		for( param in query ) {
			var value = (param.encoded) ? param.value : StringTools.urlEncode( param.value );
			params.push( param.name+'='+value );
		}
		return params.join( "&" );
	}

	/** Print the current URL as a string, including path, querystring and fragment. **/
	public function toString():String {
		var url = "/" + segments.join( "/" );
		var qs = queryString();
		if( qs.length>0 )
			url += "?" + qs;
		if( null!=fragment )
			url += "#" + fragment;
		return url;
	}
}
