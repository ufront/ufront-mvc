package ufront.web;

import ufront.api.UFApiContext;
import ufront.view.FileViewEngine;
import ufront.view.UFViewEngine;
import ufront.view.TemplatingEngines;
import ufront.web.Controller;
import ufront.api.*;
import ufront.web.session.*;
import ufront.auth.*;
import ufront.web.context.*;
import ufront.module.*;
import ufront.app.UFMiddleware;
import ufront.app.UFErrorHandler;
import ufront.handler.ErrorPageHandler;
import ufront.middleware.InlineSessionMiddleware;
import ufront.web.upload.TmpFileUploadMiddleware;
#if ufront_ufadmin
	import ufront.ufadmin.UFAdminModule;
#end

/**
	Small configuration options that affect a ufront application.

	Used in `ufront.web.UfrontApplication`
**/
typedef UfrontConfiguration = {

	/**
		The index controller that handles standard web requests.

		This controller will handle all requests given to `ufront.handler.MVCHandler`.
		It may use sub-controllers to handle some requests.

		It will be instantiated using the dependency injector for that request.

		Default = `ufront.web.DefaultController`
	**/
	?indexController:Class<Controller>,

	/**
		The `UFApiContext` API to expose with ufront-remoting.

		If null, the remoting module will not be enabled.

		Default = null.
	**/
	?remotingApi:Class<UFApiContext>,

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
		The directory

		This should be specified relative to the script directory (fetched using `HttpRequest.scriptDirectory`).  You can either have it as a subdirectory, (eg "uf-content") or in a parent directory (eg "../uf-content")

		There should not be a leading slash, and a trailing slash is optional.

		Default = "uf-content"
	**/
	?contentDirectory:String,

	/**
		If specified, then traces are logged to the file specified by this path.

		This should be set relative to `contentDirectory`.

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
		Disable traces going to the server console?
		Default = false;
	**/
	?disableServerTrace:Bool,

	/**
		The request middleware to use with this application

		Default is `[ new TmpFileUploadMiddleware(), new InlineSessionMiddleware() ]`
	**/
	?requestMiddleware:Array<UFRequestMiddleware>,

	/**
		The response middleware to use with this application

		Default is `[ new InlineSessionMiddleware(), new TmpFileUploadMiddleware()  ]`
	**/
	?responseMiddleware:Array<UFResponseMiddleware>,

	/**
		The error handlers to use with this application.

		Default is `[ new ErrorPageHandler() ]`.
	**/
	?errorHandlers:Array<UFErrorHandler>,

	/**
		Controllers to add to the Dependency Injector.

		These classes will be added to the `MVCHandler`'s injector.

		Default is a list of all `ufront.web.Controller` classes, fetched using `CompileTime.getAllClasses()`
	**/
	?controllers:Null<Iterable<Class<Controller>>>,

	/**
		APIs to add to the Dependency Injector.

		These classes will be added to the `MVCHandler`'s injector and the `RemotingHandler`'s injector.

		Please note this will not make these APIs available through Ufront Remoting, you must specify a `remotingApi` to make APIs available to remoting calls.

		Default is a list of all `ufront.api.UFApi` classes, fetched using `CompileTime.getAllClasses()`
	**/
	?apis:Null<Iterable<Class<UFApi>>>,

	/**
		ViewEngine to add to the Dependency Injector.

		This engine will be used to load views created using `ufront.web.result.ViewResult`, or other views as you need them.

		Default is `ufront.view.FileViewEngine`, which loads the views from the `viewPath` directory.
	**/
	?viewEngine:Null<Class<UFViewEngine>>,

	/**
		The TemplatingEngines to use, in order of preference.

		The order the templating engines are specified here is the order they are added to the ViewEngine, and the order that views will attempt to be loaded in.

		The default is set from `TemplatingEngines.all`.
	**/
	?templatingEngines:Array<TemplatingEngine>,

	/**
		The path to load the views from.
		The type of path (File system path, HTTP URL etc), will depend on the UFViewEngine used.
		If it is a file path, it should either be absolute (with a leading slash) or relative to the script directory, with no leading slash.
		Default is "view/".
	**/
	?viewPath:Null<String>,

	/**
		The name of the default layout view, relative to your viewPath.
		Default is null, meaning that views will not be wrapped in a layout.
	**/
	?defaultLayout:Null<String>,

	/**
		The class which we should use for saving user session state.

		This class should be able to be setup using the dependency injector for a request.

		By default, this is `ufront.web.session.FileSession`.
	**/
	?sessionImplementation:Class<UFHttpSession>,

	/**
		The class we should use as our authentication handler.

		If using the ufront-easyauth library, the default value is `EasyAuth`.

		If not using ufront-easyauth, the default value is `YesBossAuthHandler`.
	**/
	?authImplementation:Class<UFAuthHandler<UFAuthUser>>,

	#if ufront_ufadmin
		/**
			Modules to use in the UFAdmin control panel.

			If using the ufront-ufadmin library, these modules will show up as menu items in the UFAdmin controller.

			Default is a list of all `ufront.ufadmin.controller.UFAdminModule` classes, fetched using `CompileTime.getAllClasses()`
		**/
		?adminModules:Iterable<Class<UFAdminModule>>,
	#end
}

class DefaultUfrontConfiguration {

	/**
		Fetch a default `UfrontConfiguration`.

		If you do not supply a UfrontConfiguration object to your `UfrontApplication`, or if your object does not specify all the required values, it will use these values as a fallback.

		Defaults for each value are described in the documentation for each field in `UfrontConfiguration`
	**/
	public static function get():UfrontConfiguration {
		var inlineSession = new InlineSessionMiddleware();
		var uploadMiddleware = new TmpFileUploadMiddleware();
		return {
			indexController:DefaultUfrontController,
			remotingApi:null,
			urlRewrite:true,
			basePath:'/',
			contentDirectory:'uf-content',
			logFile:null,
			disableBrowserTrace: false,
			disableServerTrace: false,
			controllers: CompileTime.getAllClasses( Controller ),
			apis: CompileTime.getAllClasses( UFApi ),
			viewEngine: FileViewEngine,
			templatingEngines: TemplatingEngines.all,
			viewPath: "view/",
			defaultLayout: null,
			sessionImplementation: FileSession,
			requestMiddleware: [uploadMiddleware,inlineSession],
			responseMiddleware: [inlineSession,uploadMiddleware],
			errorHandlers: [ new ErrorPageHandler() ],
			authImplementation:
				// TODO: find out if there's a way we can teach Haxe that these type parameters are okay.
				// We only ever *read* a T:UFAuthUser, any time we ask for one to write or check against the interface accepts any UFAuthUser.
				// Because we're read only, we're safe, but Haxe doesn't think so.
				// For now we'll cast our way out of this problem.
				#if (ufront_easyauth && server)
					cast EasyAuth
				#else
					cast YesBossAuthHandler // should we use NobodyAuthHandler instead?
				#end
				,
			#if ufront_ufadmin
				adminModules: CompileTime.getAllClasses( UFAdminModule ),
			#end
		}
	}
}

/**
	A simple controller to use if no other is specified.
**/
class DefaultUfrontController extends ufront.web.Controller {
	@:route( '/*' )
	function showMessage() {
		ufTrace("Your Ufront App is almost ready.");
		return CompileTime.readFile( "ufront/web/DefaultPage.html" );
	}
}
