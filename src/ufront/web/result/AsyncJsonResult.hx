package ufront.web.result;
import ufront.web.context.ActionContext;
import ufront.web.result.JsonResult;

using tink.CoreApi;
/**
 * ...
 * @author Kevin
 */
class AsyncJsonResult<T> extends JsonResult<T>
{
	private var futureContent:Future<T>;
	
	public function new(futureContent:Future<T>) {
		this.futureContent = futureContent;
		super(null);
	}
	
	override function executeResult(actionContext:ActionContext) {
		return futureContent.flatMap(function(content) {
			this.content = content;
			return writeContentToResponse(actionContext);
		});
	}
	
}