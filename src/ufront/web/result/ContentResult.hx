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

	This will transform all URLs beginning with `~/` and wrapped in single quotes or double quotes.

	This will find URLs beginning with `~/` that look like they are part of a `href=`, `src=` or `action=` HTML attribute.
	(Note: the regex used to check this checks for `src="~/path/"`, and does not yet verify that the pattern is inside a HTML tag, please use with care).
	**/
	public static function replaceRelativeLinks( actionContext:ActionContext, html:String ):String {
		var singleQuotes = ~/(src|href|action)=(')(~\/[^']*)'/gi;
		var doubleQuotes = ~/(src|href|action)=(")(~\/[^"]*)"/gi;
		function transformUri( r:EReg ):String {
			var attName = r.matched( 1 );
			var quote = r.matched( 2 );
			var originalUri = r.matched( 3 );
			var transformedUri = ActionResult.transformUri( actionContext, originalUri );
			return attName+"="+quote+transformedUri+quote;
		}
		html = singleQuotes.map( html, transformUri );
		html = doubleQuotes.map( html, transformUri );
		return html;
	}
}
