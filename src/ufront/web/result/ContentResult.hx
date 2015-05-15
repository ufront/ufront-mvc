package ufront.web.result;

import thx.error.NullArgument;
import ufront.web.context.ActionContext;
import ufront.core.Futuristic;
using tink.CoreApi;

/**
An `ActionResult` that prints specific `String` content to the client, optionally specifying a `contentType`.

This works using `HttpResponse.write(content)` and `HttpResponse.contentType`.

`ContentResult` uses `Futuristic` for its content, meaning it can work with either a synchronous `String`, or a `Future<String>`.
**/
class ContentResult extends ActionResult {
	public var contentFuture:Future<String>;
	public var contentType:String;

	public function new( ?content:Futuristic<String>, ?contentType:String ) {
		this.contentFuture = (content!=null) ? content : Future.sync("");
		this.contentType = contentType;
	}

	override public function executeResult( actionContext:ActionContext ) {
		return contentFuture.map(function(content) {
			if( null!=contentType )
				actionContext.httpContext.response.contentType = contentType;

			actionContext.httpContext.response.write( content );
			return Success( Noise );
		});
	}
}
