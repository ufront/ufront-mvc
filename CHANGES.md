# 1.0.0

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
