package ufront.web.result;

import ufront.web.context.ActionContext;
import ufront.web.result.RedirectResult;

using tink.CoreApi;
/**
 * ...
 * @author Kevin
 */
class AsyncRedirectResult extends RedirectResult
{
	private var futureUrl:Future<String>;
	
	public function new(futureUrl:Future<String>, ?permanentRedirect=false) {
		super("", permanentRedirect);
		this.futureUrl = futureUrl;
	}
	
	override function executeResult(actionContext:ActionContext) {
		return futureUrl.flatMap(function(url) {
			this.url = url;
			return redirect(actionContext);
		});
	}
}