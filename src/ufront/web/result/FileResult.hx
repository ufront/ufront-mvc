package ufront.web.result;

import haxe.io.Bytes;
import hxevents.Async;
import thx.error.NullArgument;
import ufront.web.context.ActionContext;

/** Represents a base class that is used to send binary file content to the response. **/
class FileResult extends ActionResult
{
	/** Gets the content type to use for the response. **/
	public var contentType : String;

	/** Gets or sets the content-disposition header so that a file-download dialog box is displayed in the browser with the specified file name. **/
	public var fileDownloadName : String;
	
	function new(contentType : String, fileDownloadName : String) {
		this.contentType = contentType;
		this.fileDownloadName = fileDownloadName;
	}
	
	override function executeResult( actionContext:ActionContext, async:Async ) {
		NullArgument.throwIfNull(actionContext);

		if(null != contentType)
			actionContext.response.contentType = contentType;
		
		if(null != fileDownloadName)
			actionContext.response.setHeader("content-disposition", "attachment; filename=" + fileDownloadName);

		async.completed();
	}
}