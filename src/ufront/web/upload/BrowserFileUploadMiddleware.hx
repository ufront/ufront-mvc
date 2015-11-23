package ufront.web.upload;

#if (js && pushstate)
	import js.html.*;
	import pushstate.PushState;
#end
import ufront.web.context.HttpContext;
import ufront.web.HttpError;
import ufront.app.UFMiddleware;
import ufront.core.Uuid;
import ufront.app.HttpApplication;
import tink.CoreApi;
import ufront.web.upload.TmpFileUpload;
import ufront.core.AsyncTools;
using haxe.io.Path;
using DateTools;

/**
A middleware that works with `PushState.currentUploads` to recognise file uploads in PushState form submissions, and make them available to `HttpRequest.files` as `BrowserFileUpload` objects.

Please see the `PushState` API documentation and [README](https://github.com/jasononeil/hxpushstate) for details on the mechanics of using file uploads with PushState.

This is only available on the `js` platform when using the `pushstate` haxelib.

@author Jason O'Neil
**/
#if (js && pushstate)
class BrowserFileUploadMiddleware implements UFRequestMiddleware {

	public function new() {}

	/**
	If the current request has uploads available, turn them into `BrowserFileUpload` objects and make them available to the `HttpRequest`.
	**/
	public function requestIn( ctx:HttpContext ):Surprise<Noise,Error> {
		if ( ctx.request.isMultipart() ) {
			var uploads = PushState.currentUploads;
			for ( postName in Reflect.fields(uploads) ) {
				var fileList:FileList = Reflect.field( uploads, postName );
				for ( i in 0...fileList.length ) {
					var file = fileList[i];
					var upload = new BrowserFileUpload( postName, file );
					ctx.request.files.add( postName, upload );
				}
			}
		}
		return SurpriseTools.success();
	}
}
#end
