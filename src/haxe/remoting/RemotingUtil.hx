package haxe.remoting;

import haxe.remoting.RemotingError;
import ufront.log.Message;

class RemotingUtil {
	public static function processResponse( response:String, onResult:Dynamic->Void, onError:Dynamic->Void, remotingCallString:String ) {
		var ret = null;
		var stack:String = null;
		var hxrFound = false;
		var errors = [];
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
				errors.push( err );
			}
		}

		if ( errors.length==0 ) {
			if ( false==hxrFound ) throw NoRemotingResult( remotingCallString, response );
			
			// It is actually easier to debug these errors if we don't catch them, because the browser
			// debugger can then provide a stack trace.  
			#if debug
				onResult( ret );
			#else
				try onResult( ret ) catch (e:Dynamic) onError( ClientCallbackException(remotingCallString, e) );
			#end
		}
		else {
			for ( err in errors ) onError( err );
		}
	}

	public static function wrapErrorHandler( errorHandler:RemotingError->Void ):Dynamic->Void {
		return function( e:Dynamic ) {
			if ( Std.is(e,RemotingError) )
				errorHandler(e);
			else
				errorHandler( UnknownException(e) );
		}
	}
}