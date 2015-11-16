package ufront.web.upload;

import haxe.io.*;
#if js
	import js.html.*;
#end
import ufront.web.HttpError;
import ufront.web.upload.UFFileUpload;
using ufront.core.AsyncTools;
using tink.CoreApi;
using haxe.io.Path;

/**
A `FileUpload` implementation that allows you to operate on an upload client side using HTML5 APIs.

See `js.html.File`, `js.html.FileReader`, `js.html.FileList` and <http://www.html5rocks.com/en/tutorials/file/dndfiles/> for more information.
**/
class BrowserFileUpload extends BaseUpload implements UFFileUpload {
	#if js
		/** The relevant `js.html.File` object for this upload. **/
		public var file:File;

		/**
		Create a new `BrowserFileUpload` with the relevant `js.html.File` object.
		**/
		public function new( postName:String, file:File ) {
			super( postName, file.name, file.size, file.type );
			this.file = file;
		}
	#end

	/** Get the complete `Bytes` of the current upload. **/
	public function getBytes():Surprise<Bytes,Error> {
		if ( this.attachedUpload!=null )
			return this.attachedUpload.getBytes();

		#if js
			var t = Future.trigger();
			var fr = new FileReader();
			fr.onload = function() {
				var binaryString:String = fr.result;
				var bytes = Bytes.ofString( binaryString );
				t.trigger( Success(bytes) );
			};
			fr.onabort = function(e) t.trigger( Failure(HttpError.internalServerError('Error during BrowserFileUpload.getBytes(), readAsBinaryString() was aborted')) );
			fr.onerror = function(e) t.trigger( Failure(HttpError.wrap(e,'Error during BrowserFileUpload.getBytes(), readAsBinaryString() raised an error')) );
			fr.readAsBinaryString( file );
			return t.asFuture();
		#else
			return throw 'BrowserFileUpload.getBytes() was used on a target other than JS';
		#end
	}

	/**
	Get the complete `String` of the current upload.
	Optionally specify an encoding to use, the default is UTF-8.
	**/
	public function getString( ?encoding:String="UTF-8" ):Surprise<String,Error> {
		if ( this.attachedUpload!=null )
			return this.attachedUpload.getString( encoding );

		#if js
			var t = Future.trigger();
			var fr = new FileReader();
			fr.onload = function() {
				var str:String = fr.result;
				t.trigger( Success(str) );
			};
			fr.onabort = function(e) t.trigger( Failure(HttpError.internalServerError('Error during BrowserFileUpload.getString(), readAsText() was aborted')) );
			fr.onerror = function(e) t.trigger( Failure(HttpError.wrap(e,'Error during BrowserFileUpload.getString(), readAsText() raised an error')) );
			fr.readAsText( file, encoding );
			return t.asFuture();
		#else
			return throw 'BrowserFileUpload.getString() was used on a target other than JS';
		#end
	}

	/**
	Not implemented, will throw an error.
	**/
	public function writeToFile( newFilePath:String ):Surprise<Noise,Error> {
		if ( this.attachedUpload!=null )
			return this.attachedUpload.writeToFile( newFilePath );

		return throw HttpError.notImplemented();
	}

	/**
	A method for streaming data to a specified method.

	This will use `js.html.File.slice()` to read one `js.html.Blob` at a time and process it.
	Each part that is read will be passed to the "onData" function.
	Once `onData`'s future is resolved, the next part will be written.

	@param onData - method to execute for each set, eg. `function onData(data:Bytes, pos:Int, length:Int):Surprise<Noise,Error>`
	@param partSize - the maximum amount of data to stream in each part.  Default is 16KB.
	@return a future to notify you once all the data has been processed, or if an error occured at any point.
	**/
	public function process( onData:Bytes->Int->Int->Surprise<Noise,Error>, ?partSize:Null<Int> ):Surprise<Noise,Error> {
		if ( this.attachedUpload!=null )
			return this.attachedUpload.process( onData, partSize );

		#if js
			if( partSize == null ) {
				partSize = (1 << 14); // 16 KB
			}

			var ft = Future.trigger();
			var pos = 0;
			function readNext() {
				var final = false;
				var surprise:Surprise<Noise,Error>;
				// Slice the current portion, and process it
				var blob = file.slice( pos, pos+partSize );
				var fr = new FileReader();
				fr.onload = function() {
					var binaryString:String = fr.result;
					var bytes = Bytes.ofString( binaryString );
					if ( bytes.length==0 )
						final = true;
					try {
						surprise = onData( bytes, pos, bytes.length );
					}
					catch ( e:Dynamic ) {
						surprise = Failure( HttpError.wrap(e,'Error during TmpFileUpload.process') ).asFuture();
					}
				};
				fr.onabort = function(e) surprise = Failure( HttpError.internalServerError('Error during BrowserFileUpload.process(), readAsBinaryString() was aborted') ).asFuture();
				fr.onerror = function(e) surprise = Failure( HttpError.wrap(e,'Error during BrowserFileUpload.process(), readAsBinaryString() raised an error') ).asFuture();
				fr.readAsBinaryString( blob );
				// Once processing has finished, see if there is any more
				surprise.handle(function(outcome) switch outcome {
					case Success(_):
						if ( final==false ) {
							pos += partSize;
							readNext();
						}
						else ft.trigger( Success(Noise) );
					case Failure(err):
						ft.trigger( Failure(err) );
				});

			}
			readNext();

			return ft.asFuture();
		#else
			return throw 'BrowserFileUpload.process() was used on a target other than JS';
		#end
	}
}
