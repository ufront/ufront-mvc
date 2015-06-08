package ufront.web.context;

import ufront.web.result.ActionResult;
import ufront.web.HttpError;
import ufront.app.UFRequestHandler;

/**
A context holding information about which action was taken during the request, and what the result was.

An `ActionContext` keeps track of:

- Which `UFRequestHandler` handled the request.
- Which `Controller` (or API or other object) did the main request processing.
- Which "action" was executed on the above controller.
- Which arguments were passed to the above action.
- What the result of the given action was.

One of the main uses is in the `ActionResult` classes.
These take an `ActionContext` and use it to write a response to the client, based on the information in this context.

It is also helpful for logging and for unit testing - so we can be sure our requests are going to the right places, and being handled in the way we expect.
**/
class ActionContext {
	/** A link to the full `HttpContext` this ActionContext is associated with. **/
	public var httpContext(default, null):HttpContext;

	/**
	The `UFRequestHandler` that was used in this request.

	This will be `null` until the request is handled.
	**/
	public var handler:Null<UFRequestHandler>;

	/**
	The controller that was used in this request.

	Please note this will not always be a `Controller` object.
	For example, a `RemotingHandler` would insert the `UFApi` that was acted upon as the controller here.

	This will be `null` until the request is handled.
	**/
	public var controller:Null<{}>;

	/**
	The name of the action or method that was used in this request.

	This will be `null` until the request is handled.
	**/
	public var action:Null<String>;

	/**
	The array of arguments used for the current action or method in this request.

	This will be `null` until the request is handled.
	**/
	public var args:Null<Array<Dynamic>>;

	/**
	The `ActionResult` that came from processing the request.

	This will be `null` until the request is handled.
	**/
	public var actionResult:ActionResult;

	/**
	An array containing all the "parts" of the current Uri, split by "/".

	The first time you access this, it will load it from `httpContext.getRequestUri().split("/")`.

	Note: this array may be modified as the request is handled.
	For example, if dispatching to a sub-controller, the controller may remove certain parts and leave only parts relevant to the sub controller.
	If you need access to the original `uriParts`, you should split the `httpContext.getRequestUri()` yourself to be sure.
	**/
	public var uriParts(get, null):Array<String>;

	/**
	Create a new ActionContext, to be associated with the given `HttpContext`.
	**/
	public function new( httpContext:HttpContext ) {
		HttpError.throwIfNull( httpContext, "httpContext" );
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
