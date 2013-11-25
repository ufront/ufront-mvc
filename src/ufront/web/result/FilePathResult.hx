package ufront.web.result;

#if server
	import sys.io.File;
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


	static var extMap = [
		// @todo: add complete list from http://en.wikipedia.org/wiki/Internet_media_type#List_of_common_media_types
		
		// Image
		"jpg" => "image/jpeg",
		"jpeg" => "image/jpeg",
		"png" => "image/png",
		"gif" => "image/gif",
		"svg" => "image/svg+xml",
		"tiff" => "image/tiff",

		// Application (not exhaustive)
		"zip" => "application/zip",
		"atom" => "application/atom+xml",
		"json" => "application/json",
		"js" => "application/javascript",
		"ogg" => "application/ogg",
		"pdf" => "application/pdf",
		"ps" => "application/postscript",
		"rdf" => "application/rdf",
		"rss" => "application/rss",
		"woff" => "application/woff",
		"xml" => "application/xml",
		"dtd" => "application/xml-dtd",
		"gz" => "application/gzip",
	];

	/** Gets or sets the path of the file that is sent to the response. */
	public var fileName:String;
	
	/**
		@param fileName - absolute path to the file to be sent in response.  If null, no content is written to the response.
		@param contentType - Internet Media Type to use.  If null, it will be inferred from the extension of 'fileName' (only image types supported at the moment).  If this fails, it will remain null, and no header will be added.  In this situation the client tries to correctly guess the type of the file.
		@param fileDownloadName - file name to display to the client.  Default is null.  If non-null value is supplied, the file will be forced as a download to the client.
	**/
	public function new( ?fileName:String, ?contentType:String, ?fileDownloadName:String ) {
		if ( contentType==null ) {
			var ext = fileName.extension();
			if ( extMap.exists(ext) ) contentType = extMap[ext];
		}

		super( contentType, fileDownloadName );
		this.fileName = fileName;
	}

	override function executeResult( actionContext:ActionContext ) {
		super.executeResult( actionContext );
		#if server
			if ( null!=fileName ) {
				try {
					var bytes = File.getBytes( fileName );
					actionContext.response.writeBytes( bytes, 0, bytes.length );
					return Sync.success();
				} catch (e:Dynamic) {
					return Sync.httpError( 'Failed to read $fileName: $e' );
				}
			}
		#end
		return Sync.success();
	}
}