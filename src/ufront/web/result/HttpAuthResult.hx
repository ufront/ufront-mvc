package ufront.web.result;

import ufront.web.result.ActionResult;
import ufront.web.context.*;
import ufront.web.HttpError;
import tink.CoreApi;
import ufront.core.Sync;


/**
A result that requires a certain username and password to be provided before executing an action.

Recommended usage:

```haxe
@:route("/admin/")
public function adminArea() {
	return HttpAuthResult.requireAuth( context, "admin", "its-a-secret", "Please Log In", "Bad Username or Password", function() {
		executeSubController( AdminController );
	});
};
```
**/
class HttpAuthResult extends ActionResult {

	var message:String;
	var failureMessage:String;

	/**
	@param username The expected username.
	@param password The expected password.
	@param message (optional) The message to show in the popup box. Default is "Please login";
	@param failureMessage (optional) The HTML to show in the browser if the login is cancelled. Default is to re-use `message`.s
	@param successFn The function to execute if authentication is correct. Must return a `FutureActionOutcome`, such as from using `executeSubController( AdminController )`.
	@return A FutureActionOutcome, either the result of `fn()` or a `HttpAuthResult` that displays a login box.
	**/
	public static function requireAuth( context:HttpContext, username:String, password:String, ?message:String, ?failureMessage:String, successFn:Void->FutureActionOutcome ):FutureActionOutcome {
		var auth = context.request.authorization;
		if ( auth!=null && auth.user==username && auth.pass==password ) {
			return successFn();
		}
		else {
			var result:ActionResult = new HttpAuthResult(message,failureMessage);
			return Future.sync( Success(result) );
		}
	}

	function new( message:String, failureMessage:Null<String> ) {
		this.message = message;
		this.failureMessage = failureMessage!=null ? failureMessage : message;
	}

	override public function executeResult( actionContext:ActionContext ) {
		actionContext.httpContext.response.requireAuthentication( message );
		actionContext.httpContext.response.write( failureMessage );
		return Sync.success();
	}
}
