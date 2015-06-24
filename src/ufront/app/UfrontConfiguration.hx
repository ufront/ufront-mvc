package ufront.app;

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
import ufront.web.session.InlineSessionMiddleware;
import ufront.web.upload.TmpFileUploadMiddleware;
#if ufront_ufadmin
	import ufront.ufadmin.UFAdminModule;
#end

/**
	Configuration options for setting up a `UfrontApplication`.

	See also `DefaultUfrontConfiguration` for fetching an object with the default configuration options.
**/
typedef UfrontConfiguration = {

	/**
	The index controller that is used by `MVCHandler` to handle standard web requests.

	This controller will be created using dependency injection, and executed by `MVCHandler`.
	It will return a response either from one of it's own actions, or by executing a sub controller.

	If not supplied, the default value is `DefaultUfrontController`.
	**/
	@:optional public var indexController:Class<Controller>;

	/**
	The `UFApiContext` API to expose with remoting in our `RemotingHandler`.

	If not supplied, the default value is `null`, meaning the remoting module will not be enabled.
	**/
	@:optional public var remotingApi:Class<UFApiContext>;

	/**
	Is a URL rewriting scheme, such as Apache's `mod_rewrite` being used?

	If not, query strings will be used when filtering URLs with `HttpContext.getRequestUri()` and creating URLs with `HttpContext.generateUri()`.

	If not supplied, the default value is `true`.
	**/
	@:optional public var urlRewrite:Bool;

	/**
	A base path for this app relative to the root of the web server.

	If supplied, the base path will be used when filtering URLs with `HttpContext.getRequestUri()` and creating URLs with `HttpContext.generateUri()`.

	If not supplied, the default value is `"/"` (meaning the app is in the root directory of the webserver).
	**/
	@:optional public var basePath:String;

	/**
	The path to the "content directory" - a web server writeable directory that can be used for storing sessions, uploads, temp files and more.

	This should be specified relative to the script directory (See `HttpRequest.scriptDirectory`).
	There should not be a leading slash, and a trailing slash is optional.

	If your `contentDirectory` is used to store sensitive information, like session data, please make sure it is not visible to the public over the web.
	This can be controlled by setting the "contentDirectory" to not be a child of the "scriptDirectory" (using "../uf-content" instead of "uf-content"), or by configuring your web server to disallow access.

	On Apache this can be achieved with a simple **".htaccess"** file, placed in the content directory:

	```
	# Block all HTTP access to this folder in Apache
	deny from all
	```

	If not supplied, the default value is `"../uf-content"`.
	**/
	@:optional public var contentDirectory:String;

	/**
	The path to a plain text log file for logging application messages.

	This should be set relative to `this.contentDirectory`, so `"logs/app.log"` will write to `"../uf-content/logs/app.log"`.

	If null, no log file will be used.

	If a value is not supplied, the default value is `null` (meaning no log file will be used).
	**/
	@:optional public var logFile:Null<String>;

	/**
	Whether or not traces should be hidden from the client's browser console.

	If not supplied, the default value is `false` (traces will be sent to the browser console).
	**/
	@:optional public var disableBrowserTrace:Bool;

	/**
	Whether or not traces should be hidden from the server's console (using `Web.logMessage` on Neko, and `console.log` on NodeJS).

	If not supplied, the default value is `false` (traces will be sent to the server console).
	**/
	@:optional public var disableServerTrace:Bool;

	/**
	The request middleware to use with this application.

	If not supplied, the default value is `[ new TmpFileUploadMiddleware(), new InlineSessionMiddleware() ]`.
	**/
	@:optional public var requestMiddleware:Array<UFRequestMiddleware>;

	/**
	The response middleware to use with this application.

	If not supplied, the default value is `[ new InlineSessionMiddleware(), new TmpFileUploadMiddleware()  ]`.
	**/
	@:optional public var responseMiddleware:Array<UFResponseMiddleware>;

	/**
	The error handlers to use with this application.

	If not supplied, the default value is `[ new ErrorPageHandler() ]`.
	**/
	@:optional public var errorHandlers:Array<UFErrorHandler>;

	/**
	Controllers to add to the dependency injector.

	These classes will be added to the request injector in `MVCHandler`, and can then be used as sub controllers.

	If not supplied, the default list will include all `ufront.web.Controller` classes, fetched using `CompileTime.getAllClasses()`.
	**/
	@:optional public var controllers:Null<Iterable<Class<Controller>>>;

	/**
	APIs to add to the Dependency Injector.

	These classes will be added to the request injector in `MVCHandler` and `RemotingHandler`, and then be available to controllers and other APIs.
	`UFAsyncApi` versions of these APIs will also be injected.

	Please note this will not make these APIs available through Ufront Remoting, you must specify a `remotingApi` to make APIs available to remoting calls.

	If not supplied, the default list will include all `ufront.api.UFApi` classes, fetched using `CompileTime.getAllClasses()`.
	**/
	@:optional public var apis:Null<Iterable<Class<UFApi>>>;

	/**
	ViewEngine to add to the Dependency Injector.

	This engine will be used to load views created using `ufront.web.result.ViewResult`, or other views as you need them.

	If not supplied, the default view engine is `ufront.view.HttpViewEngine`, which loads the views from the `viewPath` directory.
	**/
	@:optional public var viewEngine:Null<Class<UFViewEngine>>;

	/**
	The TemplatingEngines to use, in order of preference.

	The order the templating engines are specified here is the order they are added to the ViewEngine, and the order that views will attempt to be loaded in.

	If not supplied, the default list will be set from `TemplatingEngines.all`.
	**/
	@:optional public var templatingEngines:Array<TemplatingEngine>;

	/**
	The path to load the views from.

	The type of path (File system path, HTTP URL etc), will depend on the `UFViewEngine` specified in `this.viewEngine`.

	If it is a file path, it should either be absolute (with a leading slash) or relative to the script directory, with no leading slash.

	If not supplied, the default path is `"view/"`.
	**/
	@:optional public var viewPath:Null<String>;

	/**
	The name of the default view layout, relative to your viewPath.

	The view at this path will be used as a "layout", to wrap your other views in a site-wide template.
	See `ViewResult` for more details.

	If not supplied, the default value is `null`, meaning that views will not be wrapped in a layout.
	**/
	@:optional public var defaultLayout:Null<String>;

	/**
	The `UFHttpSession` implementation we should use for saving user session state.

	The session state will be set up using dependency injection for each request.

	If not supplied, the default session implementation will be `ufront.web.session.FileSession`.
	**/
	@:optional public var sessionImplementation:Class<UFHttpSession>;

	/**
	The class we should use as our authentication handler.

	The auth handler will be set using dependenc injection for each request.

	If not supplied, the default value will depend on if you are using the `ufront-easyauth` library or not.
	If you are using the `ufront-easyauth` library (and not on NodeJS), the default value is `EasyAuth`.
	Otherwise, the default value is `YesBossAuthHandler`.
	**/
	@:optional public var authImplementation:Class<UFAuthHandler>;

	#if ufront_ufadmin
		/**
		Modules to use in the UFAdmin control panel.

		If using the `ufront-ufadmin` library, these modules will show up as menu items in the UFAdmin controller.

		If not supplied, the default list will include all `ufront.ufadmin.controller.UFAdminModule` classes, fetched using `CompileTime.getAllClasses()`.
		**/
		@:optional public var adminModules:Iterable<Class<UFAdminModule>>;
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
			contentDirectory:'../uf-content',
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
				#if (ufront_easyauth && server && !nodejs)
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

It shows a simple page that describes the configuration needed to set `UfrontConfiguration.indexController`.
**/
class DefaultUfrontController extends ufront.web.Controller {
	@:route( '/*' )
	function showMessage() {
		ufTrace("Your Ufront App is almost ready.");
		return CompileTime.readFile( "ufront/web/DefaultPage.html" );
	}
}
