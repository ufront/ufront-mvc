package ufront.web.upload;

import haxe.io.*;
import sys.io.*;
import sys.FileSystem;
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
class TmpFileUpload extends BaseUpload implements UFFileUpload {

	/** The path to the temporary file where the upload is being stored **/
	var tmpFileName:String;

	/**
	Create a new `TempFileUploadSync`.

	It should already be saved to a temporary file by `TmpFileUploadMiddleware` when this object is created.

	Please note that `originalFileName` will be sanitised using `haxe.io.Path.withoutDirectory()`.
	**/
	public function new( tmpFileName:String, postName:String, originalFileName:String, size:Int, ?contentType:String ) {
		super( postName, originalFileName.withoutDirectory(), size, contentType );
		this.tmpFileName = tmpFileName;
	}

	/** Get the complete `Bytes` of the current upload. **/
	public function getBytes():Surprise<Bytes,Error> {
		if ( this.attachedUpload!=null )
			return this.attachedUpload.getBytes();

		try {
			return Success( File.getBytes(tmpFileName) ).asFuture();
		}
		catch ( e:Dynamic ) return Failure( HttpError.wrap(e,'Error during TmpFileUpload.getBytes()') ).asFuture();
	}

	/**
	Get the current upload as a `String`.
	Please note that `sys` platforms do ignore the "encoding" parameter, and will use the system default.
	**/
	public function getString( ?encoding:String="UTF-8" ):Surprise<String,Error> {
		if ( this.attachedUpload!=null )
			return this.attachedUpload.getString( encoding );

		try {
			return Success( File.getContent(tmpFileName) ).asFuture();
		}
		catch ( e:Dynamic ) return Failure( HttpError.wrap(e,"Error during TmpFileUpload.getString()") ).asFuture();
	}

	/**
	Write the current upload to a file on the filesystem.
	**/
	public function writeToFile( newFilePath:String ):Surprise<Noise,Error> {
		if ( this.attachedUpload!=null )
			return this.attachedUpload.writeToFile( newFilePath );

		try {
			File.copy( tmpFileName, newFilePath );
			return SurpriseTools.success();
		}
		catch ( e:Dynamic ) return Failure( HttpError.wrap(e,"Error during TmpFileUpload.writeToFile()") ).asFuture();
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
		if ( this.attachedUpload!=null )
			return this.attachedUpload.process( onData, partSize );

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
					var surprise:Surprise<Noise,Error>;
					try {
						var bytes = fh.read( partSize ) ;
						surprise = onData( bytes, pos, bytes.length );
					}
					catch ( e:Eof ) {
						final = true;
						var bytes = fh.readAll( partSize );
						surprise = onData( bytes, pos, bytes.length );
					}
					catch ( e:Dynamic ) {
						surprise = Failure( HttpError.wrap(e,'Error during TmpFileUpload.process') ).asFuture();
					}
					surprise.handle(function(outcome) switch outcome {
						case Success(_):
							if ( final==false ) {
								pos += partSize;
								readNext();
							}
							else {
								doneTrigger.trigger( Success(Noise) );
							}
						case Failure(err):
							doneTrigger.trigger( Failure(err) );
					});

				}
				readNext();

				return doneTrigger.asFuture();
			}
			catch ( e:Dynamic ) return Failure( HttpError.wrap(e,"Error during TmpFileUpload.process()") ).asFuture();
		#else
			return throw HttpError.notImplemented();
		#end
	}

	/**
	Delete the temporary file.

	After doing this, other functions that rely on the temporary file will no longer work.
	**/
	public function deleteTemporaryFile():Outcome<Noise,Error> {
		try {
			FileSystem.deleteFile( tmpFileName );
			return Success( Noise );
		}
		catch ( e:Dynamic ) return Failure( HttpError.wrap(e,"Error during TmpFileUpload.deleteTmpFile()") );
	}
}
