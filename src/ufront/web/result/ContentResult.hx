package ufront.web.result;

import thx.error.NullArgument;
import ufront.web.context.ActionContext;
import ufront.core.AsyncTools;
using tink.CoreApi;

/**
An `ActionResult` that prints specific `String` content to the client, optionally specifying a `contentType`.

This works using `HttpResponse.write(content)` and `HttpResponse.contentType`.
**/
class ContentResult extends ActionResult {
	public var content:String;
	public var contentType:String;

	public function new( ?content:String, ?contentType:String ) {
		this.content = (content!=null) ? content : "";
		this.contentType = contentType;
	}

	override public function executeResult( actionContext:ActionContext ) {
		if( null!=contentType )
			actionContext.httpContext.response.contentType = contentType;

		actionContext.httpContext.response.write( content );
		return SurpriseTools.success();
	}
}
