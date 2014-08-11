package ufront.web.upload;

#if sys
	import sys.io.File;
	import sys.FileSystem;
	import sys.io.FileOutput;
	import ufront.sys.SysUtil;
#end
import ufront.web.context.HttpContext;
import ufront.app.UFMiddleware;
import ufront.app.HttpApplication;
import tink.CoreApi;
import ufront.web.upload.TmpFileUploadSync;
import ufront.core.Sync;
using haxe.io.Path;
using Dates;

/**
	If the HttpRequest is multipart, parse it, and store any uploads in a temporary file, adding them to `httpRequest.files`

	Any post variables encountered in the multipart will be added to `httpRequest.post`.

	This middleware will need to be called before `httpRequest.post` or `httpRequest.params` is ever accessed.
	It is probably wise to run this as your very first middleware.

	The response middleware will delete the temporary file at the end of the request.

	@author Jason O'Neil
**/
class TmpFileUploadMiddleware implements UFMiddleware
{
	/**
		Sub-directory to save temporary uploads to.

		This should represent a path, relative to `context.contentDirectory`.

		Default is "uf-upload-tmp"
	**/
	public static var subDir:String = "uf-upload-tmp";

	var files:Array<TmpFileUploadSync>;

	public function new() {
		files = [];
	}

	/**
		Start the session if a SessionID exists in the request, or if `alwaysStart` is true.

		If the chosen `subDir` does not exist, it will attempt to create it, but only one level deep - it will not recursively create directories for you.
	**/
	public function requestIn( ctx:HttpContext ):Surprise<Noise,Error> {

		if ( ctx.request.httpMethod.toLowerCase()=="post" && ctx.request.isMultipart() ) {
			#if sys
				var file:FileOutput = null,
					postName:String = null,
					origFileName:String = null,
					size:Int = 0,
					tmpFilePath:String = null,
					dateStr = Date.now().format( "%Y%m%d-%H%M" ),
					dir = ctx.contentDirectory+subDir.addTrailingSlash();

				SysUtil.mkdir( dir );

				function onPart( pName, fName ) {
					// Start writing to a temp file
					postName = pName;
					origFileName = fName;
					size = 0;
					while ( file==null ) {
						tmpFilePath = dir+dateStr+"-"+Random.string(10)+".tmp";
						#if sys
							if ( !FileSystem.exists(tmpFilePath) ) {
								file = File.write( tmpFilePath );
							}
						#else
							throw "Not implemented";
						#end
					}
					return Sync.success();
				}
				function onData( bytes, pos, len ) {
					// Write this chunk
					size += len;
					file.writeBytes( bytes, pos, len );
					return Sync.success();
				}
				function onEndPart() {
					// Close the file, create our FileUpload object and add it to the request
					if ( file!=null ) {
						file.close();
						var tmpFile = new TmpFileUploadSync( tmpFilePath, postName, origFileName, size );
						ctx.request.files.add( postName, tmpFile );
						files.push( tmpFile );
					}
					return Sync.success();
				}
				return
					ctx.request.parseMultipart( onPart, onData, onEndPart )
					.map( function(result) {
						switch result {
						case Success(s): return Success( s );
						case Failure(f): return Failure( HttpError.wrap(f) );
					}
					});
			#else
				return throw "Not implemented";
			#end
		}
		else return Sync.success();
	}

	/**
		Delete the temporary file at the end of the request
	**/
	public function responseOut( ctx:HttpContext ):Surprise<Noise,Error> {
		if ( ctx.request.httpMethod.toLowerCase()=="post" && ctx.request.isMultipart() ) {
			var errors = [];
			for ( f in files ) {
				switch f.deleteTemporaryFile() {
					case Failure( e ): errors.push( e );
					default:
				}
			}
			if ( errors.length>0 )
				return Sync.httpError( "Failed to delete one or more temporary upload files", errors );
		}
		return Sync.success();
	}
}
