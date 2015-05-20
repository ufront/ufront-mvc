package ufront.web.url.filter;

import ufront.web.context.HttpRequest;
using StringTools;

/**
A `UFUrlFilter` to add or remove a subdirectory that this app is located in on the web server.

For example if your app is stored in `/personal/blog/`, this would filter URLs between a normalized state for the app (`/posts/3/`) and the raw state of the webserver (`/personal/blog/posts/3/`)
**/
class DirectoryUrlFilter implements UFUrlFilter {

	/** The directory that you wish to filter (usually, the path the app is running from relative to the web server root). **/
	public var directory(default,null):String;

	var segments:Array<String>;

	/** Construct a new filter for the given directory **/
	public function new( directory:String ) {
		if ( directory.startsWith("/") )
			directory = directory.substr( 1, directory.length );
		if ( directory.endsWith("/") )
			directory = directory.substr( 0, directory.length-1 );
		this.directory = directory;
		this.segments = (directory!="") ? directory.split( "/" ) : [];
	}

	/** Remove the subdirectory from a `PartialUrl` **/
	public function filterIn( url:PartialUrl ) {
		var pos = 0;
		while ( url.segments.length>0 && url.segments[0]==segments[pos++] )
			url.segments.shift();
	}

	/** Add the subdirectory to a `VirtualUrl` **/
	public function filterOut( url:VirtualUrl ) {
		url.segments = segments.concat( url.segments );
	}
}
