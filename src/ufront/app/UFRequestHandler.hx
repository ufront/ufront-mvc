package ufront.app;

import tink.CoreApi;
import ufront.web.context.HttpContext;

/**
Represents an object that can handle a `HttpRequest`, process as required, and write the `HttpResponse`.

The two most common handlers for ufront include `MVCHandler` and `RemotingHandler`.

Multiple request handlers can exist in an application.
They will be called one at a time (in the order they were added) until one of them successfully handles the request.
The first to successfully handle the request should mark `ctx.completion.requestHandler=true` so that other handlers do not also run. See `HttpContext.completion`.
**/
interface UFRequestHandler {
	/**
	Handle the current request.

	@param ctx The `HttpContext` of the current request, giving you access to the `HttpRequest` to process input and the `HttpResponse` to write output.
	@return A `Surprise`, indicating when the request handler has finished, and if it encountered an error.
	**/
	public function handleRequest( ctx:HttpContext ):Surprise<Noise,Error>;

	/**
	The `toString()` method should return the name of the current handler.
	This is used for logging / debugging purposes.
	**/
	public function toString():String;
}
