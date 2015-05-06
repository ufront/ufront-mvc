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
	private var asyncData:Future<TemplateData>;
	
	public function new(?asyncData:Future<TemplateData>, ?viewPath:String, ?templatingEngine:TemplatingEngine) 
	{
		this.asyncData = asyncData;
		super(null, viewPath, templatingEngine);
	}
	
	override function executeResult(actionContext:ActionContext) 
	{
		return asyncData.flatMap(function(data)
		{
			this.data = data;
			return internalExecuteResult(actionContext);
		});
	}
}