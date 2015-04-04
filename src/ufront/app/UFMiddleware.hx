package ufront.app;

import tink.CoreApi;
import ufront.web.context.HttpContext;

/**
An interface representing Middleware that is applied both before and after processing the request.

This can be useful if you have middleware that sits in both positions, such as a cache that can respond with a cached result at the start of a request, or cache a result at the end of a request.

See `UFRequestMiddleware` and `UFResponseMiddleware` for more details.
**/
interface UFMiddleware extends UFRequestMiddleware extends UFResponseMiddleware {}

/**
Middleware that runs before the request has been processed.

#### Examples:

- Performing HTTP Redirects
- Initiating a `HttpSession` based on a cookie.
- Checking if an existing cached response is available and can be used.
- Begin a timer to measure the performance of the request.

#### Details:

This middleware has full access to the HttpContext of the current request, so can modify the request details or write to the response.

To prevent the request from executing the request handler, you can modify the values of `ctx.completion` to skip remaining request middleware, the request handler, any response middleware, logging, or flushing the response to the browser. See `HttpContext.completion`.
**/
interface UFRequestMiddleware {
	/**
	Perform an action on the current request.

	@param ctx The current `HttpContext`, allowing you to read `HttpRequest` details, or write to the `HttpResponse`.
	@return A `Surprise` indicating the middleware has completed and the request may continue. If a `Failure` is returned the `UFErrorHandler` modules will be run.
	**/
	public function requestIn( ctx:HttpContext ):Surprise<Noise,Error>;
}

/**
Middleware that runs after the request has been processed.

#### Examples:

- Modify or append the response.
- Cache the response for fututre requests.
- Save data from the request for analytics.
- Write session data from the request to the disk.

#### Details:

This middleware has full access to the `HttpContext` of the current request, so can modify the request details or write to the response.

You can modify the values of `ctx.completion` to skip remaining response middleware, the logging or flushing stages of the request. See `HttpContext.requestCompletion`.
**/
interface UFResponseMiddleware {
	/**
	Perform an action on the current request.

	@param ctx The current `HttpContext`, allowing you to read `HttpRequest` details, or write to the `HttpResponse`.
	@return A `Surprise` indicating the middleware has completed and the request may continue. If a `Failure` is returned the `UFErrorHandler` modules will be run.
	**/
	public function responseOut( ctx:HttpContext ):Surprise<Noise,Error>;
}
