package ufront.app;

import tink.CoreApi;
import ufront.web.context.HttpContext;
import ufront.log.Message;

/**
Interface for a Logger - something which takes trace, log, warning and error messages from the request and logs them appropriately.

#### Examples:

The log handler could be used in multiple ways:

- Sending them to the client's browser console. (`BrowserConsoleLogger` and `RemotingLogger`)
- Saving them to a log file on the server. (`FileLogger`)
- Saving them to a database
- Sending them to a debugging tool
- Logging them in an analytics program like Google Analytics or Mixpanel.

#### Errors during log handling:

If an error is encountered in the request's life cycle, then the `UFErrorHandler` modules are executed, followed by the `UFLogHandler` modules.
This allows logging of the error to still occur.

Please keep in mind that if your log handler throws an exception or returns a `Failure`, it may be after the error handlers have already run, and Ufront will give a fairly crude error screen.
Please be careful to make sure your `log` functions fail gracefully.
**/
interface UFLogHandler {
	/**
	The method to be called once per request to log all messages.

	@param ctx The HttpContext for the current request, including all messages.
	@param appMessages Any `Message` objects which were collected by the application, and may not belong to this particular request. This is usually the result of calling `trace` rather than `ufTrace`. A `UFLogHandler` may choose not to display `appMessages` depending on the context.
	@return A `Surprise` - A `Success` if the log was written successfully and the request can continue, or a `Failure(Error)` if one was encountered and the request should be stopped. See the note above about failures during log handlers, and use with care.
	**/
	public function log( ctx:HttpContext, appMessages:Array<Message> ):Surprise<Noise,Error>;
}
