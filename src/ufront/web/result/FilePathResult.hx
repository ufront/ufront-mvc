package ufront.web.result;

import haxe.io.Bytes;
import haxe.io.Eof;
import sys.io.File;
import ufront.web.context.ActionContext;
import ufront.core.Sync;
using haxe.io.Path;

/**  Sends the contents of a file to the response.  */
class FilePathResult extends FileResult
{
	static var BUF_SIZE = 4096;


	static var extMap = [
		// Just copied image mime types for now.  
		// @todo: add complete list from http://en.wikipedia.org/wiki/Internet_media_type#List_of_common_media_types
		"jpg" => "image/jpeg",
		"jpeg" => "image/jpeg",
		"png" => "image/png",
		"gif" => "image/gif",
		"svg" => "image/svg+xml",
		"tiff" => "image/tiff",
	];

	/** Gets or sets the path of the file that is sent to the response. */
	public var fileName:String;
	
	/**
		@param fileName - absolute path to the file to be sent in response.  If null, no content is written to the response.
		@param contentType - Internet Media Type to use.  If null, it will be inferred from the extension of 'fileName' (only image types supported at the moment).  If this fails, "text/html" will be used.
		@param fileDownloadName - file name to display to the client.  Default is null.  If non-null value is supplied, the file will be forced as a download to the client.
	**/
	public function new( ?fileName:String, ?contentType:String, ?fileDownloadName:String ) {
		if ( contentType==null ) {
			var ext = fileName.extension();
			if ( extMap.exists(ext) ) contentType = extMap[ext];
			else contentType = "text/html";
		}

		super( contentType, fileDownloadName );
		this.fileName = fileName;
	}

	override function executeResult( actionContext:ActionContext ) {
		super.executeResult( actionContext );
		if ( null!=fileName ) {
			try {
				var bytes = File.getBytes( fileName );
				actionContext.response.writeBytes( bytes, 0, bytes.length );
				return Sync.success();
			} catch (e:Dynamic) {
				return Sync.httpError( 'Failed to read $fileName: $e' );
			}
		}
		return Sync.success();
	}
}