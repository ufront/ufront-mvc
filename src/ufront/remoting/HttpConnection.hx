package ufront.remoting;

import ufront.remoting.RemotingError;

/**
A remoting connection that works over synchronous HTTP connections, with some ufront specific extensions.

This extends `haxe.remoting.HttpConnection` and behaves similarly in most ways.
This adds an extra HTTP header, "X-Ufront-Remoting=1", so that our Ufront `RemotingHandler` knows it can also send traces, logs, warnings, errors and stack traces with the response.
**/
class HttpConnection extends haxe.remoting.HttpConnection {

	public static var TIMEOUT = 10.;

	override public function call( params:Array<Dynamic> ):Dynamic {
		var data = null;
		var status = null;
		var h = new haxe.Http(__url);
		#if js
			h.async = false;
		#end
		#if (neko && no_remoting_shutdown)
			h.noShutdown = true;
		#end
		#if (neko || php || cpp)
			h.cnxTimeout = TIMEOUT;
		#end
		var s = new haxe.Serializer();
		s.serialize( __path );
		s.serialize( params );
		h.setHeader( "X-Haxe-Remoting", "1" );
		h.setHeader( "X-Ufront-Remoting", "1" );
		h.setParameter( "__x", s.toString() );

		// Set up the remoting data/error callbacks
		var remotingCallString = __path.join(".")+"("+params.join(",")+")";
		var responseCode:Int;
		var result:Dynamic;

		function onResult(v:Dynamic) { result = v; }
		function onError(v:Dynamic) { throw v; }

		h.onStatus = function( status ) {
			responseCode = status;
		}

		h.onData = RemotingUtil.processResponse.bind( _, onResult, onError, remotingCallString );

		h.onError = function( errorData ) {
			if ( 500==responseCode ) {
				// We got an internal error HTTP response code, which may have been from our remoting handler.
				// Therefore, unpack it.  It is likely there was an exception server side that has been serialized.
				// If it was a different kind of 500 error, it will throw a NoRemotingResult.
				RemotingUtil.processResponse( h.responseData, onResult, onError, remotingCallString );
			}
			else {
				// We got an error HTTP response code, and it was not a 500, so is not from our remoting handler.
				// This may be due to a server being inaccessible etc.
				onError( HttpError(remotingCallString, responseCode, h.responseData) );
			}
		}

		// Run the request
		h.request( true );

		return result;
	}

	#if (js || neko || php)
		public static function urlConnect( url:String ) {
			return new HttpConnection( url, [] );
		}
	#end
}
