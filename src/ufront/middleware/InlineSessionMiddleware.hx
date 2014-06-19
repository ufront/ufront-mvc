package ufront.middleware;

import ufront.web.context.HttpContext;
import ufront.app.UFMiddleware;
import ufront.app.HttpApplication;
import tink.CoreApi;
import ufront.web.HttpError;
import ufront.core.Sync;
using Types;

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
	public static var alwaysStart:Bool;

	public function new() {}

	/**
		Start the session if a SessionID exists in the request, or if `alwaysStart` is true.
	**/
	public function requestIn( ctx:HttpContext ):Surprise<Noise,Error> {
		return 
			if ( alwaysStart || ctx.session.isActive() ) 
				ctx.session.init() >>
				function (outcome) switch (outcome) {
					case Success(s): return Success(s);
					case Failure(f): return Failure( HttpError.internalServerError(f) );
				}
			else Sync.success();
	}

	/**
		If the session is active, commit the session before finishing the request.
	**/
	public function responseOut( ctx:HttpContext ):Surprise<Noise,Error> {
		return 
			if ( ctx.session.isActive() ) 
				ctx.session.commit() >>
				function (outcome) switch (outcome) {
					case Success(s): return Success(s);
					case Failure(f): return Failure( HttpError.internalServerError(f) );
				}
			else Sync.success();
	}
}
