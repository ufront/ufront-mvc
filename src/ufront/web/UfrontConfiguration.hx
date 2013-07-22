package ufront.web;
import thx.util.Imports;

/**
	Small configuration options that affect a ufront application.

	Used in `ufront.web.UfrontApplication`
**/
class UfrontConfiguration
{
	/** 
		Is mod_rewrite or similar being used?  
		If not, query strings will be filtered out of the URLs 
		Default = false;
	**/
	public var urlRewrite(default, null):Bool;
	
	/** 
		A base path for this app relative to the root of the server.  
		If supplied, this will be filtered from URLs.
		Default = "/" (app is at root of webserver)
	**/
	public var basePath(default, null):String;

	/**
		If specified, then traces are logged to the file specified by this path.
		Default = null; (don't log)
	**/
	public var logFile(default, null):Null<String>;

	/**
		Disable traces going to the browser console?
		Could be useful if you have sensitive information in your traces.
		Default = false;
	**/
	public var disableBrowserTrace(default, null):Bool;

	/**
		Construct a new UfrontConfiguration option with the specified values or defaults.

		Defaults:

		- `urlRewrite = false`
		- `basePath = "/"`
		- `logFile = null`
		- `disableBrowserTrace = false`
	**/
	public function new(?urlRewrite=false, ?basePath="/", ?logFile:String=null, ?disableBrowserTrace=false)
	{
		this.urlRewrite = urlRewrite;
		this.basePath = basePath;
		this.logFile = logFile;
		this.disableBrowserTrace = disableBrowserTrace;
	}
}