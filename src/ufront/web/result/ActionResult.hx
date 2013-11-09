package ufront.web.result;

import tink.CoreApi;
import ufront.web.context.ActionContext;
import ufront.web.HttpError;
import ufront.core.Sync;

/** 
	Encapsulates the result of an action method and is used to perform a framework-level operation on behalf of the action method. 
**/
class ActionResult {
	/** Enables processing of the result of an action method by a custom type that inherits from the ActionResult class. */
	public function executeResult( actionContext:ActionContext ):Surprise<Noise,HttpError> {
		return Sync.success();
	}
}