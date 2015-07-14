package ufront.view;

#if sys
	import sys.FileSystem;
	import sys.io.File;
#elseif nodejs
	import js.node.Fs;
#end
import haxe.ds.Option;
using ufront.core.AsyncTools;
using tink.CoreApi;
using haxe.io.Path;

/**
A UFViewEngine that loads views from the filesystem on the web server.

This currently only has a synchronous implementation on "sys" platforms.
An implementation for NodeJS would be easy to add - pull requests welcome!
**/
class FileViewEngine extends UFViewEngine {

	public function new() {
		super();
	}

	/** The script directory for your app. This value should be provided by dependency injection (A String named "scriptDirectory"). **/
	@inject("scriptDirectory") public var scriptDir:String;

	/** The path to your views (absolute, or relative to the script directory). This value should be provided by dependency injection (A String named "viewPath"). **/
	@inject("viewPath") public var path:String;

	/** Is `path` absolute (true) or relative to `scriptDir` (false)? This is determined by checking if the injected `viewPath` has a leading "/". **/
	public var isPathAbsolute(get,null):Bool;
	function get_isPathAbsolute():Bool return StringTools.startsWith( path, "/" );

	/**
	The absolute path to your views.
	This is essentially `${scriptDir}${path}/` (or `${path}/` if path is absolute).
	**/
	public var viewDirectory(get,null):String;
	function get_viewDirectory() return isPathAbsolute ? path.addTrailingSlash() : scriptDir.addTrailingSlash()+path.addTrailingSlash();

	/**
	Check if a file exists, and read a file from the file system.

	@param viewRelativePath The relative path to the view. Please note this path is not checked for "../" or similar path hacks, so be wary of using user inputted data here.
	@return A future containing details on if the template existed at the given path or not, or a failure if there was an unexpected error.
	**/
	override public function getTemplateString( viewRelativePath:String ):Surprise<Option<String>,Error> {
		var fullPath = viewDirectory+viewRelativePath;
		#if sys
			try {
				if ( FileSystem.exists(fullPath) ) return Future.sync( Success(Some(File.getContent(fullPath))) );
				else return Future.sync( Success(None) );
			}
			catch ( e:Dynamic ) return e.asSurpriseError( 'Failed to load template $viewRelativePath' );
		#elseif nodejs
			function attemptRead( cb:js.Error->Option<String>->Void ) {
				Fs.readFile( fullPath, { encoding: 'utf-8' }, function(err,data) {
					if ( err!=null && (untyped err.code:String)=="ENOENT" )
						cb( null, None ); // File not found.
					else if ( err!=null )
						cb( err, null ); // System error.
					else
						cb( null, Some(data) ); // The template.
				});
			}
			return attemptRead.asSurprise();
		#else
			var msg = "No implementation for non-sys platforms in FileViewEngine.getTemplateString().";
			return msg.asSurpriseError();
		#end
	}
}
