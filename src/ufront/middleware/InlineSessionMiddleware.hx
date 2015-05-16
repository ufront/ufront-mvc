package ufront.middleware;

import ufront.web.context.HttpContext;
import ufront.app.UFMiddleware;
import ufront.app.HttpApplication;
import tink.CoreApi;
import ufront.web.HttpError;
import ufront.core.AsyncTools;
using thx.Types;

/**
	Make sure we `init()` sessions before the request starts, and `commit()` them before it ends

	@author Jason O'Neil
**/
class InlineSessionMiddleware implements UFMiddleware
{
	/**
		Should we start a session for every request, or only if one already exists?
		If false, one will only be started if init() is called specifically on one request.
		(For example, when they log in).
		From there onwards it will initialize with each request.
	**/
	public static var alwaysStart:Bool = false;

	public function new() {}

	/**
		Start the session if a SessionID exists in the request, or if `alwaysStart` is true.
	**/
	public function requestIn( ctx:HttpContext ):Surprise<Noise,Error> {
		if ( alwaysStart || ctx.session.id!=null ) {
			return ctx.session.init().map(function (outcome) return switch (outcome) {
				case Success(s): Success(s);
				case Failure(f): Failure( HttpError.internalServerError(f) );
			});
		}
		return SurpriseTools.success();
	}

	/**
		If the session is active, commit the session before finishing the request.
	**/
	public function responseOut( ctx:HttpContext ):Surprise<Noise,Error> {
		return
			if ( ctx.session!=null )
				ctx.session.commit() >>
				function (outcome) switch (outcome) {
					case Success(s): return Success(s);
					case Failure(err): return Failure( err );
				}
			else SurpriseTools.success();
	}
}
