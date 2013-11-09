package ufront.web.upload;

import haxe.io.Bytes;

/**
	Interface for defining a new Http file upload handler

	TODO: more documentation
	
	@author Franco Ponticelli
**/
interface UFHttpUploadHandler
{
	public function uploadStart(name : String, filename : String) : Void;
	public function uploadProgress(bytes : Bytes, pos : Int, len : Int) : Void;
	public function uploadEnd() : Void;
}