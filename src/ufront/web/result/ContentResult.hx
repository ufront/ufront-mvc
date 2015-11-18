package ufront.web.result;

import ufront.web.context.ActionContext;
import ufront.core.AsyncTools;
using tink.CoreApi;

/**
An `ActionResult` that prints specific `String` content to the client, optionally specifying a `contentType`.

This works using `HttpResponse.write(content)` and `HttpResponse.contentType`.

If the ContentType of the response is `text/html` then we will use `ContentResult.replaceRelativeLinks` to replace relative URIs in HTML `src`, `href` and `action` attributes.
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
		if ( null!=contentType )
			actionContext.httpContext.response.contentType = contentType;

		if ( actionContext.httpContext.response.contentType=="text/html" )
			content = replaceRelativeLinks( actionContext, content );

		actionContext.httpContext.response.write( content );
		return SurpriseTools.success();
	}

	/**
	Search for relative URLs in the HTML content and transform them using the appropriate URL filters.

	This will transform all URLs beginning with `~/` that are wrapped in either single quotes or double quotes, and contain no whitespace.

	TODO: provide a way to 'escape' this behaviour, perhaps by using `~~/` which will be rendered as plain `~/`.
	**/
	public static function replaceRelativeLinks( actionContext:ActionContext, html:String ):String {
		var singleQuotes = ~/(')(~\/[^'\s]*)'/gi;
		var doubleQuotes = ~/(")(~\/[^"\s]*)"/gi;
		function transformUri( r:EReg ):String {
			var quote = r.matched( 1 );
			var originalUri = r.matched( 2 );
			var transformedUri = ActionResult.transformUri( actionContext, originalUri );
			return quote+transformedUri+quote;
		}
		html = singleQuotes.map( html, transformUri );
		html = doubleQuotes.map( html, transformUri );
		return html;
	}
}
