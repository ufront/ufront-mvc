package ufront.web.result;

import ufront.view.TemplateData;
import ufront.view.TemplatingEngines.TemplatingEngine;
import ufront.web.context.ActionContext;
import ufront.web.result.ViewResult;

using tink.CoreApi;

/**
 * ...
 * @author Kevin
 */
class AsyncViewResult extends ViewResult
{
	private var futureData:Future<TemplateData>;
	
	public function new(?futureData:Future<TemplateData>, ?viewPath:String, ?templatingEngine:TemplatingEngine) {
		this.futureData = futureData;
		super(null, viewPath, templatingEngine);
	}
	
	override function executeResult(actionContext:ActionContext) {
		return futureData.flatMap(function(data)
		{
			this.data = data;
			return internalExecuteResult(actionContext);
		});
	}
}