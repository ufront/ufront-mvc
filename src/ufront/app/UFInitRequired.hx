package ufront.app;

import tink.CoreApi;
import ufront.app.HttpApplication;

/**
This is to be used with Handlers or Middleware that require an init() function.

Should be used in conjunction with `UFMiddleware`, `UFRequestHandler`, `UFErrorHandler` and `UFLogHandler`.

If a handler or middleware module implement `UFInitRequired`, then when they are added to the app, `init( httpApplication )` is called, and the app will wait for all modules to be initiated before it begins accepting requests.

Both `init()` and `dispose()` should return a Surprise - a Future letting you know when the outcome of the operation once it has completed - was it a success (continue with the request) or a failure (throw to the error handler).

If your platform supports keeping a `HttpApplication` alive between requests, then each module should initialise only once and stay initialised for each following request.
This is the case for Node JS, Client JS, and Neko when using mod_tora or mod_neko's `Web.cacheModule()` feature.
**/
interface UFInitRequired {
	public function init( app:HttpApplication ):Surprise<Noise,Error>;
	public function dispose( app:HttpApplication ):Surprise<Noise,Error>;
}
