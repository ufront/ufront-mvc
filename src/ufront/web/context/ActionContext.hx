package ufront.web.context;

import ufront.web.session.UFHttpSessionState;
import ufront.web.result.ActionResult;
import thx.error.NullArgument;
import ufront.auth.*;
using StringTools;

/**
	A context describing the result returned by an action.

	Contains the `HttpContext`, it's children, the controller, action and arguments used.
**/
class ActionContext
{
	/** A link to the full `HttpContext` **/
	public var httpContext(default, null):HttpContext;

	/** A link to the full `HttpRequest` **/
	public var request(get, null):HttpRequest;

	/** A link to the full `HttpResponse` **/
	public var response(get, null):HttpResponse;

	/** A link to the current `UFHttpSessionState` **/
	public var session(get, null):UFHttpSessionState;

	/** A link to the current `UFAuthHandler` **/
	public var auth(get, null):UFAuthHandler<UFAuthUser>;

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
	public function new( httpContext:HttpContext, ?controller:{}, ?action:String, ?args:Array<Dynamic> ) {
		NullArgument.throwIfNull( httpContext );

		this.httpContext = httpContext;
		this.controller = controller;
		this.action = action;
		this.args = args;

		// set the back-reference from HttpContext
		httpContext.actionContext = this;
	}
	
	inline function get_request() return httpContext.request;
	inline function get_response() return httpContext.response;
	inline function get_session() return httpContext.session;
	inline function get_auth() return httpContext.auth;

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