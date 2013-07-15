package ufront.web.context;

import ufront.web.session.IHttpSessionState;
import thx.error.NullArgument;

/**
	A context describing the result returned by an action.

	Mostly httpContext and it's children, and then also the controller and the action called.
**/
class ActionResultContext
{
	public var httpContext(default, null) : HttpContext;
	public var controller(default, null) : {};
	public var action(default, null) : String;

	public var request(get, null) : HttpRequest;
	public var response(get, null) : HttpResponse;
	public var session(get, null) : IHttpSessionState;

	public function new( httpContext:HttpContext, controller:{}, action:String ) {
		NullArgument.throwIfNull( httpContext );
		this.httpContext = httpContext;
		this.controller = controller;
		this.action = action;
	}
	
	/**
		Dispose of this ActionResultContext.

		Currently just disposes of the given `session`.
	**/
	public function dispose():Void {
		session.dispose();
	}
	
	inline function get_request() return httpContext.request;
	inline function get_response() return httpContext.response;
	inline function get_session() return httpContext.session;
}