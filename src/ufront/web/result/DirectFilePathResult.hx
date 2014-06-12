package ufront.web.result;

import haxe.io.Bytes;
import thx.error.NullArgument;
import ufront.web.context.ActionContext;
import ufront.core.Sync;
import ufront.web.HttpError;
#if sys
	import sys.FileSystem;
#end
using haxe.io.Path;
using StringTools;

/**
	Given a path to a file on the local system, pass onto the client either:

	- A redirect to the actual location of the file, if the file path is inside the `scriptDirectory` (and therefore accessible from the web), or
	- A FilePathResult, streaming the file's contents to the client.
**/
class DirectFilePathResult extends ActionResult
{
	/**
		The file that is to be sent to the client.
		If the file is inside the script directory, and therefore visible to the world, the result will be a redirect to the path's direct file.
		If the file is outside the script directory, and therefore not directly accessible, the file will be streamed via a FilePathResult.
		If this value is null during `executeResult` an exception will be thrown.
	**/
	public var filePath:String;

	/**
		@param filePath - absolute path to the file to be sent in response.
	**/
	public function new( ?filePath:String ) {
		this.filePath = filePath;
	}

	override function executeResult( actionContext:ActionContext ) {
		NullArgument.throwIfNull( actionContext );
		#if sys
			filePath = filePath.normalize();
			if ( !FileSystem.exists(filePath) ) {
				throw HttpError.pageNotFound();
			}
			var scriptDir = actionContext.httpContext.request.scriptDirectory;
			if ( filePath.startsWith(scriptDir) ) {
				var url = filePath.substr( scriptDir.removeTrailingSlashes().length );
				return new RedirectResult( url, true ).executeResult( actionContext );
			}
			else {
				var result = new FilePathResult( filePath );
				result.setContentTypeByFilename( filePath.withoutDirectory() );
				return result.executeResult( actionContext );
			}
		#else
			return throw "Not implemented on non sys platforms.";
		#end
	}
}
