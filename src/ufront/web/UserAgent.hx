package ufront.web;

/**
UserAgent information detected from the version string.

You can access a pre-filled version for the current request using `HttpRequest.userAgent`.

You can parse a User-Agent string (from your HTTP headers or logs) using `UserAgent.fromString`.

This class is fairly outdated, so usefulness may vary.  For example, iOS is listed as a known OS, but Android isn't.

@author Franco Ponticelli

__Pull requests to update this class with modern user agent data are welcome.__
**/
class UserAgent
{
	// Info from: http://www.quirksmode.org/js/detect.html
	static var dataBrowser:Array<{ subString:String, ?versionSearch:String, identity:String }> = [
		{ subString: "Chrome", identity: "Chrome" },
		{ subString: "OmniWeb", versionSearch: "OmniWeb/", identity: "OmniWeb" },
		{ subString: "Apple", identity: "Safari", versionSearch: "Version" },
		{ subString: "Opera", versionSearch: "Version", identity: "Opera" },
		{ subString: "iCab", identity: "iCab" },
		{ subString: "KDE", identity: "Konqueror" },
		{ subString: "Firefox", identity: "Firefox" },
		{ subString: "Camino", identity: "Camino" },
		{ subString: "Netscape", identity: "Netscape" },
		{ subString: "MSIE", identity: "Explorer", versionSearch: "MSIE" },
		{ subString: "Gecko", identity: "Mozilla", versionSearch: "rv" },
		{ subString: "Mozilla", identity: "Netscape", versionSearch: "Mozilla" }
	];

	static var dataOS = [
		{ subString: "Win", identity: "Windows" },
		{ subString: "Mac", identity: "Mac" },
		{ subString: "iPhone", identity: "iPhone/iPod" },
		{ subString: "Linux", identity: "Linux" }
	];

	/** The name of the client's browser. **/
	public var browser(default,null):String;

	/** The version string of the client's browser. **/
	public var version(default,null):String;

	/** The major version of the client's browser. **/
	public var majorVersion(default,null):Int;

	/** The minor version of the client's browser. **/
	public var minorVersion(default,null):Int;

	/** The name of the client's platform / operating system. **/
	public var platform(default,null):String;

	/**
	Create a new UserAgent with the given parameters.

	If you have a User-Agent String, you can use `UserAgent.fromString()` to generate a complete `UserAgent` object.
	**/
	public function new( browser:String, version:String, majorVersion:Int, minorVersion:Int, platform:String ) {
		this.browser = browser;
		this.version = version;
		this.majorVersion = majorVersion;
		this.minorVersion = minorVersion;
		this.platform = platform;
	}

	/**
	Return a String with a summary of the current User-Agent.
	**/
	public function toString() {
		return '$browser v.${majorVersion}.${minorVersion} ($version) on $platform';
	}

	/**
	Parse a User-Agent string into a `UserAgent` object.
	**/
	public static function fromString( s:String ):UserAgent {
		var ua = new UserAgent( "unknown", "", 0, 0, "unknown" );

		var info = searchString( dataBrowser, s );
		if ( info!=null ) {
			ua.browser = info.app;
			var version = extractVersion( info.versionString, s );
			if (null != version) {
				ua.version = version.version;
				ua.majorVersion = version.majorVersion;
				ua.minorVersion = version.minorVersion;
			}
		}
		var info = searchString( dataOS, s );
		if ( info!=null ) {
			ua.platform = info.app;
		}

		return ua;
	}

	static function extractVersion( searchString:String, s:String ) {
		var index = s.indexOf( searchString );
		if ( index<0 )
			return null;
		var re = ~/(\d+)\.(\d+)[^ ();]*/;
		if ( !re.match(s.substr(index+searchString.length+1)) )
			return null;
		return {
			version: re.matched(0),
			majorVersion: Std.parseInt( re.matched(1) ),
			minorVersion: Std.parseInt( re.matched(2) )
		};
	}

	static function searchString( data:Array<Dynamic>, s:String ) {
		for (d in data) {
			if ( s.indexOf(d.subString)>=0 ) {
				return {
					app: d.identity,
					versionString: (d.versionSearch==null) ? d.identity : d.versionSearch
				}
			}
		}
		return null;
	}
}
