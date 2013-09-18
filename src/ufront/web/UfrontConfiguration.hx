package ufront.web;

import ufront.web.Controller;
import ufront.remoting.*;
import ufront.web.session.*;
import ufront.auth.*;
import haxe.web.Dispatch.DispatchConfig;
import ufront.web.context.*;
import ufront.module.*;

/**
	Small configuration options that affect a ufront application.

	Used in `ufront.web.UfrontApplication`
**/
typedef UfrontConfiguration = {
	/**
		The `DispatchConfig` representing your routes.

		Fetch by using `dispatchConf = ufront.web.Dispatch.make( new MyRoutes() )`
		
		The default value is a catch-all controller that informs you that you need to add a dispatchConf.
	**/
	?dispatchConf:DispatchConfig,

	/**
		The `RemotingApiContext` to share via remoting.

		Please note this should be the class, not an instance of the class.

		If this is null, no remoting module will be initiated.

		Default is null.
	**/
	?remotingContext:Null<Class<RemotingApiContext>>,

	/** 
		Is mod_rewrite or similar being used?  
		If not, query strings will be filtered out of the URLs.
		Default = true;
	**/
	?urlRewrite:Bool,
	
	/** 
		A base path for this app relative to the root of the server.  
		If supplied, this will be filtered from URLs.
		Default = "/" (app is at root of webserver)
	**/
	?basePath:String,
	
	/**
		If specified, then traces are logged to the file specified by this path.
		Default = null; (don't log)
	**/
	?logFile:Null<String>,
	
	/**
		Disable traces going to the browser console?
		Could be useful if you have sensitive information in your traces.
		Default = false;
	**/
	?disableBrowserTrace:Bool,

	/**
		Controllers to add to the Dependency Injector.

		Default is a list of all `ufront.web.Controller` classes, fetched using `CompileTime.getAllClasses()`
	**/
	?controllers:Null<Iterable<Class<Controller>>>,
	
	/**
		APIs to add to the Dependency Injector.

		Default is a list of all `ufront.remoting.RemotingApiClass` classes, fetched using `CompileTime.getAllClasses()`
	**/
	?apis:Null<Iterable<Class<RemotingApiClass>>>,

	/**
		An error module to use for the application.

		Default is a basic instance of `ufront.module.ErrorModule`
	**/
	?errorModule:IHttpModule,

	/**
		A method which can be used to generate a session for the current request, as required.

		By default, this is `FileSession.create.bind(_, "sessions", null, 0)`

		This means using `ufront.web.session.FileSession`, saving to the "sessions" folder, with a default session variable name, and an expiry of 0 (when window closed)
	**/
	?sessionFactory:HttpContext->IHttpSessionState,

	/**
		A method which can be used to generate an AuthHandler for the current request, as required.

		By default, this is `EasyAuth.create.bind(_,null)`

		This means it will create an `ufront.auth.EasyAuth` handler using the current session, and the default variable name to store the ID in the session.
	**/
	?authFactory:HttpContext->IAuthHandler<IAuthUser>
}

class DefaultUfrontConfiguration {

	static var _defaultRoutes = new DefaultRoutes();
	
	/**
		Fetch a default `UfrontConfiguration`.

		The values here are as explained in the documentation for each field of `UfrontConfiguration`.

		If you do not supply a UfrontConfiguration object to your `UfrontApplication`, or if your object does not specify all the required values, it will use these values as a fallback.
	**/
	public static function get():UfrontConfiguration {
		return {
			dispatchConf: Dispatch.make( _defaultRoutes ),
			remotingContext: null,
			urlRewrite:true,
			basePath:'/',
			logFile:null,
			disableBrowserTrace: false,
			controllers: cast CompileTime.getAllClasses( Controller ),
			apis: cast CompileTime.getAllClasses( RemotingApiClass ),
			errorModule: new ErrorModule(),
			sessionFactory: FileSession.create.bind(_, "sessions", null, 0),
			authFactory: 
				#if ufront_easyauth cast EasyAuth.create.bind(_,null)
				#else YesBossAuthHandler.create #end
		}
	}
}

class DefaultRoutes extends ufront.web.Controller {
	static var _emptyUfrontString = CompileTime.readFile( "ufront/web/DefaultPage.html" );
	function doDefault( d:Dispatch ) {
		ufTrace("Your Ufront App is almost ready.");
		return _emptyUfrontString;
	}
}