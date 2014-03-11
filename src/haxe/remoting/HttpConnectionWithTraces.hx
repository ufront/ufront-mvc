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
		h.onData = function(d) { data = d; };
		h.onStatus = function(s) { status = s; };
		h.onError = function(e) { throw '$e \n${h.responseData}'; };

		OKAY... 
		Can we change this to behave pretty similar to the async call() method? 
		We need to somehow 
		 - process the result, regardless of error code
		 - if there are traces, trace them (or have an onTrace dynamic function?)
		 - if there is an exception, make sure we process all the lines first, because traces come after exceptions
		 - throw RemotingError rather than have onError... (use onError=function(re) throw re;)

		h.request(true);
		if( data.substr(0,3) != "hxr" )
			throw "Invalid response : '"+data+"'";
		data = data.substr(3);
		return new haxe.Unserializer(data).unserialize();
	}

	#if (js || neko || php)

	public static function urlConnect( url : String ) {
		return new HttpConnectionWithTraces(url,[]);
	}

	#end
}
