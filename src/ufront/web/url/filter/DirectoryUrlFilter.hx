package ufront.web.url.filter;
import ufront.web.context.HttpRequest;
import thx.error.NullArgument;
import thx.error.Error;     

using StringTools;

/**
	URLFilter to add/remove a subdirectory that this app is stored in.

	For example `/myappdir/posts/3/` becomes `/posts/3/`
**/
class DirectoryUrlFilter implements UFUrlFilter
{
	/** The directory that is being filtered **/
	public var directory(default, null) : String;
	
	var segments : Array<String>;

	/**
		Construct a new filter for the given directory
	**/
	public function new(directory : String) {
		if(directory.endsWith("/"))
			directory = directory.substr(0, directory.length-1);
		this.directory = directory;
		this.segments = directory.split("/");
	} 
	
	/**
		Remove the subdirectory from a PartialUrl
	**/
	public function filterIn(url : PartialUrl, request : HttpRequest) {
		var pos = 0;
		while (url.segments.length > 0 && url.segments[0] == segments[pos++])
			url.segments.shift();
	}
	
	/**
		Add the subdirectory to a partial URL
	**/
	public function filterOut(url : VirtualUrl, request : HttpRequest) {
		url.segments = segments.concat(url.segments);
	}
}