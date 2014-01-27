package ufront.web.upload;

import haxe.io.Bytes;
import ufront.web.context.HttpContext;
using tink.CoreApi;

/**
	Interface for defining a new Http file upload handler.

	A `UFHttpUploadHandler` allows you to read a file that was uploaded during the HTTPRequest, usually through a `<form method="POST" enctype="multipart/form-data">`.

	It is utilized by using the `setUploadHandler()` method of the current `ufront.web.context.HttpRequest`.  
	When you do this, the `HttpRequest` object will parse the "multipart/form-data" data and any file uploads it encounters will be sent to this upload handler.

	Only one upload is processed at a time, so it is safe to assume that `uploadStart` will be called first, followed by one or more runs of `uploadProgress`, and finishing with `uploadEnd`.
	The `HttoRequest` will ensure only one method (`uploadStart`, `uploadProgress` or `uploadEnd`) is ever running at a time.

	If you never call `setUploadHandler()` on the request, the uploaded files are ignored.  
	Multipart data will still be parsed and any "POST" parameters set accordingly, but files will not be processed.

	See `ufront.web.upload.SaveToDirectoryUploadHandler` for an example implementation.
	
	@author Franco Ponticelli
**/
interface UFHttpUploadHandler
{
	/**
		`uploadStart` is called by the `HttpRequest` when we begin processing a new upload.

		This is not intended to be called manually.

		This is the same signiature as `neko.Web.parseMultipart()`'s `onPart` argument.

		@param name - the parameter name in the HTTP request
		@param filename - the original filename of the upload
		@return Surprise<Noise,Error> - has this step finished, did it succeeed?
	**/
	public function uploadStart(context:HttpContext, name:String, filename:String):Surprise<Noise,Error>;
	
	/**
		`uploadProgress` is called by the `HttpRequest` as many times as required until all the upload data has been processed.

		This is not intended to be called manually.

		This is the same signiature as `neko.Web.parseMultipart()`'s `onData` argument.

		@param bytes - this bytes in this segment
		@param pos - ??? On PHP, this will always be 0.  On Neko, it is the same as `neko.Web.
		@param len
		@return Surprise<Noise,Error> - has this step finished, did it succeed?
	**/
	public function uploadProgress(bytes:Bytes, pos:Int, len:Int):Surprise<Noise,Error>;

	/**
		`uploadStart` is called by the `HttpRequest` when we begin processing a new upload.

		This is not intended to be called manually.

		@return Surprise<Noise,Error>
	**/
	public function uploadEnd():Surprise<Noise,Error>;
}