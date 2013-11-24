package ufront.web.result;

import haxe.io.Bytes;
import thx.error.NullArgument;
import ufront.web.context.ActionContext;
import ufront.core.Sync;

/** Represents a base class that is used to send binary file content to the response. **/
class FileResult extends ActionResult
{
	/** Gets the content type to use for the response. **/
	public var contentType:String;

	/** 
		Gets or sets the content-disposition header so that a file-download dialog box is displayed in the browser with the specified file name. 

		Setting a non-null value will set the `content-disposition` to `attachment`, which will force the file to be downloaded
	**/
	public var fileDownloadName:String;
	
	function new( contentType:String, fileDownloadName:String ) {
		this.contentType = contentType;
		this.fileDownloadName = fileDownloadName;
	}
	
	override function executeResult( actionContext:ActionContext ) {
		NullArgument.throwIfNull( actionContext );

		if( null!=contentType )
			actionContext.response.contentType = contentType;
		
		if( null!=fileDownloadName )
			actionContext.response.setHeader( "content-disposition", 'attachment; filename=$fileDownloadName' );

		return Sync.success();
	}
}