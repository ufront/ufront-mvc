package ufront.web.result;
import haxe.Json;
import thx.error.NullArgument;
import ufront.web.context.ActionContext;
import ufront.core.AsyncTools;
import tink.CoreApi;

/**
An `ActionResult` that sends a JSON response to the client.

The response content type will be set to `application/json`, and `Json.stringify` will be used to generate the JSON representation of the data.
**/
class JsonResult<T> extends ActionResult
{
	/** The content to be serialized. **/
	public var content:T;

	public function new( content:T ) {
		this.content = content;
	}

	override function executeResult( actionContext:ActionContext ) {
		NullArgument.throwIfNull(actionContext);
		NullArgument.throwIfNull(content);
		var serialized = Json.stringify( content );
		actionContext.httpContext.response.write( serialized );
		actionContext.httpContext.response.contentType = "application/json";
		return SurpriseTools.success();
	}
}
