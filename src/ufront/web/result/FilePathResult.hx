package ufront.web.result;

import haxe.io.Bytes;
import haxe.io.Eof;
import sys.io.File;
import ufront.web.context.ActionContext;

/**  Sends the contents of a file to the response.  */
class FilePathResult extends FileResult
{
	static var BUF_SIZE = 4096;

	/** Gets or sets the path of the file that is sent to the response. */
	public var fileName:String;
	
	public function new( ?fileName:String, ?contentType:String, ?fileDownloadName:String )
	{
		super( contentType, fileDownloadName );
		this.fileName = fileName;
	}

	override function executeResult( actionContext:ActionContext ) {
		super.executeResult( actionContext );
		if ( null!=fileName ) {
			var reader = File.read( fileName, true );
			try {
				var buf = Bytes.alloc( BUF_SIZE );
				var size = reader.readBytes( buf, 0, BUF_SIZE );
				actionContext.response.writeBytes( buf, 0, size );
			} catch (e:Eof) { }
		}
	}
}