package ufront.web.result;

import ufront.web.context.ActionContext;
import ufront.core.AsyncTools;
using tink.CoreApi;

/**
An `ActionResult` that prints specific `String` content to the client, optionally specifying a `contentType`.

This works using `HttpResponse.write(content)` and `HttpResponse.contentType`.
**/
class ContentResult extends ActionResult {

	/**
	A shortcut to create a new ContentResult.

	This is useful when you are waiting for a Future: `return getFutureContent() >> ContentResult.create;`
	**/
	public static function create( content:String ):ContentResult return new ContentResult( content, null );

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
