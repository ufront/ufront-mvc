package ufront.web.result;

import tink.CoreApi;
import ufront.web.context.ActionContext;
import ufront.web.HttpError;
import ufront.core.Sync;
using Types;

/** 
	Encapsulates the result of an action method and is used to perform a framework-level operation on behalf of the action method. 
**/
class ActionResult {
	/** Enables processing of the result of an action method by a custom type that inherits from the ActionResult class. */
	public function executeResult( actionContext:ActionContext ):Surprise<Noise,HttpError> {
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