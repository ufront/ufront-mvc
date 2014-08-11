package ufront.app;

import tink.CoreApi;
import ufront.web.context.HttpContext;

/**
	An interface representing Middleware that is applied both before and after processing the request.

	This can be useful if you have middleware that sits in both positions

	See `UFRequestMiddleware` and `UFResponseMiddleware` for more details.
**/
interface UFMiddleware extends UFRequestMiddleware extends UFResponseMiddleware {}

/**
	Middleware that runs before the request has been processed.

	It can be used for things such as:

	- perform redirects
	- initiate a session
	- check for a cached response
	- begin a timer to measure the length of the request

	etc.  This middleware has full access to the HttpContext of the current request, so can modify the request details or write to the response.

	To prevent the request from executing (for example, if you have a cached version of the page you can display), you can modify the values of `ctx.completion` to skip remaining request middleware, the request handler, any response middleware, logging, or flushing the response to the browser.

	The `requestIn()` method should return a Surprise - a Future letting you know when the outcome of the operation once it is complete - was it a success (continue with the request) or a failure (throw to the error handler)
**/
interface UFRequestMiddleware {
	public function requestIn( ctx:HttpContext ):Surprise<Noise,Error>;
}

/**
	Middleware that runs after the request has been processed.

	It can be used for things such as:

	- modify or append the response,
	- log traces from the request (either including `console.log` snippets in the response, or logging on the server)
	- cache the response for fututre requests
	- save data from the request for analytics

	etc.  This middleware has full access to the HttpContext of the current request, so can modify the request details or write to the response.

	You can modify the values of `ctx.completion` to skip remaining response middleware, the logging or flushing stages of the request.

	The `responseOut()` method should return a Surprise - a Future letting you know when the outcome of the operation once it is complete - was it a success (continue with the request) or a failure (throw to the error handler)
**/
interface UFResponseMiddleware {
	public function responseOut( ctx:HttpContext ):Surprise<Noise,Error>;
}
