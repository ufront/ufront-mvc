package ufront.web.result;

import haxe.io.Bytes;
import ufront.web.context.ActionContext;
import ufront.core.Sync;

class BytesResult extends FileResult
{
	/** The bytes of the file to be written to the response **/
	public var bytes:Bytes;

	public function new( ?bytes:Bytes, ?contentType:String, ?fileDownloadName:String ) {
		super(contentType, fileDownloadName);
		this.bytes = bytes;
	}
	
	override function executeResult( actionContext:ActionContext ) {
		super.executeResult(actionContext);
		actionContext.httpContext.response.writeBytes(bytes, 0, bytes.length);
		return Sync.success();
	}
}