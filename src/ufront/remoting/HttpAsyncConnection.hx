package ufront.remoting;

import haxe.remoting.AsyncConnection;
import ufront.remoting.RemotingError;
import ufront.log.Message;
import haxe.CallStack;
using StringTools;


/**
A remoting connection that works over asynchronous HTTP connections, with some ufront specific extensions.

This extends `haxe.remoting.HttpAsyncConnection` and behaves similarly in most ways.
An extra HTTP header is added, "X-Ufront-Remoting=1", so that our Ufront `RemotingHandler` knows it can also send traces, logs, warnings, errors and stack traces with the response.
**/
class HttpAsyncConnection extends haxe.remoting.HttpAsyncConnection
{
	override public function resolve( name ):AsyncConnection {
		var dataCopy = { url:__data.url, error:__data.error };
		var c = new HttpAsyncConnection(dataCopy,__path.copy());
		c.__path.push(name);
		return c;
	}

	// Code mostly copied from super class, but the onData() response has been modified to output traces
	override public function call( params:Array<Dynamic>, ?onResult:Dynamic->Void ) {

		// Set up the remoting call
		var h = new haxe.Http(__data.url);
		#if (neko && no_remoting_shutdown)
			h.noShutdown = true;
		#end
		var s = new haxe.Serializer();
		s.serialize(__path);
		s.serialize(params);
		h.setHeader("X-Haxe-Remoting","1");
		h.setHeader("X-Ufront-Remoting","1");
		h.setParameter("__x",s.toString());

		// Set up the remoting data/error callbacks
		var remotingCallString = __path.join(".")+"("+params.join(",")+")";

		var responseCode:Int;
		h.onStatus = function(status) {
			responseCode = status;
		}

		h.onData = RemotingUtil.processResponse.bind( _, onResult, __data.error, remotingCallString );

		h.onError = function(errorData) {
			if ( 500==responseCode ) {
				// We got an internal error HTTP response code, which may have been from our remoting handler.
				// Therefore, unpack it.  It is likely there was an exception server side that has been serialized.
				// If it was a different kind of 500 error, it will throw a NoRemotingResult.
				RemotingUtil.processResponse( h.responseData, onResult, __data.error, remotingCallString );
			}
			else if ( 404==responseCode ) {
				var errorHandler = __data.error;
				errorHandler( ApiNotFound(remotingCallString, h.responseData) );
			}
			else {
				// We got an error HTTP response code, and it was not a 500 or a 404, so is not from our remoting handler.
				// This may be due to a server being inaccessible etc.
				var errorHandler = __data.error;
				errorHandler( HttpError(remotingCallString, responseCode, h.responseData) );
			}
		}

		// Run the request
		h.request(true);
	}

	public static function urlConnect( url:String, ?errorHandler:RemotingError<Dynamic>->Void ) {
		if ( errorHandler==null )
			errorHandler = RemotingUtil.defaultErrorHandler;
		return new HttpAsyncConnection({ url:url, error:errorHandler },[]);
	}
}
