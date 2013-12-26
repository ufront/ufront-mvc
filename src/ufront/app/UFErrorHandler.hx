package ufront.app;

import tink.CoreApi;
import ufront.web.context.HttpContext;
import ufront.web.HttpError;

/**
	Represents an error handler that can help us output, log, diagnose or even recover from errors in our HttpApplication.

	When an unhandled Failure or exception occurs, each of the UFErrorHandler events will fire.

	These can perform tasks such as:

	- Displaying a helpful error page
	- Providing stack traces to the developer
	- Logging or emailing a copy of the error report

	Because multiple ErrorHandlers can exist at once, you should only add one which writes to the http response, or you may generate a confusing page/message.  Another approach is to make your error handler only write a response if one is not already written.

	The `handleError()` method should return a Surprise - a Future letting you know when the outcome of the error handler once it has completed - was it a success (continue with any remaining stages in the request) or a failure (in which case, a raw error will be thrown - you have an error in your error handler).
**/
interface UFErrorHandler {
	public function handleError( err:HttpError, ctx:HttpContext ):Surprise<Noise,HttpError>;
}