package ufront.web.filter;
import ufront.web.context.HttpRequest;
import thx.error.Error;
import ufront.web.url.*;
using StringTools;

/**
	URLFilter to add/remove path info from the URL.

	To be used when URL rewriting is disabled, but path info is available.

	For example `/index.php/post/123/` becomes `/post/123`
**/
class PathInfoUrlFilter implements IUrlFilter
{
	/** The name of the front script to filter out **/
	public var frontScript(default, null) : String;  
	
	/** If the path is "/", should we still show the frontScript? **/
	public var useCleanRoot(default, null) : Bool;

	/**
		Construct a new filter with the given options.

		@param frontScript default is "index.php", "index.n".  Other platforms will throw an error
		@param useCleanRoot default=true
	**/
	public function new(?frontScript : String, useCleanRoot = true)
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
		this.useCleanRoot = useCleanRoot;
	}
	
	/** Remove the frontScript from the URL **/
	public function filterIn(url : PartialUrl, request : HttpRequest)
	{
		if(url.segments[0] == frontScript)
			url.segments.shift();
	}
	
	/** Add the frontScript to the URL (unless this is a physical URL, or we are on the root path "/" and cleanRoot is true) **/
	public function filterOut(url : VirtualUrl, request : HttpRequest)
	{
		if(url.isPhysical || (url.segments.length == 0 && useCleanRoot)) 
		{
			//
		}
		else
			url.segments.unshift(frontScript);                                                                      
	}
}