package ufront.app;

import tink.CoreApi;
import ufront.web.context.HttpContext;
import ufront.web.HttpError;
import ufront.log.Message;

/**
	Interface for a Logger - something which takes trace, log and error messages from the request and logs them appropriately.

	This may include:

	- Sending them to the client's browser console
	- Saving them to a log file on the server
	- Saving them to a database
	- Sending them to a debugging tool

	etc.  

	The `log()` method takes two arguments - the `HttpContext`, which will include the messages for the current request, and `appMessages`, which may contain app specific messages which may or may not be relevant to that request.  It is up to the LogHandler to decide whether to log these or not.

	The `log()` method should return a Surprise - a Future letting you know when the outcome of the operation once it is complete - was it a success (you can continue) or a failure (throw to the error handler)
**/
interface UFLogHandler {
	public function log( ctx:HttpContext, appMessages:Array<Message> ):Surprise<Noise,HttpError>;
}