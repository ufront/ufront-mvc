package ufront.app;

import tink.CoreApi;
import ufront.web.context.HttpContext;

/**
	Represents an object that can handle a `HttpRequest`, process as required, and write the `HttpResponse`.

	Two big examples for ufront include `DispatchHandler` and `RemotingHandler`.

	Multiple request handlers can exist in an application.  They will be called one at a time (in the order they were added) until one of them successfully handles the request.  The first to successfully handle the request should mark `httpContext.completion.requestHandler=true` so that other handlers do not also run.

	The `handleRequest()` method should return a Surprise - a Future letting you know when the outcome of the request handler once it has completed - was it a success (continue with the request) or a failure (throw to the error handler).

	If the outcome was a success, the response middleware, logging and flushing stages will then take place.
**/
interface UFRequestHandler {
	public function handleRequest( ctx:HttpContext ):Surprise<Noise,Error>;
	public function toString():String;
}
