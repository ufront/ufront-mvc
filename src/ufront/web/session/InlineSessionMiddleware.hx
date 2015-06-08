package ufront.web.session;

import ufront.web.context.HttpContext;
import ufront.app.UFMiddleware;
import ufront.app.HttpApplication;
import tink.CoreApi;
import ufront.web.HttpError;
import ufront.core.AsyncTools;

/**
The `InlineSessionMiddleware` makes sure we `init()` a session before a request starts, and `commit()` it before the request ends.

Because these operations are asynchronous, it can be frustrating to deal with in other parts of your web application.
Using this middleware allows you to work with the assumption that sessions will be available and ready when you need them.

This middleware is included in the default `UfrontConfiguration`.

__Always Start?__

By default, this middleware will not start a session for a visitor when they first come to your website.
The session state will only be initialised if an existing `sessionID` is found - for example, if you set a session ID when they logged in.
This way you do not start a session unnecessarily, but after they have logged in, the session will be initialised for each request.

This behaviour can be changed by setting `InlineSessionMiddleware.alwaysStart = true`.

If `alwaysStart` is true, then a session will be initiated even on the first visit to the website.

@author Jason O'Neil
**/
class InlineSessionMiddleware implements UFMiddleware {
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
