package ufront.web.upload;

#if sys
	import sys.io.File;
	import sys.FileSystem;
	import sys.io.FileOutput;
#end
import ufront.web.context.HttpContext;
import ufront.app.UFMiddleware;
import ufront.app.HttpApplication;
import tink.CoreApi;
import ufront.web.upload.TmpFileUpload;
import ufront.core.AsyncTools;
using haxe.io.Path;
using DateTools;

/**
A middleware to take any file uploads, save them to a temporary file, and make them available to the `HttpRequest`.

If the `HttpRequest` is multipart, this will parse the multipart data and store any uploads in a temporary file, adding them to `HttpRequest.files`.

This middleware will need to be called before `HttpRequest.post` or `HttpRequest.params` are ever accessed.
It is probably wise to run this as your very first middleware.

The response middleware will delete the temporary file at the end of the request.

This is only available on `sys` platforms currently.

@author Jason O'Neil
**/
class TmpFileUploadMiddleware implements UFMiddleware {
	/**
	Sub-directory to save temporary uploads to.

	This should represent a path, relative to `context.contentDirectory`.
	If the chosen `subDir` does not exist, the middleware will attempt to create it during `this.requestIn`.

	Default is "uf-upload-tmp"
	**/
	public static var subDir:String = "uf-upload-tmp";

	var files:Array<TmpFileUpload>;

	public function new() {
		files = [];
	}

	/**
	If the request is a multipart POST request, use `HttpRequest.parseMultipart()` to save the uploads to temporary files.
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

				FileSystem.createDirectory( dir.removeTrailingSlashes() );

				function onPart( pName, fName ) {
					// Start writing to a temp file
					postName = pName;
					origFileName = fName;
					size = 0;
					while ( file==null ) {
						tmpFilePath = dir+dateStr+"-"+Random.string(10)+".tmp";
						if ( !FileSystem.exists(tmpFilePath) ) {
							file = File.write( tmpFilePath );
						}
					}
					return SurpriseTools.success();
				}
				function onData( bytes, pos, len ) {
					// Write this chunk
					size += len;
					file.writeBytes( bytes, pos, len );
					return SurpriseTools.success();
				}
				function onEndPart() {
					// Close the file, create our UFFileUpload object and add it to the request
					if ( file!=null ) {
						file.close();
						file = null;
						var tmpFile = new TmpFileUpload( tmpFilePath, postName, origFileName, size );
						ctx.request.files.add( postName, tmpFile );
						files.push( tmpFile );
					}
					return SurpriseTools.success();
				}
				return
					ctx.request.parseMultipart( onPart, onData, onEndPart ).map(function(result) {
						switch result {
							case Success(s): return Success( s );
							case Failure(f): return Failure( HttpError.wrap(f) );
						}
					});
			#else
				return throw "Not implemented";
			#end
		}
		else return SurpriseTools.success();
	}

	/**
	Delete the temporary file at the end of the request.
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
				return SurpriseTools.asSurpriseError( errors, "Failed to delete one or more temporary upload files" );
		}
		return SurpriseTools.success();
	}
}
