package ufront.web.result;

import haxe.io.Bytes;
import ufront.web.context.ActionContext;
import ufront.core.AsyncTools;

/**
An `ActionResult` that writes `Bytes` (arbitrary binary content) to the client response.
**/
class BytesResult extends FileResult {
	/** The bytes of the file to be written to the response **/
	public var bytes:Bytes;

	/**
	@param bytes The bytes to write to the response.
	@param contentType The content type to specify. If not specified, it will be guessed from `fileDownloadName`, or left blank, in which case the client will guess the type.
	@param fileDownloadName The name of the file download. If set, it will force a download dialogue on the client, using the given `fileDownloadName` as the default filename.
	**/
	public function new( ?bytes:Bytes, ?contentType:String, ?fileDownloadName:String ) {
		super(contentType, fileDownloadName);
		this.bytes = bytes;
	}

	override function executeResult( actionContext:ActionContext ) {
		super.executeResult(actionContext);
		actionContext.httpContext.response.writeBytes(bytes, 0, bytes.length);
		return SurpriseTools.success();
	}
}
