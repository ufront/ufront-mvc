package ufront.web.context;

import ufront.web.session.UFHttpSessionState;
import thx.error.NullArgument;
import ufront.auth.*;

/**
	A context describing the result returned by an action.

	Contains the `HttpContext`, it's children, the controller, action and arguments used.
**/
class ActionContext
{
	public var httpContext(default, null):HttpContext;
	public var controller:Null<{}>;
	public var action:Null<String>;
	public var args:Null<Array<Dynamic>>;

	public var request(get, null):HttpRequest;
	public var response(get, null):HttpResponse;
	public var session(get, null):UFHttpSessionState;
	public var auth(get, null):UFAuthHandler<UFAuthUser>;

	public function new( httpContext:HttpContext, ?controller:{}, ?action:String, ?args:Array<Dynamic> ) {
		NullArgument.throwIfNull( httpContext );
		this.httpContext = httpContext;
		this.controller = controller;
		this.action = action;
		this.args = args;
	}
	
	inline function get_request() return httpContext.request;
	inline function get_response() return httpContext.response;
	inline function get_session() return httpContext.session;
	inline function get_auth() return httpContext.auth;

	public function toString() return 'ActionContext($controller, $action, $args)';
}