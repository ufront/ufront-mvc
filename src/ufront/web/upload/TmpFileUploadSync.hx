package ufront.web.upload;

import haxe.io.Bytes;
import haxe.io.Eof;
#if sys
	import sys.FileSystem;
	import sys.io.File;
#end
import ufront.web.upload.FileUpload;
import ufront.core.Sync;
using tink.CoreApi;
using haxe.io.Path;

/**
	A FileUpload implementation that works on `SYS` platforms (Neko, PHP etc).

	All methods are performed synchronously, but work with the async interface.
**/
class TmpFileUploadSync implements FileUpload {

	/** The name of the POST argument (that is, the name of the file input) that this file was uploaded with. **/
	public var postName:String;

	/** The original name of this file on the client. **/
	public var originalFileName:String;

	/** The size of the upload in Bytes **/
	public var size:Int;

	/**
		The contentType of the upload.

		Please note this is not verified, so do not rely on this for security.
	**/
	// Commenting out for now until I find a way to get this information on neko
	// public var contentType:String;

	/** The path to the temporary file where the upload is being stored **/
	var tmpFileName:String;

	/**
		Create a new TempFileUploadSync

		Please note that "originalFileName" will be sanitised using `haxe.io.Path.withoutDirectory()`.
	**/
	public function new( tmpFileName:String, postName:String, originalFileName:String, size:Int ) {
		this.postName = postName;
		this.originalFileName = originalFileName.withoutDirectory();
		this.size = size;
		this.tmpFileName = tmpFileName;
	}

	/**
		Get the current upload as a `haxe.io.Bytes`

		Uses `sys.io.File.getBytes(tmpFileName)` behind the scenes.
	**/
	public function getBytes():Surprise<Bytes,Error> {
		#if sys
			try {
				return Sync.of( Success(File.getBytes(tmpFileName)) );
			}
			catch ( e:Dynamic ) return Sync.of( Failure(Error.withData("Error during SyncFileUpload.getBytes()",e)) );
		#else
			return throw "Not implemented";
		#end
	}

	/**
		Get the current upload as a `String`

		Uses `sys.io.File.getContent(tmpFileName)` behind the scenes.
	**/
	public function getString():Surprise<String,Error> {
		#if sys
			try {
				return Sync.of( Success(File.getContent(tmpFileName)) );
			}
			catch ( e:Dynamic ) return Sync.of( Failure(Error.withData("Error during SyncFileUpload.getString()",e)) );
		#else
			return throw "Not implemented";
		#end
	}

	/**
		Write the current upload to a file on the filesystem.

		Uses `sys.io.File.copy( tmpFileName, newFilePath )` behind the scenes.
	**/
	public function writeToFile( newFilePath:String ):Surprise<Noise,Error> {
		#if sys
			try {
				File.copy(tmpFileName, newFilePath);
				return Sync.success();
			}
			catch ( e:Dynamic ) return Sync.of( Failure(Error.withData("Error during SyncFileUpload.writeToFile()",e)) );
		#else
			return throw "Not implemented";
		#end
	}

	/**
		A method for streaming data to a specified method.

		Will read the temporary file from the disk, one part at a time.
		Each part that is read will be passed to the "onData" function.
		Once `onData`'s future is resolved, the next part will be written.

		@param onData - method to execute for each set, eg. `function onData(data:Bytes, pos:Int, length:Int):Surprise<Noise,Error>`
		@param partSize - the maximum amount of data to stream in each part.  Default is 8KB for PHP, 16KB for other targets.
		@return a future to notify you once all the data has been processed, or if an error occured at any point.
	**/
	public function process( onData:Bytes->Int->Int->Surprise<Noise,Error>, ?partSize:Null<Int> ):Surprise<Noise,Error> {
		#if sys
			try {
				if( partSize == null ) {
					#if php partSize = 8192; // default value for PHP and max under certain circumstances
					#else partSize = (1 << 14); // 16 KB 
					#end
				}
				var doneTrigger = Future.trigger();

				var fh = File.read( tmpFileName );
				var pos = 0;
				function readNext() {
					var final = false;
					var bytes:Bytes;
					try {
						bytes = fh.read( partSize ) ;
					}
					catch ( e:Eof ) {
						final = true;
						bytes = fh.readAll( partSize );
					}
					onData( bytes, pos, bytes.length );

					if ( final==false ) {
						pos += partSize;
						readNext();
					}
					else {
						doneTrigger.trigger( Success(Noise) );
					}
				}
				readNext();

				return doneTrigger.asFuture();
			}
			catch ( e:Dynamic ) return Sync.of( Failure(Error.withData("Error during SyncFileUpload.process()",e)) );
		#else
			return throw "Not implemented";
		#end
	}

	/**
		Delete the temporary file.  

		After doing this, other functions that rely on the temporary file will no longer work.
	**/
	public function deleteTemporaryFile():Outcome<Noise,Error> {
		#if sys
			try {
				FileSystem.deleteFile(tmpFileName);
				return Success( Noise );
			}
			catch ( e:Dynamic ) return Failure( Error.withData("Error during SyncFileUpload.deleteTmpFile()",e) );
		#else
			throw "Not implemented";
		#end
	}
}
