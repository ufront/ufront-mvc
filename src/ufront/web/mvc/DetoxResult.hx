package ufront.web.mvc;
import thx.error.NullArgument;
import ufront.web.mvc.ActionResult;
import ufront.web.mvc.ControllerContext;

using Detox;
import detox.DetoxLayout;

class DetoxResult extends ActionResult
{
	public static var defaultLayout : DetoxLayout;

	public var view : DOMCollection;
	public var layout : DetoxLayout;
	
	public function new(?view : DOMCollection, ?layout : DetoxLayout)
	{
		this.view = view;
		this.layout = (layout != null) ? layout : defaultLayout;
	}
	
	override function executeResult(controllerContext : ControllerContext)
	{
		NullArgument.throwIfNull(controllerContext);
		NullArgument.throwIfNull(layout);

		layout.content = view;
		
		controllerContext.response.contentType = "text/html";
		controllerContext.response.write(layout.html());
	}
}