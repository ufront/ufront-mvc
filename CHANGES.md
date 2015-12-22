Next release
============

- __New:__ On Client JS, we've added `HttpRequest.reloadScripts( ?doc, ?elm )` to reload all scripts with the `uf-reload` tag.
- __New:__ We've added [CaseInsensitiveMultiValueMap][], and are now using that for `HttpRequest.clientHeaders`.
- __Improved:__ On Client JS, both `HttpRequest` and `PartialViewResult` now reload all `uf-reload` scripts by default.
- __Fixed:__ [CallJavascriptResult][] now functions correctly on the client side.
- __Fixed:__ [Issue 44][] - remoting APIs in a package named `api` failed to compile because of a naming conflict. Thanks @kevinresol for the workaround.
- __Fixed:__ [Issue 45][] - remoting calls always used Multipart HTTP requests, which failed on NodeJS.

[CallJavascriptResult]: http://api.ufront.net/ufront/web/result/CallJavascriptResult.html
[CaseInsensitiveMultiValueMap]: http://api.ufront.net/ufront/core/CaseInsensitiveMultiValueMap.html
[Issue 44]: https://github.com/ufront/ufront-mvc/issues/44
[Issue 45]: https://github.com/ufront/ufront-mvc/issues/45

1.1.0
=====

#### Improved platform consistency:

- __Improved:__ the [Platform test][] repo that helps check platform consistency.
- __Now consistent:__ `queryString` and `postString` are left URL encoded.
- __Now consistent:__ `query` and `post` values are URL decoded correctly across PHP, Nekotools, GET requests, POST requests, Multipart requests and more.
- __Now consistent:__ POST, GET and COOKIE parameter names are now URL decoded correctly.
- __Now consistent:__ `uri` is now URL decoded corretly.
- __Fixed:__ multipart upload handling on PHP when using multiple post values with the same name.

[Platform test]: https://github.com/ufront/mvc-platform-test/

#### Client Actions

- __New:__ The new [UFClientAction][] class can be used to build Javascript actions that are triggered on the client.
    - When a UFClientAction is executed it has access to the current HttpContext, and so can use any remoting APIs, dependency injection, etc.
- __New:__ [AddClientActionResult][] can be used to trigger a [UFClientAction][] to run once a page has loaded. These can be triggered from the client or the server, and will run seamlessly on the client.
- __New:__ You can trigger a [UFClientAction][] directly from [ClientJsApplication][]:
    - `jsApp.executeAction( action, ?data )`
    - `ufExecuteAction( action, ?data )`
    - `ufExecuteSerializedAction( action, ?serializedData )`

[UFClientAction]: http://api.ufront.net/ufront/web/client/UFClientAction.html
[AddClientActionResult]: http://api.ufront.net/ufront/web/result/AddClientActionResult.html
[ClientJsApplication]: http://api.ufront.net/ufront/app/ClientJsApplication.html

#### Improved ViewResult support for helpers and partials

- __New:__ [TemplateHelper][] abstract to describe template helpers and store information about how many arguments they expect.
- __New:__ [UFTemplate][] functions can now be either take either of the following forms:
    - `function execute(data:TemplateData):String`
    - `function execute(data:TemplateData, helpers:StringMap<TemplateHelper>):String`
- Support helpers in [ViewResult][]
    - __New:__ `addHelper(name,helper)` and `addHelpers(map)` methods.
    - __New:__ `static var globalHelpers:Map<String,TemplateHelper>`
    - __Improved:__ `executeResult()` now passes through both `helpers` and `globalHelpers` to the templates.
    - __Improved (breaking):__ `ViewResult.helpers` is now a `Map<String,TemplateHelper>` rather than a `TemplateData`. Given helpers did not actually work before, we decided to allow this breaking change.
- Support partials in [ViewResult][]
    - Partials can load any template file from your [UFViewEngine][].
    - Partials are called in the same way as helpers for your given templating engine.
    - __New:__ `addPartial(name,file)` and `addPartials(map)` methods.
    - __New:__ `addPartialString(name,tpl)` and `addPartialStrings(map)` methods.
    - __New:__ `var partials:Map<String,TemplateSource>`
    - __New:__ `static var globalPartials:Map<String,TemplateSource>`
- __New:__ Add `ViewResult.renderResult()` for rendering a layout and view outside of a normal HttpContext - for example, when sending a HTML email.

[TemplateHelper]: http://api.ufront.net/ufront/view/TemplateHelper.html
[UFTemplate]: http://api.ufront.net/ufront/view/UFTemplate.html
[ViewResult]: http://api.ufront.net/ufront/web/result/ViewResult.html
[UFViewEngine]: http://api.ufront.net/ufront/view/UFViewEngine.html


#### Virtual URLs

- __New__: Added [ActionResult.transformUri()][transformUri].
- __New__: Added [ContentResult.replaceVirtualLinks()][replaceVirtualLinks].
- __Improved:__ Start processing Virtual URLs (those beginning with `~/`) in common ActionResults:
    - `ContentResult` will now replace URLs found in any text/html result.
    - `ViewResult` will now replace URLs found in any text/html result.
    - `DetoxResult` will now replace URLs found in `src`, `href` or `action` attributes.
    - `RedirectResult`
- __Improved:__ [Controller.baseUri][baseUri] now uses a Virtual URL (meaning it always begins with `~/`).

[replaceVirtualLinks]: http://api.ufront.net/ufront/web/result/ContentResult.html#replaceVirtualLinks
[transformUri]: http://api.ufront.net/ufront/web/result/ActionResult.html#transformUri
[baseUri]: http://api.ufront.net/ufront/web/Controller.html#baseUri

#### Uploads

- __New:__ Added [BrowserFileUpload][] for handling file uploads on the client with [File][] and [FileReader][] Javascript APIs.
- __New:__ Support uploads seemlessly in client-side `HttpRequest.uploads` with the new PushState and [BrowserFileUploadMiddleware][].
- __New:__ Upload files during a HTTP remoting API call.
    - APIs that take a `UFFileUpload` object will be called using a `multipart/form-data` HTTP request that attaches the file.
    - [RemotingSerializer][] and [RemotingUnserializer][] will be used to attach and retrieve uploads as part of the remoting call.
    - __New:__ The new [BaseUpload][] class is used by both [TmpFileUpload][] and [BrowserFileUpload][] to make sure that these uploads can be sent over remoting calls safely.
- __Improved:__ Changes to the [UFFileUpload][] interface:
    - New `upload.contentType` property.
    - Calls to `upload.getString()` can now optionally specify the encoding to use.
    - These are not supported on every platform.
- __Fixed:__ `TmpFileUpload.process()` now respects asynchronous processing functions.
- __Fixed:__ [TmpFileUploadMiddleware][] no longer logs errors for failing to delete files that were already deleted in previous requests.

[TmpFileUpload]: http://api.ufront.net/ufront/web/upload/TmpFileUpload.html
[BrowserFileUpload]: http://api.ufront.net/ufront/web/upload/BrowserFileUpload.html
[TmpFileUploadMiddleware]: http://api.ufront.net/ufront/web/upload/TmpFileUploadMiddleware.html
[BrowserFileUploadMiddleware]: http://api.ufront.net/ufront/web/upload/BrowserFileUploadMiddleware.html
[File]: http://api.haxe.org/js/html/File.html
[FileReader]: http://api.haxe.org/js/html/FileReader.html
[UFFileUpload]: http://api.ufront.net/ufront/web/upload/UFFileUpload.html
[BaseUpload]: http://api.ufront.net/ufront/web/upload/BaseUpload.html
[RemotingSerializer]: http://api.ufront.net/ufront/remoting/RemotingSerializer.html
[RemotingUnserializer]: http://api.ufront.net/ufront/remoting/RemotingUnserializer.html

#### Small additions:

- __New:__ Add [TemplatingEngines.erazorHtml][erazorHtml] (escapes HTML by default, and uses the `raw()` helper to allow an unescaped value).
- __New:__ Add [HttpSession.isReady()][isReady].
- __New:__ Add [WrappedResult][] interface for results that wrap an existing type, like `CallJavascriptResult` - making it easier for unit tests to differentiate the real result type from a wrapped result.
- __New:__ Add [TestUtils.saveHtmlOutput()][saveHtmlOutput] for saving HTML output of a page during unit tests, so that you can, for example, render a screen-shot.
- __New:__ Script tags that have a "uf-reload" attribute (`<script uf-reload>`) will be re-executed on each client-side page load, rather than only being executed on the first page.
- __New:__ Add `-D UF_MODULE_DEBUG` flag for logging which modules are run in which order. Useful for debugging middleware issues.

[erazorHtml]: http://api.ufront.net/ufront/view/TemplatingEngines.html#erazorHtml
[isReady]: http://api.ufront.net/ufront/web/session/UFHttpSession.html#isReady
[WrappedResult]: http://api.uf.dev/ufront/web/result/WrappedResult.html
[saveHtmlOutput]: http://api.uf.dev/ufront/test/TestUtils.html#saveHtmlOutput

#### Small improvements

- __Improved:__ Add charset in header for 'application/json' responses.
- __Improved:__ Give better error messages when `args:{}` parameters cannot be parsed in your controllers.
- __Improved__: Allow `TemplateData` to work with class instances.  A resulting implementation change is that casting from an anonymous object now results in copying the object, rather than using the object directly.
- __Improved__: Less confusing error message when a `UFAsyncApi` returns a Failure.
- __Improved:__ Add `showStack` option to `ErrorPageHandler`.
- __Improved:__ Give a more obvious message when the remoting call could not be understood.
- __Improved:__ Try prevent `ApiMacros` and `ControllerMacros` from reporting incorrect compiler error positions.
- __Improved:__ Set `Controller.baseUri` as part of dependency injection, rather than at the start of `execute()`. This allows you to access `baseUri` during a `@post` injection method, which can be useful for setting `ViewResult.globalValues` etc.
- __Improved:__ The default auth handler on `UfrontClientConfiguration` is now `NobodyAuthHandler`, which is safer than the previous `YesBossAuthHandler` default.
- __Improved:__ `PartialViewResult` will now create a new node for each partial, and allow time for the old node to transition out of view using CSS transitions.  The incoming node will have the `uf-partial-incoming` class and the outgoing node will have the `uf-partial-outgoing` class. You can use a `data-uf-transition-timeout` attribute or `PartialViewResult.transitionTimeout` to ensure the old node has time to transition out correctly.
- __Improved:__ Use `EasyAuthClient` (and the associated middleware) by default in `UfrontClientConfiguration` if you are using the `ufront-easyauth` haxelib.

#### Bug fixes

- [Fix remoting with classes that are submodules](https://github.com/ufront/ufront-mvc/issues/29)
- [Bug fix for APIs which return an alias of Outcome,Future or Surprise](https://github.com/ufront/ufront-mvc/commit/611e0c4b708aa5e43db002a6a5e0b7279dde5007)
- Ensure that `PartialViewResult` falls back to `HttpResponse.flush()` correctly if the layout has changed.
- __Fixed__: PHP `TemplateData.setObject()` not working with function values.
- __Fixed__: Working with checkboxes as controller args: if the parameter is not found, it only means it was not checked, not that the parameter was missing.
- __Fixed:__ Catch errors when checking for getting `HttpContext.sessionID` and `HttpContext.currentUserID` as these can be loaded after error handlers have already run.
- __Fixed:__ Avoid use of `Fs.exists` on NodeJS, as it is deprecated.

#### Dependency Updates

- [compiletime:2.6.0](http://lib.haxe.org/p/compiletime/2.6.0/)
- [minject:2.0.0-rc.1](http://lib.haxe.org/p/minject/2.0.0-rc.1/)
- [tink_core:1.0.0-rc.11](http://lib.haxe.org/p/tink_core/1.0.0-rc.11/)
- [tink_macro:0.6.4](http://lib.haxe.org/p/tink_macro/0.6.4/)

---

1.0.1
=====

- Use `uf-` prefix for `PartialViewResult`. So it's now `[data-uf-partial]` and `[data-uf-layout]` and `.uf-partial-loading`.
  A quick patch release to correct this behaviour before it begins getting used.

---

1.0.0
=====

This is a 1.0.0 release of ufront-mvc - Hoorah!

This has been a long time coming, after splitting the `ufront` repo into several smaller repos in 2013, this is the first stable release of Ufront MVC.
We intend to maintain API compatibility as much as possible going forward, until a 2.0.0 is justified.

As such, this release includes a number of breaking changes from the last `1.0.0-rc.17` release, which we've done now so that we can have a more stable API going forward.


### General

- Major API documentation - see http://api.ufront.net/
- Add a `ufront.MVC` module that is a shortcut for all of our import types in ufront-mvc.
- Remove `SysUtil` until we come up with a better solution that will also work with NodeJS.
- Fix issue of Controller and ActionContext bleeding into the macro context, and slowing down compile times (and occasionally causing confusing compiler errors).
- Remove `ufront.middleware` package, and place the middleware in the package to do with it's function instead.
- Use the message of the error as the title on the error page, rather than error.toString()
- Moved things out of the `ufront.handler.*` package. `MVCHandler` and `ErrorPageHandler` are now in `ufront.web`. `RemotingHandler` is now in `ufront.remoting`.

### Platform Support

- NodeJS:
    - Use hxnodejs (the official externs) rather than js-kit.
        - See https://github.com/HaxeFoundation/hxnodejs/
        - See https://github.com/abedev/hxexpress
    - Add NodeJS implementation of FileViewEngine.
    - Add NodeJS implementation of FileSession.
    - Small improvements to NodeJS HttpContext.
- Update `HttpResponse` on client-side JS to use native DOM methods rather than relying on the `detox` haxelib.

### Dependencies

- Update to minject v2.0.0-rc.1, which has macro powered injections (supports type parameters!)
- Removed dependency on `random`.
- Remove dependency on `thx.core`.
- Removed dependency on `detox` on the client side.

### `ufront.api`

- Fix: Make constructor for UFApiClientContext public.
- APIs are now mapped as singletons in the injector for each HttpContext. This means that API1 and API2 can be dependent on each other.

### `ufront.auth`

- Remove type parameter on UFAuthHandler to avoid variance issues. It was mainly used to fetch the current user and have it typed as the implementation, rather than as the `UFAuthUser` interface. The workaround is to now cast, use dependency injection (and ask for the type you want explicitly) or have a different method / property on the auth handler which gets the correctly typed user.
- Remove `setCurrentUser()` from `UFAuthHandler` interface.
- Remove `getUserByID()` from `UFAuthHandler` interface.

### `ufront.cache`

- Add `DBCache` for use with `ufront-orm`.
- Get RequestCacheMiddleware working with new cache mechanisms.

### `ufront.core`

- Add `Uuid` class, and use this instead of a dependency on the `random` haxelib.
- Remove ufront.core.Sync, use ufront.core.AsyncTools instead. Many additions and improvements.
- Add `FutureTools.when()` macro to wait on the result of several futures easily.
- Remove InjectionRef as minject 2 now supports any type, not just class instances.
- Remove the utilities in `InjectionTools` as they don't play well with the new macro-powered minject.

### `ufront.log`

- Restore the original `haxe.Log.trace` function when `HttpApplication.dispose()` has been called.
- Add `OriginalTraceLogger` which forwards request/app traces, logs, warnings and errors to the original trace function (handy for unit testing).

### `ufront.remoting`

- Namespace the remoting errors, to avoid `HttpError` having a naming conflict with `ufront.web.HttpError`.

### `ufront.test`

- Major fixes and improvements to TestUtils and NaturalLanguageTests.
- Added `TestUtils.simulateSession` to simulate a session (multiple requests) in TestUtils and pass cookies, referrer data etc through.

### `ufront.web`

- Remove Dispatch, DispatchController and DispatchHandler. Pretty sure nobody was using those.
- Allow arrays as POST arguments.
- Allow using typedef as the type of `args`.

### `ufront.web.result`

- Added `.create()` shortcuts for ContentResult, JsonResult, RedirectResult and ViewResult to make it easier to work with the tink `>>` operator on futures.
- Major refactor of ViewResult.
- Move `ViewResult.writeResponse()` to a member method so we can subclass ViewResult easily (for example, to render a partial view on client side).
- ViewResult: Also look for @layout metadata on the method, not just the controller
- Fix for `ViewResult.inferLayoutFromContext` on PHP with no default layout

### `ufront.web.session`

- Add CacheSession. Works with any UFCache, so it's pretty versatile.
- Fixes for FileSession.
- Significant unit testing of CacheSession and FileSession.
- Refine definition of `UFHttpSession.isActive()` to mean 'was a session initiated either during this request or during a previous request?'
- Add TestSession (Similarly useless to VoidSession, but holds onto the ID and values for the duration of the request.)

### `ufront.web.upload`

- Rename FileUpload interface to UFFileUpload, following our convention for interfaces.
- Removed UFHttpUploadHandler, it was not being used.

### `ufront.web.url`

- Major cleanup, refactor, documentation, fixes and unit testing of `ufront.web.url` package.

---

# Older changes

For changes prior to 1.0.0, please see http://lib.haxe.org/p/ufront-mvc/versions/
