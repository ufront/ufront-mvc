package ufront.web.result;

import haxe.io.Bytes;
import hxevents.Async;
import ufront.web.context.ActionContext;

class BytesResult extends FileResult
{
	/** The bytes of the file to be written to the response **/
	public var bytes : Bytes;

	public function new(?bytes : Bytes, ?contentType : String, ?fileDownloadName) {
		super(contentType, fileDownloadName);
		this.bytes = bytes;
	}
	
	override function executeResult( actionContext:ActionContext, async:Async ) {
		super.executeResult(actionContext, new Async(function (){ 
			actionContext.response.writeBytes(bytes, 0, bytes.length);
			async.completed(); 
		}, async.error));
	}
}