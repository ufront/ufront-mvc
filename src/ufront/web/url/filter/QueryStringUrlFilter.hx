package ufront.web.url.filter;
import ufront.web.context.HttpRequest;
import thx.Error;

using StringTools;

/**
	URLFilter to add/remove a front script and query parameter from the URL segments.

	To be used if neither URL rewriting nor PathInfo is being used, but rather simple parameters.

	For example `index.n?q=/some/path/` becomes `/some/path/`
**/
class QueryStringUrlFilter implements UFUrlFilter
{
	public var frontScript(default, null) : String;
	public var paramName(default, null) : String;
	public var useCleanRoot(default, null) : Bool;

	/**
	Construct a new Filter based on the given frontScript name and parameter name

	@param paramName Parameter name to check for. Default="q".
	@param frontScript Front script to ignore. Default "index.php" or "index.n", or error on other platforms.
	@param useCleanRoot Unsure, please ask Franco :)  Default=true
	**/
	public function new(paramName = "q", ?frontScript : String, useCleanRoot = true)
	{
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

	/** Remove frontScript and query param from URL **/
	public function filterIn(url : PartialUrl, request : HttpRequest) {
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

	/** Add frontScript and query param to URL **/
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
