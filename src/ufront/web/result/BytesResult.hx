package ufront.web.result;

import haxe.io.Bytes;

class BytesResult extends FileResult
{
	/** The bytes of the file to be written to the response **/
	public var bytes : Bytes;

	public function new(?bytes : Bytes, ?contentType : String, ?fileDownloadName) {
		super(contentType, fileDownloadName);
		this.bytes = bytes;
	}
	
	override function executeResult( actionContext:ActionContext ) {
		super.executeResult(actionContext);
		actionContext.response.writeBytes(bytes, 0, bytes.length);
	}
}