package ufront;

/**
The `ufront.MVC` module contains typedefs for commonly imported types in the `ufront-mvc` package.

This allows you to use `import ufront.MVC;` or `using ufront.MVC` rather than having dozens of imports in your code.
**/
class MVC {}

// `ufront.api` package.
@:noDoc @:noUsing typedef ApiReturnType = ufront.api.ApiReturnType;
@:noDoc @:noUsing typedef RequireAsyncCallbackApi<T> = ufront.api.RequireAsyncCallbackApi<T>;
@:noDoc @:noUsing typedef UFApi = ufront.api.UFApi;
@:noDoc @:noUsing typedef UFApiClientContext<ServerContext:UFApiContext> = ufront.api.UFApiClientContext<ServerContext>;
@:noDoc @:noUsing typedef UFApiContext = ufront.api.UFApiContext;
@:noDoc @:noUsing typedef UFAsyncApi<SyncApi:UFApi> = ufront.api.UFAsyncApi<SyncApi>;
@:noDoc @:noUsing typedef UFCallbackApi<SyncApi:UFApi> = ufront.api.UFCallbackApi<SyncApi>;

// `ufront.app` package.
#if client
	@:noDoc @:noUsing typedef ClientJsApplication = ufront.app.ClientJsApplication;
#end
@:noDoc @:noUsing typedef HttpApplication = ufront.app.HttpApplication;
@:noDoc @:noUsing typedef UFErrorHandler = ufront.app.UFErrorHandler;
@:noDoc @:noUsing typedef UFInitRequired = ufront.app.UFInitRequired;
@:noDoc @:noUsing typedef UFLogHandler = ufront.app.UFLogHandler;
@:noDoc @:noUsing typedef UFMiddleware = ufront.app.UFMiddleware.UFMiddleware;
@:noDoc @:noUsing typedef UFRequestMiddleware = ufront.app.UFMiddleware.UFRequestMiddleware;
@:noDoc @:noUsing typedef UFResponseMiddleware = ufront.app.UFMiddleware.UFResponseMiddleware;
@:noDoc @:noUsing typedef UFRequestHandler = ufront.app.UFRequestHandler;
@:noDoc @:noUsing typedef UfrontApplication = ufront.app.UfrontApplication;
@:noDoc @:noUsing typedef UfrontClientConfiguration = ufront.app.UfrontClientConfiguration;
@:noDoc @:noUsing typedef UfrontConfiguration = ufront.app.UfrontConfiguration;

// `ufront.auth` package
@:noDoc @:noUsing typedef AuthError = ufront.auth.AuthError;
@:noDoc @:noUsing typedef NobodyAuthHandler = ufront.auth.NobodyAuthHandler;
@:noDoc @:noUsing typedef UFAuthAdapter<T:UFAuthUser> = ufront.auth.UFAuthAdapter.UFAuthAdapter<T>;
@:noDoc @:noUsing typedef UFAuthAdapterSync<T:UFAuthUser> = ufront.auth.UFAuthAdapter.UFAuthAdapterSync<T>;
@:noDoc @:noUsing typedef UFAuthHandler = ufront.auth.UFAuthHandler;
@:noDoc @:noUsing typedef UFAuthUser = ufront.auth.UFAuthUser;
@:noDoc @:noUsing typedef YesBossAuthHandler = ufront.auth.YesBossAuthHandler;

// `ufront.cache` package
#if (ufront_orm && server)
	@:noDoc @:noUsing typedef DBCacheConnection = ufront.cache.DBCache.DBCacheConnection;
	@:noDoc @:noUsing typedef DBCache = ufront.cache.DBCache.DBCache;
	@:noDoc @:noUsing typedef DBCacheItem = ufront.cache.DBCache.DBCacheItem;
	@:noDoc @:noUsing typedef DBCacheApi = ufront.cache.DBCache.DBCacheApi;
	#if (ufront_uftasks)
		@:noDoc @:noUsing typedef DBCacheTasks = ufront.cache.DBCache.DBCacheTasks;
	#end
#end
@:noDoc @:noUsing typedef MemoryCacheConnection = ufront.cache.MemoryCache.MemoryCacheConnection;
@:noDoc @:noUsing typedef MemoryCache = ufront.cache.MemoryCache.MemoryCache;
@:noDoc @:noUsing typedef RequestCacheMiddleware = ufront.cache.RequestCacheMiddleware;
@:noDoc @:noUsing typedef UFCacheConnection = ufront.cache.UFCache.UFCacheConnection;
@:noDoc @:noUsing typedef UFCacheConnectionSync = ufront.cache.UFCache.UFCacheConnectionSync;
@:noDoc @:noUsing typedef UFCache = ufront.cache.UFCache.UFCache;
@:noDoc @:noUsing typedef UFCacheSync = ufront.cache.UFCache.UFCacheSync;
@:noDoc @:noUsing typedef CacheError = ufront.cache.UFCache.CacheError;

// `ufront.core` package
@:noDoc @:noUsing typedef AcceptEither<A,B> = ufront.core.AcceptEither<A,B>;
@:noDoc @:noUsing typedef InjectionTools = ufront.core.InjectionTools;
@:noDoc @:noUsing typedef FutureTools = ufront.core.AsyncTools.FutureTools;
@:noDoc @:noUsing typedef SurpriseTools = ufront.core.AsyncTools.SurpriseTools;
@:noDoc @:noUsing typedef CallbackTools = ufront.core.AsyncTools.CallbackTools;
@:noDoc @:noUsing typedef Futuristic<T> = ufront.core.Futuristic<T>;
@:noDoc @:noUsing typedef MultiValueMap<T> = ufront.core.MultiValueMap<T>;
@:noDoc @:noUsing typedef OrderedStringMap<T> = ufront.core.OrderedStringMap<T>;
@:noDoc @:noUsing typedef Uuid = ufront.core.Uuid;

// `ufront.handler` package
@:noDoc @:noUsing typedef ErrorPageHandler = ufront.handler.ErrorPageHandler;
@:noDoc @:noUsing typedef MVCHandler = ufront.handler.MVCHandler;
@:noDoc @:noUsing typedef RemotingHandler = ufront.handler.RemotingHandler;

// `ufront.log` package
@:noDoc @:noUsing typedef BrowserConsoleLogger = ufront.log.BrowserConsoleLogger;
@:noDoc @:noUsing typedef FileLogger = ufront.log.FileLogger;
@:noDoc @:noUsing typedef Message = ufront.log.Message.Message;
@:noDoc @:noUsing typedef MessageType = ufront.log.Message.MessageType;
@:noDoc @:noUsing typedef MessageList = ufront.log.MessageList;
@:noDoc @:noUsing typedef OriginalTraceLogger = ufront.log.OriginalTraceLogger;
@:noDoc @:noUsing typedef RemotingLogger = ufront.log.RemotingLogger;
@:noDoc @:noUsing typedef ServerConsoleLogger = ufront.log.ServerConsoleLogger;

// `ufront.remoting` package
@:noDoc @:noUsing typedef HttpAsyncConnection = ufront.remoting.HttpAsyncConnection;
@:noDoc @:noUsing typedef HttpConnection = ufront.remoting.HttpConnection;
@:noDoc @:noUsing typedef RemotingError<FailureType> = ufront.remoting.RemotingError<FailureType>;
@:noDoc @:noUsing typedef RemotingUtil = ufront.remoting.RemotingUtil;

// `ufront.test` package
@:noDoc @:noUsing typedef TestUtils = ufront.test.TestUtils.TestUtils;
@:noDoc @:noUsing typedef NaturalLanguageTests = ufront.test.TestUtils.NaturalLanguageTests;
@:noDoc @:noUsing typedef RequestTestContext = ufront.test.TestUtils.RequestTestContext;
#if mockatoo
	@:noDoc @:noUsing typedef Mockatoo = ufront.test.TestUtils.TMockatoo;
#end

// `ufront.view` package
@:noDoc @:noUsing typedef FileViewEngine = ufront.view.FileViewEngine;
@:noDoc @:noUsing typedef HttpViewEngine = ufront.view.HttpViewEngine;
@:noDoc @:noUsing typedef TemplateData = ufront.view.TemplateData;
@:noDoc @:noUsing typedef TemplatingEngines = ufront.view.TemplatingEngines.TemplatingEngines;
@:noDoc @:noUsing typedef TemplatingEngine = ufront.view.TemplatingEngines.TemplatingEngine;
@:noDoc @:noUsing typedef UFTemplate = ufront.view.UFTemplate;
@:noDoc @:noUsing typedef UFViewEngine = ufront.view.UFViewEngine;

// `ufront.web.context` package
@:noDoc @:noUsing typedef ActionContext = ufront.web.context.ActionContext;
@:noDoc @:noUsing typedef HttpContext = ufront.web.context.HttpContext.HttpContext;
@:noDoc @:noUsing typedef RequestCompletion = ufront.web.context.HttpContext.RequestCompletion;
@:noDoc @:noUsing typedef HttpRequest = ufront.web.context.HttpRequest.HttpRequest;
@:noDoc @:noUsing typedef OnPartCallback = ufront.web.context.HttpRequest.OnPartCallback;
@:noDoc @:noUsing typedef OnDataCallback = ufront.web.context.HttpRequest.OnDataCallback;
@:noDoc @:noUsing typedef OnEndPartCallback = ufront.web.context.HttpRequest.OnEndPartCallback;
@:noDoc @:noUsing typedef HttpResponse = ufront.web.context.HttpResponse;

// `ufront.web.result` package
@:noDoc @:noUsing typedef ActionResult = ufront.web.result.ActionResult.ActionResult;
@:noDoc @:noUsing typedef ActionOutcome = ufront.web.result.ActionResult.ActionOutcome;
@:noDoc @:noUsing typedef FutureActionResult = ufront.web.result.ActionResult.FutureActionResult;
@:noDoc @:noUsing typedef FutureActionOutcome = ufront.web.result.ActionResult.FutureActionOutcome;
@:noDoc @:noUsing typedef BytesResult = ufront.web.result.BytesResult;
@:noDoc @:noUsing typedef ContentResult = ufront.web.result.ContentResult;
#if detox
	@:noDoc @:noUsing typedef DetoxResult<T:dtx.widget.Widget> = ufront.web.result.DetoxResult<T>;
#end
@:noDoc @:noUsing typedef DirectFilePathResult = ufront.web.result.DirectFilePathResult;
@:noDoc @:noUsing typedef EmptyResult = ufront.web.result.EmptyResult;
@:noDoc @:noUsing typedef FilePathResult = ufront.web.result.FilePathResult;
@:noDoc @:noUsing typedef FileResult = ufront.web.result.FileResult;
@:noDoc @:noUsing typedef HttpAuthResult = ufront.web.result.HttpAuthResult;
@:noDoc @:noUsing typedef JsonResult<T> = ufront.web.result.JsonResult<T>;
@:noDoc @:noUsing typedef RedirectResult = ufront.web.result.RedirectResult;
@:noDoc @:noUsing typedef ViewResult = ufront.web.result.ViewResult;

// `ufront.web.session` package
@:noDoc @:noUsing typedef CacheSession = ufront.web.session.CacheSession;
@:noDoc @:noUsing typedef FileSession = ufront.web.session.FileSession;
@:noDoc @:noUsing typedef InlineSessionMiddleware = ufront.web.session.InlineSessionMiddleware;
@:noDoc @:noUsing typedef TestSession = ufront.web.session.TestSession;
@:noDoc @:noUsing typedef UFHttpSession = ufront.web.session.UFHttpSession;
@:noDoc @:noUsing typedef VoidSession = ufront.web.session.VoidSession;

// `ufront.web.upload` package
@:noDoc @:noUsing typedef TmpFileUpload = ufront.web.upload.TmpFileUpload;
@:noDoc @:noUsing typedef TmpFileUploadMiddleware = ufront.web.upload.TmpFileUploadMiddleware;
@:noDoc @:noUsing typedef UFFileUpload = ufront.web.upload.UFFileUpload;

// `ufront.web.url` package
@:noDoc @:noUsing typedef PartialUrl = ufront.web.url.PartialUrl;
@:noDoc @:noUsing typedef VirtualUrl = ufront.web.url.VirtualUrl;

// `ufront.web.url.filter` package
@:noDoc @:noUsing typedef DirectoryUrlFilter = ufront.web.url.filter.DirectoryUrlFilter;
@:noDoc @:noUsing typedef PathInfoUrlFilter = ufront.web.url.filter.PathInfoUrlFilter;
@:noDoc @:noUsing typedef QueryStringUrlFilter = ufront.web.url.filter.QueryStringUrlFilter;
@:noDoc @:noUsing typedef UFUrlFilter = ufront.web.url.filter.UFUrlFilter;

// `ufront.web` package
@:noDoc @:noUsing typedef Controller = ufront.web.Controller;
@:noDoc @:noUsing typedef HttpCookie = ufront.web.HttpCookie;
@:noDoc @:noUsing typedef HttpError = ufront.web.HttpError;
@:noDoc @:noUsing typedef UserAgent = ufront.web.UserAgent;
