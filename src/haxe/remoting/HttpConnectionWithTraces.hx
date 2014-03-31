/*
 * Copyright (C)2005-2012 Haxe Foundation
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 */
package haxe.remoting;

import haxe.remoting.RemotingError;

class HttpConnectionWithTraces extends haxe.remoting.HttpConnection {

	public static var TIMEOUT = 10.;

	override public function call( params : Array<Dynamic> ) : Dynamic {
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
		s.serialize(__path);
		s.serialize(params);
		h.setHeader("X-Haxe-Remoting","1");
		h.setParameter("__x",s.toString());

		// Set up the remoting data/error callbacks
		var remotingCallString = __path.join(".")+"("+params.join(",")+")";
		var responseCode:Int;
		var result:Dynamic;

		function onResult(v:Dynamic) { result = v; }
		function onError(v:Dynamic) { throw v; }
		
		h.onStatus = function(status) {
			responseCode = status;
		}

		h.onData = RemotingUtil.processResponse.bind( _, onResult, onError, remotingCallString );

		h.onError = function(errorData) {
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
		h.request(true);

		return result;
	}

	#if (js || neko || php)

	public static function urlConnect( url : String ) {
		return new HttpConnectionWithTraces(url,[]);
	}

	#end
}
