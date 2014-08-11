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

import haxe.remoting.AsyncConnection;
import haxe.remoting.HttpAsyncConnection;
import haxe.remoting.RemotingError;
import ufront.log.Message;
import haxe.CallStack;
using StringTools;


/**
	Extension of class that allows traces to be sent.
	On the server side, just make sure you write to `Lib.printLn();` before `handleRequest(context)` is called.

	This all relies on Haxe serialised data always being one line.

	A line beginning with hxr is the remoting call, a line beginning with hxt is a trace

	Any other line will throw an "Invalid response" error.
**/
class HttpAsyncConnectionWithTraces extends HttpAsyncConnection
{
	override public function resolve( name ):AsyncConnection {
		var c = new HttpAsyncConnectionWithTraces(__data,__path.copy());
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
			else {
				// We got an error HTTP response code, and it was not a 500, so is not from our remoting handler.
				// This may be due to a server being inaccessible etc.
				var errorHandler = __data.error;
				errorHandler( HttpError(remotingCallString, responseCode, h.responseData) );
			}
		}

		// Run the request
		h.request(true);
	}

	public static function urlConnect( url:String, errorHandler:RemotingError->Void ) {
		var handler = RemotingUtil.wrapErrorHandler( errorHandler );
		return new HttpAsyncConnectionWithTraces({ url:url, error:handler },[]);
	}
}
