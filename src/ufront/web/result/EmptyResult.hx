package ufront.web.result;

import ufront.web.context.ActionContext;
import ufront.core.Sync;

/**
	Represents a result that takes no further action and writes nothing to the response.

	This is useful if your controller action has written to the response directly, for example using `Sys.println`.

	@author Andreas Soderlund
**/
class EmptyResult extends ActionResult
{
	var preventFlush:Bool;

	/**
		@param preventFlush Should we prevent the application from "flushing" the response, this will prevent both content and headers, cookies, status codes etc from being returned to the client.
	**/
	public function new( ?preventFlush=false ){
		this.preventFlush = preventFlush;
	}

	override public function executeResult( actionContext:ActionContext ) {
		if ( preventFlush ) actionContext.httpContext.response.preventFlush();
		return Sync.success();
	}
}
