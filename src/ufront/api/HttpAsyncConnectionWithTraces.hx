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
package ufront.api;

import haxe.remoting.AsyncConnection;
import haxe.remoting.HttpAsyncConnection;
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

		h.onData = processResponse.bind( _, onResult, remotingCallString );

		h.onError = function(errorData) {
			if ( 500==responseCode ) {
				// We got an internal error HTTP response code, which may have been from our remoting handler.
				// Therefore, unpack it.  It is likely there was an exception server side that has been serialized.
				// If it was a different kind of 500 error, it will throw a NoRemotingResult.
				processResponse( h.responseData, onResult, remotingCallString );
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

	function processResponse( response:String, onResult:Dynamic->Void, remotingCallString:String ) {
		var ret = null;
		var errorHandler = __data.error;
		var stack:String = null;
		var hxrFound = false;
		var errFound = false;
		for (line in response.split('\n')) {
			if (line=="") continue;
			try {
				switch (line.substr(0,3)) {
					case "hxr":
						var s = new haxe.Unserializer(line.substr(3));
						ret = 
							try s.unserialize() 
							catch(e:Dynamic) throw UnserializeFailed( remotingCallString, line.substr(3), '$e' )
						;
						hxrFound = true;
					case "hxt":
						var s = new haxe.Unserializer(line.substr(3));
						var m:Message = 
							try s.unserialize() 
							catch(e:Dynamic) throw UnserializeFailed( remotingCallString, line.substr(3), '$e' )
						;
						#if js 
							var extras = 
								if ( m.pos!=null && m.pos.customParams!=null ) " "+m.pos.customParams.join(" ")
								else "";
							var msg = '[R]${m.pos.className}.${m.pos.methodName}(${m.pos.lineNumber}): ${m.msg}$extras';
							var c = js.Browser.window.console;
							switch m.type {
								case Trace: c.log( msg );
								case Log: c.info( msg );
								case Warning: c.warn( msg );
								case Error: c.error( msg );
							}
						#else
							m.pos.fileName="[R]"+m.pos.fileName;
							haxe.Log.trace('[${m.type}]${m.msg}', m.pos);
						#end
					case "hxs":
						var s = new haxe.Unserializer(line.substr(3));
						stack = 
							try s.unserialize() 
							catch(e:Dynamic) throw UnserializeFailed( remotingCallString, line.substr(3), '$e' )
						;
					case "hxe":
						var s = new haxe.Unserializer(line.substr(3));
						ret = 
							try s.unserialize() 
							catch(e:Dynamic) throw ServerSideException( remotingCallString, e, stack )
						;
					default:
						throw UnserializeFailed( remotingCallString, line, "Invalid line in response" );
				}
			}
			catch( err:Dynamic ) {
				errFound = true;
				errorHandler( err );
			}
		}

		if ( false==errFound ) {
			if ( false==hxrFound ) throw NoRemotingResult( remotingCallString, response );
			
			// It is actually easier to debug these errors if we don't catch them, because the browser
			// debugger can then provide a stack trace.  
			#if debug
				onResult( ret );
			#else
				try onResult( ret ) catch (e:Dynamic) errorHandler( ClientCallbackException(remotingCallString, e) );
			#end
		}
	}

	public static function urlConnect( url:String, errorHandler:RemotingError->Void ) {
		var handler = function( e:Dynamic ) {
			if ( Std.is(e,RemotingError) )
				errorHandler(e);
			else
				errorHandler( UnknownException(e) );
		}
		return new HttpAsyncConnectionWithTraces({ url:url, error:handler },[]);
	}
}

enum RemotingError {
	HttpError( callString:String, responseCode:Int, responseData:String );
	ServerSideException( callString:String, e:Dynamic, stack:String );
	ClientCallbackException( callString:String, e:Dynamic );
	UnserializeFailed( callString:String, troubleLine:String, err:String );
	NoRemotingResult( callString:String, responseData:String );
	UnknownException( e:Dynamic );
}