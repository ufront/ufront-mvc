package ufront.web.result;
import haxe.Json;
import ufront.web.HttpError;
import ufront.web.context.ActionContext;
import ufront.core.AsyncTools;
import tink.CoreApi;

/**
An `ActionResult` that sends a JSON response to the client.

The response content type will be set to `application/json`, and `Json.stringify` will be used to generate the JSON representation of the data.
**/
class JsonResult<T> extends ActionResult {

	/**
	A shortcut to create a Json Result.

	This is useful when you are waiting for a Future: `return getFutureData() >> JsonResult.create;`.
	**/
	public static function create<T>( data:T ):JsonResult<T> return new JsonResult( data );

	/** The content to be serialized. **/
	public var content:T;

	public function new( content:T ) {
		HttpError.throwIfNull( content, "content" );
		this.content = content;
	}

	override function executeResult( actionContext:ActionContext ) {
		HttpError.throwIfNull(actionContext, "actionContext" );
		var serialized = Json.stringify( content );
		actionContext.httpContext.response.write( serialized );
		actionContext.httpContext.response.contentType = "application/json";
		return SurpriseTools.success();
	}
}
