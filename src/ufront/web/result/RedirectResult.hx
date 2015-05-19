package ufront.web.result;

import thx.error.NullArgument;
import ufront.web.context.ActionContext;
import ufront.core.AsyncTools;
using tink.CoreApi;

/**
An `ActionResult` that redirects the client to a new location.

This works using `HttpResponse.redirect(url)` or `HttpResponse.permanentRedirect(url)`.
**/
class RedirectResult extends ActionResult {
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
		NullArgument.throwIfNull(actionContext);
		NullArgument.throwIfNull(url);

		// Clear content and headers, but not cookies.
		actionContext.httpContext.response.clearContent();
		actionContext.httpContext.response.clearHeaders();

		if(permanentRedirect)
			actionContext.httpContext.response.permanentRedirect( url );
		else
			actionContext.httpContext.response.redirect( url );

		return SurpriseTools.success();
	}
}
