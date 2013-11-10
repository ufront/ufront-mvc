package ufront.view;

class FileViewEngine extends UFViewEngine {
	
	/** The content directory for your app.  This value should be injected. **/
	@inject("contentDirectory") public var contentDir(default,null):String;

	/** The relative path to your views inside the content directory.  This value is set in the constructor. **/
	public var path(default,null):String;

	/** The absolute path to your views.  Basically `contentDir+path+'/'` **/
	public var viewDirectory(get,null):String;
	function get_viewDirectory() return contentDir+path+'/';

	/**
		@param path - path (relative to your content-directory) where your views are stored.  Default is "views"
		@param ?cachingEnabled - (default is true)
	**/
	public function new( ?path="views", ?cachingEnabled=true ) {
		super();
		this.path = path;
	}
}