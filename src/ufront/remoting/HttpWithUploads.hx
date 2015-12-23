package ufront.remoting;

import ufront.web.upload.*;
import ufront.core.MultiValueMap;
import haxe.Http;
#if js
	import js.html.*;
	using StringTools;
#end
using ufront.core.AsyncTools;
using tink.CoreApi;

/**
A simple wrapper of `Http` and `XMLHttpRequest`, because plain `Http` doesn't allow uploads on JS currently.

NOTE: This class is intended for private use only. API may change or be removed in future.

TODO: make this private, but still accessible to `HttpConnection` and `HttpAsyncConnection`.
TODO: make this an abstract rather than a class.
**/
@:noDoc
class HttpWithUploads {
	#if js
		public var h:XMLHttpRequest;
		var files:Array<{ postName:String, file:File, fileName:String }>;
		var params:Array<{ name:String, val:String }>;
	#else
		public var h:Http;
	#end
	public var async:Bool;

	public function new( url:String, async:Bool, ?timeout:Null<Float> ) {
		#if js
			this.h = new XMLHttpRequest();
			this.files = [];
			this.params = [];
			h.open( "POST", url, async );
		#else
			this.h = new Http( url );
			if ( async==false ) {
				#if (neko && no_remoting_shutdown)
					h.noShutdown = true;
				#end
				#if (neko || php || cpp)
					if ( timeout!=null )
						h.cnxTimeout = timeout;
				#end
			}
		#end
		this.async = async;
	}

	public function setHeader( k:String, v:String ):Void {
		#if js
			h.setRequestHeader( k, v );
		#else
			h.setHeader( k, v );
		#end
	}

	public function setParam( k:String, v:String ):Void {
		#if js
			params.push({ name:k, val:v });
		#else
			h.setParameter( k, v );
		#end
	}

	public function attachUploads( uploads:MultiValueMap<UFFileUpload> ):Surprise<Noise,Error> {
		#if js
			for ( postName in uploads.keys() ) for ( u in uploads.getAll(postName) ) {
				var browserFileUpload = Std.instance( u, BrowserFileUpload );
				if ( browserFileUpload!=null ) {
					files.push({ postName:postName, file:browserFileUpload.file, fileName:u.originalFileName });
				}
				// TODO: See if we can upload other types based on haxe.io.Bytes, rather than js.html.File.
			}
			return SurpriseTools.success();
		#else
			var allUploadsReady = [];
			var failedUploads = [];
			for ( postName in uploads.keys() ) for ( upload in uploads.getAll(postName) ) {
				var finished = false;
				var surprise = upload.getBytes().map(function(outcome) {
					switch outcome {
						case Success(bytes):
							var bytesInput = new haxe.io.BytesInput( bytes );
							h.fileTransfer( postName, upload.originalFileName, bytesInput, upload.size, upload.contentType );
							finished = true;
						case Failure(err):
							failedUploads.push( err );
					}
				});
				if ( this.async==false && !finished ) {
					throw 'upload.getBytes() resolved asynchronously, and was not ready in time for the synchronous HttpConnection remoting call';
				}
				allUploadsReady.push( surprise );
			}
			return Future.ofMany( allUploadsReady ).map( function(_) {
				return
					if ( failedUploads.length==0 ) Success( Noise )
					else Failure( new Error('Failed to read attachments: ${failedUploads}') );
			});
		#end
	}

	public function send():Void {
		#if js
			// FormData is the easiest way to send multipart requests including uploads.
			// But if there are no uploads, we manually do a URL encoded request to avoid using a multipart request unnecessarily.
			if ( this.files.length>0 ) {
				var formData = new FormData();
				for ( p in params )
					formData.append( p.name, p.val );
				for ( f in files )
					formData.append( f.postName, f.file, f.fileName );
				h.send( formData );
			}
			else {
				// https://developer.mozilla.org/en-US/docs/Web/Guide/HTML/Forms/Sending_forms_through_JavaScript#Building_an_XMLHttpRequest_manually
				var urlEncodedDataPairs = [];
				for ( p in params ) {
					urlEncodedDataPairs.push( p.name.urlEncode() + '=' + p.val.urlEncode() );
				}
				var urlEncodedData = urlEncodedDataPairs.join( '&' ).replace( '%20', '+' );
				h.setRequestHeader( 'Content-Type', 'application/x-www-form-urlencoded' );
				// h.setRequestHeader( 'Content-Length', ''+urlEncodedData.length ); // see http://stackoverflow.com/questions/7210507/ajax-post-error-refused-to-set-unsafe-header-connection
				h.send( urlEncodedData );
			}
		#else
			h.request( true );
		#end
	}

	public function responseData():String {
		#if js
			return h.responseText;
		#else
			return h.responseData;
		#end
	}

	public function handle( onStatus:Int->Void, onData:String->Void, onError:String->Void ):Void {
		#if js
			h.onload = function(oEvent) {
				onStatus( h.status );
				if ( h.status==200 ) onData( h.responseText );
				else onError( h.responseText );
			}
		#else
			h.onStatus = onStatus;
			h.onData = onData;
			h.onError = onError;
		#end
	}
}
