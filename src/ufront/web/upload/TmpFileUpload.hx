package ufront.web.upload;

import haxe.io.*;
#if sys
	import sys.io.*;
	import sys.FileSystem;
#end
import ufront.web.HttpError;
import ufront.web.upload.UFFileUpload;
using ufront.core.AsyncTools;
using tink.CoreApi;
using haxe.io.Path;

/**
A `FileUpload` implementation that allows you to operate on an upload that has been saved to a temporary file.

`TmpFileUpload` is designed to work with `TmpFileUploadMiddleware`.
This middleware currently does not support reading `contentType`.

It is currently only implemented on `sys` platforms.

**/
class TmpFileUpload implements UFFileUpload {

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
	public var contentType:Null<String>;

	/** The path to the temporary file where the upload is being stored **/
	var tmpFileName:String;

	/**
	Create a new `TempFileUploadSync`.

	It should already be saved to a temporary file by `TmpFileUploadMiddleware` when this object is created.

	Please note that `originalFileName` will be sanitised using `haxe.io.Path.withoutDirectory()`.
	**/
	public function new( tmpFileName:String, postName:String, originalFileName:String, size:Int, ?contentType:String ) {
		this.postName = postName;
		this.originalFileName = originalFileName.withoutDirectory();
		this.size = size;
		this.tmpFileName = tmpFileName;
		this.contentType = contentType;
	}

	/** Get the complete `Bytes` of the current upload. **/
	public function getBytes():Surprise<Bytes,Error> {
		#if sys
			try {
				return Success(File.getBytes(tmpFileName)).asFuture();
			}
			catch ( e:Dynamic ) return Failure(Error.withData("Error during TmpFileUpload.getBytes()",e)).asFuture();
		#else
			return throw HttpError.notImplemented();
		#end
	}

	/**
	Get the current upload as a `String`.
	Please note that `sys` platforms do ignore the "encoding" parameter, and will use the system default.
	**/
	public function getString( ?encoding:String="UTF-8" ):Surprise<String,Error> {
		#if sys
			try {
				return Success(File.getContent(tmpFileName)).asFuture();
			}
			catch ( e:Dynamic ) return Failure(Error.withData("Error during TmpFileUpload.getString()",e)).asFuture();
		#else
			return throw HttpError.notImplemented();
		#end
	}

	/**
	Write the current upload to a file on the filesystem.
	**/
	public function writeToFile( newFilePath:String ):Surprise<Noise,Error> {
		#if sys
			try {
				File.copy(tmpFileName, newFilePath);
				return SurpriseTools.success();
			}
			catch ( e:Dynamic ) return Failure(Error.withData("Error during TmpFileUpload.writeToFile()",e)).asFuture();
		#else
			return throw HttpError.notImplemented();
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
			catch ( e:Dynamic ) return Failure(Error.withData("Error during TmpFileUpload.process()",e)).asFuture();
		#else
			return throw HttpError.notImplemented();
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
			catch ( e:Dynamic ) return Failure( Error.withData("Error during TmpFileUpload.deleteTmpFile()",e) );
		#else
			throw HttpError.notImplemented();
		#end
	}
}
