package ufront.remoting;

import ufront.web.upload.*;
import ufront.core.MultiValueMap;
import haxe.Http;
#if js
	import js.html.*;
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
		public var formData:FormData;
	#else
		public var h:Http;
	#end
	public var async:Bool;

	public function new( url:String, async:Bool, ?timeout:Null<Float> ) {
		#if js
			this.h = new XMLHttpRequest();
			this.formData = new FormData();
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
			formData.append( k, v );
		#else
			h.setParameter( k, v );
		#end
	}

	public function attachUploads( uploads:MultiValueMap<UFFileUpload> ):Surprise<Noise,Error> {
		#if js
			for ( postName in uploads.keys() ) for ( u in uploads.getAll(postName) ) {
				var browserFileUpload = Std.instance( u, BrowserFileUpload );
				if ( browserFileUpload!=null ) {
					formData.append( postName, browserFileUpload.file, u.originalFileName );
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
			h.send( formData );
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
