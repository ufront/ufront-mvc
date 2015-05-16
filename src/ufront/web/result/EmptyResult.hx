package ufront.web.result;

import ufront.web.context.ActionContext;
import ufront.core.AsyncTools;

/**
Represents a result that takes no further action and writes nothing to the response.

This is useful if your controller action has written to the response directly, for example using `Sys.println`.

@author Andreas Soderlund
**/
class EmptyResult extends ActionResult
{
	/**
	Should we prevent the application from "flushing" the response?
	This will prevent content, headers, cookies, status codes, or any other part of the `HttpResponse`, from being returned to the client.
	**/
	public var preventFlush:Bool;

	/**
		@param preventFlush
	**/
	public function new( ?preventFlush=false ){
		this.preventFlush = preventFlush;
	}

	override public function executeResult( actionContext:ActionContext ) {
		if ( preventFlush ) actionContext.httpContext.response.preventFlush();
		return SurpriseTools.success();
	}
}
