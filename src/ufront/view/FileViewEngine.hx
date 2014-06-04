package ufront.view;

#if sys
	import sys.FileSystem;
	import sys.io.File;
#end
import haxe.ds.Option;
using tink.CoreApi;
using haxe.io.Path;

class FileViewEngine extends UFViewEngine {
	
	/** The content directory for your app.  This value should be injected. **/
	@inject("scriptDirectory") public var scriptDir:String;

	/** The relative path to your views inside the content directory.  This value is set in the constructor. **/
	public var path(default,null):String;

	/** The absolute path to your views.  Basically `scriptDir+path+'/'` **/
	public var viewDirectory(get,null):String;
	function get_viewDirectory() return scriptDir+path.addTrailingSlash();

	/**
		@param path - path (relative to your content-directory) where your views are stored.  Default is "view"
		@param ?cachingEnabled - (default is true)
	**/
	public function new( ?path="view", ?cachingEnabled=true ) {
		super(cachingEnabled);
		this.path = path;
	}

	#if sys
		/**
			Check if a file exists, and read a file from the file system using the synchronous `sys.FileSystem` api from the standard library.
		**/
		override public function getTemplateString( path:String ):Surprise<Option<String>,Error> {
			var fullPath = viewDirectory+path;
			try {
				if ( FileSystem.exists(fullPath) ) return Future.sync( Success(Some(File.getContent(fullPath))) );
				else return Future.sync( Success(None) );
			}
			catch ( e:Dynamic ) return Future.sync( Failure(Error.withData('Failed to load template $path', e)) );
		}
	#end
}
