package ufront.app;

import tink.CoreApi;
import ufront.web.context.HttpContext;

/**
An error handler that can help us output, log, diagnose or even recover from errors in our HttpApplication.

#### When error handlers are used:

During the life of a request, each module (`UFRequestMiddleware`, `UFRequestHandler`, `UFResponseMiddleware`, `UFLogHandler` and `UFErrorHandler`) processes the current request.
If any of these throw an exception or return a `Failure`, then each of our `UFErrorHandler` modules is called and given the chance to respond to the error.

#### Example usages:

Error handlers can log an error, display an error, or even try recover from an error. Examples include:

- Displaying a helpful error page.
- Redirecting old URLs to their new location.
- Providing stack traces to the developer console.
- Logging or emailing a copy of the error report.

#### Multiple error handlers:

Because multiple `UFErrorHandlers` can be used, you should be careful that you don't have any conflicting.
For example, if two separate error handlers both try to display a different error page, the result could be confusing.
One approach is to only use one error handler that writes to the request, such as `ErrorPageHandler`.
Another strategy is to use `ctx.completion.has(CErrorHandlersComplete)` to check if the error has already been handled adequately. See `HttpContext.completion`.

#### Errors during "handleError":

Like other modules, `UFErrorHandler` can return a `Failure(Error)`, or simply throw an exception.

If there is an error in your error handler, Ufront will try to inform you, but the result is crude and you should aim to never have it shown to end users.

Please take care to make sure your error handlers fail gracefully.
**/
interface UFErrorHandler {
	/**
		Handle an `Error` that was thrown or returned by one of our modules, controllers or APIs.

		@param err The `Error` that was thrown or returned by one of our modules, controllers or APIs.
		@param ctx The current `HttpContext` for the request, which can be used to gather more information or write a response to the output.
		@return A `Surprise`, letting us know when the handler is finished, and if it succeeded (and the request should continue) or if it failed. See note above regarding errors in error handlers.
	**/
	public function handleError( err:Error, ctx:HttpContext ):Surprise<Noise,Error>;
}
