package ufront.web.result;
import haxe.Json;
import thx.error.NullArgument;
import ufront.web.context.ActionContext;
import ufront.core.Futuristic;
import tink.CoreApi;

/**
An `ActionResult` that sends a JSON response to the client.

The response content type will be set to `application/json`, and `Json.stringify` will be used to generate the JSON representation of the data.

`JsonResult` uses `Futuristic` for its content, meaning it can work with either synchronous content or asynchronous content.
**/
class JsonResult<T> extends ActionResult
{
	/** A `Future` containing the content to be serialized. **/
	public var contentFuture:Future<T>;

	public function new( content:Futuristic<T> ) {
		this.contentFuture = content;
	}

	override function executeResult( actionContext:ActionContext ) {
		NullArgument.throwIfNull(actionContext);
		NullArgument.throwIfNull(contentFuture);
		return contentFuture.map(function (content) {
			var serialized = Json.stringify( content );
			actionContext.httpContext.response.write( serialized );
			actionContext.httpContext.response.contentType = "application/json";
			return Success(Noise);
		});
	}
}
