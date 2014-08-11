package ufront.web.upload;

import haxe.io.Bytes;

using tink.CoreApi;

/**
	An interface describing an uploaded file.

	Each platform can respond to file uploads differently.
	For example, PHP stores temp files for each request, mod_neko has a callback for processing multitype data, and NodeJS will have it's own async methods.

	This interface aims to provide a safe abstraction for working with uploaded files, no matter which platform.
**/
interface FileUpload {

	/** The name of the POST argument (that is, the name of the file input) that this file was uploaded with. **/
	var postName:String;

	/** The original name of this file on the client. **/
	var originalFileName:String;

	/** The size of the upload in Bytes **/
	var size:Int;

	/**
		The contentType of the upload.

		Please note this is not verified, so do not rely on this for security.
	**/
	// Commenting out for now until I find a way to get this information on neko
	// var contentType:String;

	/** Get the current upload as a `haxe.io.Bytes` **/
	function getBytes():Surprise<Bytes,Error>;

	/** Get the current upload as a `String` **/
	function getString():Surprise<String,Error>;

	/** Write the current upload to a file on the filesystem **/
	function writeToFile( filePath:String ):Surprise<Noise,Error>;

	/**
		A method for streaming data to a specified method.

		@param onData - method to execute for each set, eg. `function onData(data:Bytes, pos:Int, length:Int):Surprise<Noise,Error>`
		@param partSize - the maximum amount of data to stream in each part.  Optional, default depends on FileUpload implementation.
	**/
	function process( onData:Bytes->Int->Int->Surprise<Noise,Error>, ?partSize:Null<Int> ):Surprise<Noise,Error>;
}
