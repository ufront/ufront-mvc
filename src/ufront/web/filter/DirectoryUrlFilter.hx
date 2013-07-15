package ufront.web.filter;
import ufront.web.context.HttpRequest;
import thx.error.NullArgument;
import thx.error.Error;
import ufront.web.url.*;

using StringTools;

/**
	URLFilter to add/remove a subdirectory that this app is stored in.

	For example `/myapp/post/123/` becomes `/post/123`
**/
class DirectoryUrlFilter implements IUrlFilter
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