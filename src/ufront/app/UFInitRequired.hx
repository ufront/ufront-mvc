package ufront.app;

import tink.CoreApi;
import ufront.app.HttpApplication;
import ufront.web.HttpError;

/**
	This is to be used with Handlers or Middleware that require an init() function.

	Should be used in conjunction with `UFMiddleware`, `UFRequestHandler`, `UFErrorHandler` and `UFLogHandler`.

	If a handler or middleware module implement `UFInitRequired`, then when they are added to the app, `init( httpApplication )` is called, and the app will wait for all modules to be completed before accepting requests.

	Both `init()` and `dispose()` should return a Surprise - a Future letting you know when the outcome of the operation once it has completed - was it a success (continue with the request) or a failure (throw to the error handler).
**/
interface UFInitRequired {
	public function init( app:HttpApplication ):Surprise<Noise,HttpError>;
	public function dispose( app:HttpApplication ):Surprise<Noise,HttpError>;
}