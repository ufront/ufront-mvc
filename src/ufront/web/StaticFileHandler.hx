package ufront.web;

import ufront.app.UFRequestHandler;
import ufront.web.context.HttpContext;

#if server
import sys.FileSystem;
import sys.io.File;
#end

using haxe.io.Path;
using ufront.core.AsyncTools;
using tink.CoreApi;

class StaticFileHandler implements UFRequestHandler {
	
	var directory:String;
	
	public function new(?directory:String) {
		this.directory = directory;
	}
	
	public function handleRequest( ctx:HttpContext ):Surprise<Noise,Error> {

#if server
		if(directory == null) directory = ctx.request.scriptDirectory;
		
		var path = Path.join([directory, ctx.request.uri]);
		
		if(ctx.request.httpMethod != 'GET' || !FileSystem.exists(path)) return SurpriseTools.success();
		if(FileSystem.isDirectory(path)) return SurpriseTools.success(); // TODO: serve index files
		
		var bytes = File.getBytes(path);
		ctx.response.writeBytes(bytes, 0, bytes.length); // TODO: set content-type
		ctx.response.contentType = getMime(path);
		ctx.completion.set(CRequestHandlersComplete);
#end

		return SurpriseTools.success();
	}
	
	// TODO: complete the list (and move this to a separate library)
	function getMime(path:String)
	{
		return switch path.extension().toLowerCase() {
			case 'ico': 'image/x-icon';
			case 'png': 'image/png';
			case 'jpg' | 'jpeg': 'image/jpeg';
			case 'htm' | 'html': 'text/html';
			case 'txt': 'text/plain';
			case _: null;
		}
	}
	
	public function toString() return "ufront.web.StaticFileHandler";
}