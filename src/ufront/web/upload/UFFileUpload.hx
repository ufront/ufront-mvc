package ufront.web.upload;

import haxe.io.Bytes;
import haxe.io.Input;

using tink.CoreApi;

/**
An interface for working with uploaded files.

Each platform can respond to file uploads differently.
For example, PHP stores temp files for each request, mod_neko has a callback for processing multitype data, and NodeJS will have it's own async methods.
If you are using a cloud based storage container, your processes will be different again.

This interface aims to provide a safe abstraction for working with uploaded files, no matter which platform or technology.
**/
interface UFFileUpload {

	/** The name of the POST argument (that is, the name of the file input) that this file was uploaded with. **/
	var postName:String;

	/** The original file name of this upload. **/
	var originalFileName:String;

	/** The size of the upload in Bytes. **/
	var size:Int;

	/**
	The contentType of the upload.

	Please note this is not verified, and the value may not even be available depending on the platform / implementation.
	**/
	var contentType:Null<String>;

	/** Get the complete `Bytes` of the current upload. **/
	function getBytes():Surprise<Bytes,Error>;

	/**
	Get the complete `String` of the current upload.
	Optionally specify an encoding to use.
	Please note not all platforms or implementations support setting the encoding, so please use with care.
	**/
	function getString( ?encoding:String ):Surprise<String,Error>;

	/**
	Write the current upload to a file on the filesystem.
	This may not be supported on some platforms (such as client-side JS), in which case it will return an error.
	**/
	function writeToFile( filePath:String ):Surprise<Noise,Error>;

	/**
	A method for streaming data to a specified method.

	@param onData - method to execute for each set, eg. `function onData(data:Bytes, pos:Int, length:Int):Surprise<Noise,Error>`
	@param partSize - the maximum amount of data to stream in each part.  Optional, default depends on FileUpload implementation.
	**/
	function process( onData:Bytes->Int->Int->Surprise<Noise,Error>, ?partSize:Null<Int> ):Surprise<Noise,Error>;
}
