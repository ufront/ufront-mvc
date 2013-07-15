package ufront.web.filter;
import ufront.web.context.HttpRequest;
import thx.error.Error;
import ufront.web.url.*;

using StringTools;

/**
	URLFilter to add/remove a query string from the URL.

	To be used when URL rewriting is disabled, but path info is available.

	For example `/index.php?q=/post/123/` becomes `/post/123`
**/
class QueryStringUrlFilter implements IUrlFilter
{
	/** The name of the front script to filter out **/
	public var frontScript(default, null) : String;

	/** The name of the parameter containing the rest of the URL **/
	public var paramName(default, null) : String; 
	
	/** If the path is "/", should we still show the frontScript? **/
	public var useCleanRoot(default, null) : Bool;
	
	/**
		Construct a filter with the given options

		@param paramName default="q"
		@param frontScript default is "index.php", "index.n", or throw an error for other platforms.
		@param useCleanRoot default=true
	**/
	public function new(paramName = "q", ?frontScript : String, useCleanRoot = true) {
		if(null == frontScript)
			frontScript = 
				#if php 
					"index.php" 
				#elseif neko 
					"index.n" 
				#else 
					throw new Error("target not implemented, always pass a value for frontScript") 
				#end
			;
		this.frontScript = frontScript; 
		this.paramName = paramName;
		this.useCleanRoot = useCleanRoot;
	} 
	
	public function filterIn(url : PartialUrl, request : HttpRequest)
	{
		if(url.segments[0] == frontScript) {
			var params = request.query;
			var u = params.get(paramName);
			if(null == u)
				url.segments = [];
			else {
				url.segments = PartialUrl.parse(u).segments;
				params.remove(paramName);
			}
		}
	}
	
	public function filterOut(url : VirtualUrl, request : HttpRequest) {
		if(url.isPhysical || (url.segments.length == 0 && useCleanRoot)) {
			//
		} 
		else {
			var path = "/" + url.segments.join("/");
			url.segments = [frontScript];
			url.query.set(paramName, { value : path, encoded : true });
		}
	}
}