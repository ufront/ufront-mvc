package ufront.web.upload;

import haxe.io.Bytes;

/**
	An empty implementation of a Http file upload handler

	This implementation ignores uploaded files.
	
	@author Franco Ponticelli
**/
class EmptyUploadHandler implements IHttpUploadHandler
{
	public function new(){}
	public function uploadStart(name : String, filename : String) : Void{}
	public function uploadProgress(bytes : Bytes, pos : Int, len : Int) : Void{}
	public function uploadEnd() : Void{}
}