package ufront.web.result;

import tink.CoreApi;
import ufront.web.context.ActionContext;
import ufront.core.Sync;

/**
	ActionResult is the base class for all results of actions performed during a MVC request.

	Each action (method) in your controller returns an action result.
	This result will take information about the request (the result of the action, which action was called etc) and write an appropriate response to the client.
	For example, a ViewResult will render a view using the data provided and a template whose path is guessed based on the name of the controller and action that were called.
	As another example, a JsonResult will serialize the returned data and send it to the client as JSON, with the correct HTTP content type headings.

	Please note if an action does not return an action result, it will be wrapped into one using `wrap()` below.
**/
class ActionResult {
	/**
		Every ActionResult must implement the `executeResult` method.

		This method can write output to the HTTP Response, set headers, change content types etc.

		The method may be asynchronous, and should return a `tink.core.Surprise`.

		The ActionResult base class provides a default implementation which has no effect (does not render a result).
	**/
	public function executeResult( actionContext:ActionContext ):Surprise<Noise,Error> {
		return Sync.success();
	}

	/**
		Wrap a dynamic result in an ActionResult.

		If it is null, an `EmptyResult` will be used.
		If it is an ActionResult, it will be left as is.
		If it is a different type, it will be converted to a String and used in a ContentResult.
	**/
	public static function wrap( resultValue:Dynamic ):ActionResult {
		if ( resultValue==null ) {
			return new EmptyResult();
		}
		else {
			var actionResultValue = Std.instance( resultValue, ActionResult );
			if ( actionResultValue==null ) {
				actionResultValue = new ContentResult( Std.string(resultValue) );
			}
			return actionResultValue;
		}
	}
}

/** A typedef shortcut for an action return type that either gives a valid result or a Error **/
typedef ActionOutcome = Outcome<ActionResult,Error>;

/** A typedef shortcut for a Future that will contain an ActionResult **/
typedef FutureActionResult = Future<ActionResult>;

/** A typedef shortcut for a Future that will contain either an ActionResult or a Error **/
typedef FutureActionOutcome = Future<ActionOutcome>;
