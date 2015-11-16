package ufront.remoting;

import ufront.remoting.RemotingError;
import ufront.remoting.RemotingUtil;
import ufront.remoting.HttpWithUploads;
import ufront.web.HttpError;
using tink.CoreApi;

/**
A remoting connection that works over synchronous HTTP connections, with some ufront specific extensions.

This extends `haxe.remoting.HttpConnection` and behaves similarly in most ways.
This adds an extra HTTP header, "X-Ufront-Remoting=1", so that our Ufront `RemotingHandler` knows it can also send traces, logs, warnings, errors and stack traces with the response.
**/
class HttpConnection extends haxe.remoting.HttpConnection {

	public static var TIMEOUT = 10.;

	@:allow( ufront.remoting.HttpWithUploads )
	override public function call( params:Array<Dynamic> ):Dynamic {

		// Set up the Http Request
		var h = new HttpWithUploads( __url, false, TIMEOUT );
		var data = null;
		var status = null;

		// Serialize the request details.
		var s = new RemotingSerializer( RDClientToServer );
		s.serialize( __path );
		s.serialize( params );

		// Set up the remoting data/error callbacks
		var remotingCallString = __path.join(".")+"("+params.join(",")+")",
		    responseCode:Int,
		    responseText:String,
		    result:Dynamic;
		function throwError(v:Dynamic) { throw v; }
		function setResult(v:Dynamic) { result = v; }
		function onStatus(s:Int) { responseCode = status; }
		function onData(str:String) {
			responseText = str;
			RemotingUtil.processResponse( responseText, setResult, throwError, remotingCallString );
		}
		function onError( errorData )  {
			if ( 500==responseCode ) {
				// We got an internal error HTTP response code, which may have been from our remoting handler.
				// Therefore, unpack it.  It is likely there was an exception server side that has been serialized.
				// If it was a different kind of 500 error, it will throw a NoRemotingResult.
				RemotingUtil.processResponse( h.responseData(), setResult, throwError, remotingCallString );
			}
			else {
				// We got an error HTTP response code, and it was not a 500, so is not from our remoting handler.
				// This may be due to a server being inaccessible etc.
				throwError( RHttpError(remotingCallString, responseCode, h.responseData()) );
			}
		}
		h.handle( onStatus, onData, onError );

		// Prepare and POST the request
		h.setHeader( "X-Haxe-Remoting", "1" );
		h.setHeader( "X-Ufront-Remoting", "1" );
		h.setParam( "__x", s.toString() );
		h.attachUploads( s.uploads );
		h.send();

		return result;
	}

	#if (js || neko || php)
		public static function urlConnect( url:String ) {
			return new HttpConnection( url, [] );
		}
	#end
}
