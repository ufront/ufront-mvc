package ufront.web.url.filter;

import ufront.web.context.HttpRequest;
using StringTools;

/**
A `UFUrlFilter` to add or remove a front script (such as `index.php`) from the URL segments.

To be used if URL rewriting is not being used, but the web server is passing a `PATH_INFO` environment variable to our script.

For example this would filter URLs between a normalized state of `index.n/some/path/` and a clean state of `/some/path/`.
**/
class PathInfoUrlFilter implements UFUrlFilter {
	/** The name of the script file to filter. Defaults to `index.n` on Neko or `index.php` on PHP. **/
	public var frontScript(default,null):String;

	/** If the URI is for the application root, should we use "index.php" (`false`) or "" (`true`). Default is `true`. **/
	public var useCleanRoot(default,null):Bool;

	/**
	Construct a new Filter based on the given `frontScript` name.

	@param frontScript (optional) Set the `frontScript`, otherwise use the default for the platform.
	@param useCleanRoot (optional) Set the value for `useCleanRoot`. The default value is `true`.
	**/
	public function new( ?frontScript:String, ?useCleanRoot=true ) {
		if( frontScript==null )
			frontScript =
				#if php "index.php"
				#elseif neko "index.n"
				#else throw "Target not implemented, always pass a value for frontScript."
				#end
			;
		this.frontScript = frontScript;
		this.useCleanRoot = useCleanRoot;
	}

	/** Remove `this.frontScript` from front of URL segments. **/
	public function filterIn( url:PartialUrl ) {
		if( url.segments[0]==frontScript )
			url.segments.shift();
	}

	/** Add `this.frontScript` to URL segments. **/
	public function filterOut( url:VirtualUrl ) {
		if( url.isPhysical || (url.segments.length==0 && useCleanRoot) ) {
			//
		}
		else {
			url.segments.unshift( frontScript );
		}
	}
}
