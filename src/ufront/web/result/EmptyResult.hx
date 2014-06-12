package ufront.web.result;

import ufront.web.context.ActionContext;
import ufront.core.Sync;

/**
 * Represents a result that does nothing, such as a controller action method that returns nothing.
 * @author Andreas Soderlund
 */

class EmptyResult extends ActionResult
{
	var preventFlush:Bool;
	public function new( ?preventFlush=false ){
		this.preventFlush = preventFlush;
	}
	
	override public function executeResult( actionContext:ActionContext ) {
		if ( preventFlush ) actionContext.httpContext.response.preventFlush();
		return Sync.success();
	}
}