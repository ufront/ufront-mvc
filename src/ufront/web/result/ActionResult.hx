package ufront.web.result;

import tink.CoreApi;
import ufront.web.context.ActionContext;
import ufront.core.Sync;
using Types;

/** 
	Encapsulates the result of an action method and is used to perform a framework-level operation on behalf of the action method. 
**/
class ActionResult {
	/** Enables processing of the result of an action method by a custom type that inherits from the ActionResult class. */
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
			var actionResultValue = Types.as( resultValue, ActionResult );
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