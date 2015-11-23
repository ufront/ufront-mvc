package ufront.app;

import ufront.api.UFApiContext;
import ufront.view.HttpViewEngine;
import ufront.view.UFViewEngine;
import ufront.view.TemplatingEngines;
import ufront.web.Controller;
import ufront.api.*;
import ufront.web.session.*;
import ufront.auth.*;
import ufront.web.context.*;
import ufront.web.client.UFClientAction;
import ufront.module.*;
import ufront.app.UFMiddleware;
import ufront.app.UFErrorHandler;
import ufront.web.ErrorPageHandler;
#if pushstate
	import ufront.web.upload.BrowserFileUploadMiddleware;
#end

/**
Configuration options for setting up a `ClientJsApplication`.

See also `DefaultUfrontClientConfiguration` for fetching an object with the default configuration options.
**/
typedef UfrontClientConfiguration = {

	/**
	The index controller that is used by `MVCHandler` to handle standard web requests.

	This controller will be created using dependency injection, and executed by `MVCHandler`.
	It will return a response either from one of it's own actions, or by executing a sub controller.

	If not supplied, the default value is `DefaultUfrontController`.
	**/
	@:optional public var indexController:Class<Controller>;

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
	The URL to use for remoting requests.

	Should be treated as a URL, eg `"/"`, `"rel/path/"`, `"/abs/path/"` or `"http://example.com/"`.

	If set to `null`, no remoting connection classes will be injected.

	If not supplied, the default value is `"/"` (the root of the current domain).
	**/
	@:optional public var remotingPath:String;

	/**
	Whether or not traces should be hidden from the client's browser console.

	If not supplied, the default value is `false` (traces will be sent to the browser console).
	**/
	@:optional public var disableBrowserTrace:Bool;

	/**
	The request middleware to use with this application.

	If not supplied, the default value is `[]`.
	**/
	@:optional public var requestMiddleware:Array<UFRequestMiddleware>;

	/**
	The response middleware to use with this application.

	If not supplied, the default value is `[]`.
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
	`UFAsyncApi` versions of these API proxies will also be injected.

	On the client these API classes are proxy classes that will use remoting to call the APIs on the server.

	Please note if the APIs are not made available for remoting, (using `UfrontConfiguration.remotingApi`), then the proxy APIs used here will not function.

	If not supplied, the default list will include all `ufront.api.UFApi` classes, fetched using `CompileTime.getAllClasses()`.
	**/
	@:optional public var apis:Null<Iterable<Class<UFApi>>>;

	/**
	Client Actions to add to the Dependency Injector.

	These classes will be added to the application injector, mapped as singletons.

	If not supplied, the default list will include all `UFClientAction` classes, fetched using `CompileTime.getAllClasses()`.
	**/
	@:optional public var clientActions:Null<Iterable<Class<UFClientAction<Dynamic>>>>;

	/**
	ViewEngine to add to the Dependency Injector.

	This engine will be used to load views created using `ufront.web.result.ViewResult`, or other views as you need them.

	If not supplied, the default view engine is `ufront.view.HttpViewEngine`, which loads the views over HTTP using the `viewPath` base URL.
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

	If not supplied, the default path is `"/view/"`.
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

	If not supplied, the default session implementation will be `ufront.web.session.VoidSession`.
	**/
	@:optional public var sessionImplementation:Class<UFHttpSession>;

	/**
	The class we should use as our authentication handler.

	The auth handler will be set using dependenc injection for each request.

	If not supplied, the default value will be `YesBossAuthHandler`.
	This may change in future once `EasyAuth` has better client-side support.
	**/
	@:optional public var authImplementation:Class<UFAuthHandler>;
}

class DefaultUfrontClientConfiguration {

	/**
		Fetch a default `UfrontClientConfiguration`.

		If you do not supply a UfrontClientConfiguration object to your `ClientJsApplication`, or if your object does not specify all the required values, it will use these values as a fallback.

		Defaults for each value are described in the documentation for each field in `UfrontConfiguration`
	**/
	public static function get():UfrontClientConfiguration {
		return {
			indexController:ufront.app.UfrontConfiguration.DefaultUfrontController,
			urlRewrite:true,
			basePath:'/',
			remotingPath:'/',
			disableBrowserTrace: false,
			controllers: CompileTime.getAllClasses( Controller ),
			apis: CompileTime.getAllClasses( UFApi ),
			clientActions: CompileTime.getAllClasses( UFClientAction ),
			viewEngine: HttpViewEngine,
			templatingEngines: TemplatingEngines.all,
			viewPath: "/view/",
			defaultLayout: null,
			sessionImplementation: VoidSession,
			requestMiddleware: [
				#if pushstate new BrowserFileUploadMiddleware(), #end
			],
			responseMiddleware: [],
			errorHandlers: [ new ErrorPageHandler() ],
			authImplementation:
				// TODO: find out if there's a way we can teach Haxe that these type parameters are okay.
				// We only ever *read* a T:UFAuthUser, any time we ask for one to write or check against the interface accepts any UFAuthUser.
				// Because we're read only, we're safe, but Haxe doesn't think so.
				// For now we'll cast our way out of this problem.
				cast YesBossAuthHandler,
		}
	}
}
