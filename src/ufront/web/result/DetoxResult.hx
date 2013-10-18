package ufront.web.result;

import dtx.DOMCollection;
import tink.CoreApi;
import thx.error.NullArgument;
import ufront.web.context.ActionContext;
import dtx.widget.Widget;
import dtx.layout.IDetoxLayout;
import ufront.core.AsyncCallback;
using Detox;

/** Represents a class that is used to send JSON-formatted content to the response. */
class DetoxResult<W:DOMCollection> extends ActionResult
{
	public var content : W;
	public var title : Null<String>;
	public var layout : Null<IDetoxLayout>;

	public function new( content:W, ?title:String, ?layout:IDetoxLayout ) {
		NullArgument.throwIfNull(content);
		this.content = content;
		this.title = title;
		this.layout = layout;
	}

	override function executeResult( actionContext:ActionContext ) {
		// If layout is null, get a default one...
		if (layout==null) layout = getDefaultLayout();

		layout.contentContainer.empty().append( content );
		if (title!=null) layout.title = title;

		actionContext.response.contentType = "text/html";
		actionContext.response.write( '<!DOCTYPE html>' + layout.document.html() );

		return AsyncCallback.COMPLETED;
	}

	// TODO: move somewhere else?
	public static var defaultLayout:IDetoxLayout;
	static function getDefaultLayout() {
		if (defaultLayout==null) defaultLayout = new DefaultDetoxLayout();
		return defaultLayout;
	}
}