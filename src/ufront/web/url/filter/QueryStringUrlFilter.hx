package ufront.web.url.filter;

import ufront.web.context.HttpRequest;
using StringTools;

/**
A `UFUrlFilter` to add or remove a front script and query parameter from the URL segments.

To be used if neither URL rewriting nor `PathInfo` is being used, but rather simple parameters.

For example this would filter URLs between a normalized state of `index.n?q=/some/path/` and a clean state of `/some/path/`.
**/
class QueryStringUrlFilter implements UFUrlFilter {
	/** The name of the script file to filter. Defaults to `index.n` on Neko or `index.php` on PHP. **/
	public var frontScript(default,null):String;

	/** Parameter name that stores the path. Default is `q`, as in `index.php?q=/some/path/`. **/
	public var paramName(default,null):String;

	/** If the URI is for the application root, should we use "index.php" (`false`) or "" (`true`). Default is `true`. **/
	public var useCleanRoot(default,null):Bool;

	/**
	Construct a new Filter based on the given frontScript name and parameter name

	@param paramName (optional) Set the `paramName`. Otherwise use the default ("q").
	@param frontScript (optional) Set the `frontScript`, otherwise use the default for the platform.
	@param useCleanRoot (optional) Set the value for `useCleanRoot`. The default value is `true`.
	**/
	public function new( ?paramName:String="q", ?frontScript:String, ?useCleanRoot=true ) {
		if( frontScript==null )
			frontScript =
				#if php "index.php"
				#elseif neko "index.n"
				#else throw HttpError.internalServerError( "Target not implemented, always pass a value for frontScript" )
				#end
			;
		this.frontScript = frontScript;
		this.paramName = paramName;
		this.useCleanRoot = useCleanRoot;
	}

	/** Remove `this.frontScript` and `this.paramName` from the URL. **/
	public function filterIn( url:PartialUrl ) {
		if( url.segments[0]==frontScript ) {
			var param = Lambda.find(url.query, function(p) return p.name==paramName);
			if ( param!=null ) {
				var value = (param.encoded) ? StringTools.urlDecode( param.value ) : param.value;
				url.segments = PartialUrl.parse( param.value ).segments;
				url.query.remove( param );
			}
		}
	}

	/** Add `this.frontScript` and `this.paramName` to the URL. **/
	public function filterOut( url:VirtualUrl ) {
		if( url.isPhysical || (url.segments.length==0 && useCleanRoot) ) {
			//
		}
		else {
			var path = "/" + url.segments.join( "/" );
			url.segments = [frontScript];
			url.query.push({ name:paramName, value:path, encoded: true });
		}
	}
}
