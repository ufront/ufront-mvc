package ufront.web.context;

import ufront.web.result.ActionResult;
import thx.error.NullArgument;

/**
	A context describing the result returned by an action.

	Contains the `HttpContext`, as well as the utilised UFRequestHandler, controller, action, arguments and result.

	It is useful for helping know how to present a response to the client, and is used in the `ufront.web.result.ActionResult` classes.

	It is also helpful for logging and for unit testing - so we can be sure our requests are being acted upon in the way we expect.
**/
class ActionContext
{
	/** A link to the full `HttpContext` **/
	public var httpContext(default, null):HttpContext;

	/** The UFRequestHandler that was used in this request.  Will be null until the request is handled. **/
	public var handler:Null<{}>;

	/** The controller that was used in this request.  Will be null until the request is handled. **/
	public var controller:Null<{}>;

	/** The name of the action / method that was used in this request.  Will be null until the request is handled. **/
	public var action:Null<String>;

	/** The array of arguments used for the current action / method in this request.  Will be null until the request is handled. **/
	public var args:Null<Array<Dynamic>>;

	/** The `ActionResult` that came from processing the request. Will be null until the action has been executed. **/
	public var actionResult:ActionResult;

	/**
		An array containing all the "parts" of the current Uri, split by "/".

		The first time you access this, it will load it from `httpContext.getRequestUri().split("/")`.

		Note: this array may be modified as the request is handled.
		For example, if dispatching to a sub-controller, the controller may remove certain parts and leave only parts relevant to the sub controller.
		If you need access to the original `uriParts`, you should split the `httpContext.getRequestUri()` yourself to be sure.
	**/
	public var uriParts(get, null):Array<String>;

	/** Create a new ActionContext.  HttpContext is required. **/
	public function new( httpContext:HttpContext ) {
		NullArgument.throwIfNull( httpContext );
		this.httpContext = httpContext;
	}

	function get_uriParts() {
		if ( uriParts==null ) {
			uriParts = httpContext.getRequestUri().split( "/" );
			if ( uriParts.length>0 && uriParts[0]=="" ) uriParts.shift();
			if ( uriParts.length>0 && uriParts[uriParts.length-1]=="" ) uriParts.pop();
		}
		return uriParts;
	}

	public function toString() return 'ActionContext($controller, $action, $args)';
}
