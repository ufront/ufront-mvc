package ufront.view;

#if sys
	import sys.FileSystem;
	import sys.io.File;
#end
import haxe.ds.Option;
using tink.CoreApi;
using haxe.io.Path;

/**
	A UFViewEngine that loads views from the filesystem on the web server.

	This currently only has a synchronous implementation on "sys" platforms.
**/
class FileViewEngine extends UFViewEngine {
	
	/** The script directory for your app. This value should be injected. **/
	@inject("scriptDirectory") public var scriptDir:String;

	/** The path to your views (absolute, or relative to the script directory). This value should be injected. **/
	@inject("viewPath") public var path(default,null):String;

	/** Is `path` absolute (true) or relative to `scriptDir` (false)? This value is set in the constructor. **/
	public var isPathAbsolute(get,null):Bool;

	/** The absolute path to your views.  Basically `$scriptDir$path/` (or `$path/` if path is absolute). **/
	public var viewDirectory(get,null):String;
	function get_viewDirectory() return isPathAbsolute ? path.addTrailingSlash() : scriptDir+path.addTrailingSlash();

	/**
		Check if a file exists, and read a file from the file system using the synchronous `sys.FileSystem` api from the standard library.

		A pull request for a NodeJS asynchronous implementation is invited.

		@param viewRelativePath The relative path to the view. Please note this path is not checked for "../" or similar path hacks, so be wary of using user inputted data here.
		@return A future (resolved synchronously) containing details on if the template existed at the given path or not, or a failure if there was an unexpected error.
	**/
	override public function getTemplateString( viewRelativePath:String ):Surprise<Option<String>,Error> {
		var fullPath = viewDirectory+viewRelativePath;
		try {
			#if sys
				if ( FileSystem.exists(fullPath) ) return Future.sync( Success(Some(File.getContent(fullPath))) );
				else return Future.sync( Success(None) );
			#else
				throw "No implementation for non-sys platforms in FileViewEngine.getTemplateString().";
			#end
		}
		catch ( e:Dynamic ) return Future.sync( Failure(Error.withData('Failed to load template $viewRelativePath', e)) );
	}

	function get_isPathAbsolute():Bool {
		return StringTools.startsWith( path, "/" );
	}
}
