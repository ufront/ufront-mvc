package ufront.web.result;

import thx.error.NullArgument;
import ufront.web.context.ActionContext;
import ufront.core.Futuristic;
using tink.CoreApi;

/**
An `ActionResult` that redirects the client to a new location.

This works using `HttpResponse.redirect(url)` or `HttpResponse.permanentRedirect(url)`.

`RedirectResult` uses `Futuristic` for its url, meaning it can work with either a synchronous value for the URL, or a `Future` which will eventually contain the value for the URL.
**/
class RedirectResult extends ActionResult {
	/** The target URL. */
	public var urlFuture:Future<String>;

	/** Indicates whether the redirection should be permanent. */
	public var permanentRedirect:Bool;

	public function new( url:Futuristic<String>, ?permanentRedirect=false ) {
		NullArgument.throwIfNull(url);
		this.urlFuture = url;
		this.permanentRedirect = permanentRedirect;
	}

	override function executeResult( actionContext:ActionContext ) {
		NullArgument.throwIfNull(actionContext);
		NullArgument.throwIfNull(urlFuture);

		return urlFuture.map(function (url) {
			// Clear content and headers, but not cookies.
			actionContext.httpContext.response.clearContent();
			actionContext.httpContext.response.clearHeaders();

			if(permanentRedirect)
				actionContext.httpContext.response.permanentRedirect( url );
			else
				actionContext.httpContext.response.redirect( url );

			return Success(Noise);
		});
	}
}
