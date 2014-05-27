package ufront.web.result;

#if server
	import sys.io.File;
	import sys.FileSystem;
#end
import haxe.io.Bytes;
import haxe.io.Eof;
import ufront.web.context.ActionContext;
import ufront.core.Sync;
using haxe.io.Path;

/**  Sends the contents of a file to the response.  */
class FilePathResult extends FileResult
{
	static var BUF_SIZE = 4096;

	/** Gets or sets the path of the file that is sent to the response. */
	public var fileName:String;
	
	/**
		@param fileName - absolute path to the file to be sent in response.  If null, no content is written to the response.
		@param contentType - Internet Media Type to use.  If null, it will be inferred from the extension of 'fileName' (only image types supported at the moment).  If this fails, it will remain null, and no header will be added.  In this situation the client tries to correctly guess the type of the file.
		@param fileDownloadName - file name to display to the client.  Default is null.  If non-null value is supplied, the file will be forced as a download to the client.
	**/
	public function new( ?fileName:String, ?contentType:String, ?fileDownloadName:String ) {
		super( contentType, fileDownloadName );
		this.fileName = fileName;
	}

	override function executeResult( actionContext:ActionContext ) {
		super.executeResult( actionContext );
		#if server
			if ( null!=fileName ) {
				if ( !FileSystem.exists(fileName) )
					throw HttpError.pageNotFound();

				try {
					var bytes = File.getBytes( fileName );
					actionContext.response.writeBytes( bytes, 0, bytes.length );
					return Sync.success();
				}
				catch (e:Dynamic) {
					throw HttpError.internalServerError( 'Failed to read file $fileName in FilePathResult: $e', e );
				}
			}
		#end
		return Sync.success();
	}
}
