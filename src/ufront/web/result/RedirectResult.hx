package ufront.web.result;

import thx.core.error.NullArgument;
import ufront.web.context.ActionContext;
import ufront.core.Sync;

/** Controls the processing of application actions by redirecting to a specified URI. */
class RedirectResult extends ActionResult
{
	/** The target URL. */
	public var url:String;

	/** Indicates whether the redirection should be permanent. */
	public var permanentRedirect:Bool;

	public function new( url:String, ?permanentRedirect=false ) {
		NullArgument.throwIfNull(url);
		this.url = url;
		this.permanentRedirect = permanentRedirect;
	}

	override function executeResult( actionContext:ActionContext ) {
		return redirect(actionContext);
	}
	
	private function redirect(actionContext:ActionContext) {
		// Clear content and headers, but not cookies
		actionContext.httpContext.response.clearContent();
		actionContext.httpContext.response.clearHeaders();

		if(permanentRedirect) actionContext.httpContext.response.permanentRedirect( url );
		else actionContext.httpContext.response.redirect( url );

		return Sync.success();
	}
}
