package ufront.web.url.filter;
import ufront.web.context.HttpRequest;
import thx.error.Error;     

using StringTools;

/**
	URLFilter to add/remove a front script from the URL segments.

	To be used if URL rewriting is not being used but PathInfo is.

	For example `index.n/some/path/` becomes `/some/path/`
**/
class PathInfoUrlFilter implements UFUrlFilter
{
	public var frontScript(default, null) : String;  
	public var useCleanRoot(default, null) : Bool;

	/**
	Construct a new Filter based on the given frontScript name

	@param frontScript Front script to ignore Default is "index.php" or "index.n", or error on other platforms..
	@param useCleanRoot Unsure, please ask Franco :)  Default=true
	**/
	public function new(?frontScript : String, useCleanRoot = true) {
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
		this.useCleanRoot = useCleanRoot;
	} 
	
	/** Remove frontScript from front of URL segments **/
	public function filterIn(url : PartialUrl, request : HttpRequest) {
		if(url.segments[0] == frontScript) 
			url.segments.shift();
	} 
	
	/** Add frontScript to URL segments **/
	public function filterOut(url : VirtualUrl, request : HttpRequest) {
		if(url.isPhysical || (url.segments.length == 0 && useCleanRoot)) 
			{} 
		else 
			url.segments.unshift(frontScript);
	}
}