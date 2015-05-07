package ufront.web.result;
import haxe.Json;
import thx.core.error.NullArgument;
import ufront.web.context.ActionContext;
import ufront.core.Sync;

/** Represents a class that is used to send JSON-formatted content to the response. */
class JsonResult<T> extends ActionResult
{
	/** The content to be serialized **/
	public var content : T;
	public var allowOrigin : String;

	public function new( content:T ) {
		this.content = content;
	}

	override function executeResult( actionContext:ActionContext ) {
		return writeContentToResponse(actionContext);
	}
	
	private function writeContentToResponse(actionContext:ActionContext) {
		NullArgument.throwIfNull(actionContext);
		actionContext.httpContext.response.contentType = "application/json";
		var serialized = Json.stringify( content );
		actionContext.httpContext.response.write( serialized );
		return Sync.success();
	}
}