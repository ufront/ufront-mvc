package ufront.remoting;

import ufront.remoting.RemotingError;
import ufront.log.Message;

/**
Helper functions used by both `ufront.remoting.HttpConnection` and `ufront.remoting.HttpAsyncConnection`.
**/
class RemotingUtil {
	/**
	Process a remoting response from the server.

	Lines are interpreted as follows:

	- Lines beginning with `hxr` contain a serialized response to the remoting function call.
	- Lines beginning with `hxt` contain a trace, log, warning or error message.
	- Lines beginning with `hxe` contain a server side exception that was encountered during the remoting function call.
	- Lines beginning with `hxs` contain a stack trace for the exception found in the `hxe` line.
	- Blank lines are ignored.
	- Other lines are not recognised and will result in an error.
	- If no `hxr` line is found, it will result in an error.

	If there is a valid result and no errors, `onResult` will be called.
	If one or more errors occured, `onError` will be called for each error encountered.

	@param response The response received from the HTTP remoting call.
	@param onResult The function to call once a valid result has been received.
	@param onError The function to call if an error is encountered.
	@param remotingCallString A string describing the remoting call, used to help error messages be more descriptive.
	**/
	public static function processResponse( response:String, onResult:Dynamic->Void, errorHandler:RemotingError<Dynamic>->Void, remotingCallString:String ):Void {
		var ret = null;
		var stack:String = null;
		var hxrFound = false;
		var errors = [];
		var onError = wrapErrorHandler( errorHandler );
		for ( line in response.split('\n') ) {
			if ( line=="" ) continue;
			try switch (line.substr(0,3)) {
				case "hxr":
					var s = new haxe.Unserializer(line.substr(3));
					ret =
						try s.unserialize()
						catch(e:Dynamic) throw RUnserializeFailed( remotingCallString, line.substr(3), '$e' )
					;
					hxrFound = true;
				case "hxt":
					var s = new haxe.Unserializer(line.substr(3));
					var m:Message =
						try s.unserialize()
						catch(e:Dynamic) throw RUnserializeFailed( remotingCallString, line.substr(3), '$e' )
					;
					#if js
						var extras =
							if ( m.pos!=null && m.pos.customParams!=null ) " "+m.pos.customParams.join(" ")
							else "";
						var msg = '[R]${m.pos.className}.${m.pos.methodName}(${m.pos.lineNumber}): ${m.msg}$extras';
						var c = js.Browser.window.console;
						switch m.type {
							case MTrace: c.log( msg );
							case MLog: c.info( msg );
							case MWarning: c.warn( msg );
							case MError: c.error( msg );
						}
					#else
						m.pos.fileName="[R]"+m.pos.fileName;
						haxe.Log.trace('[${m.type}]${m.msg}', m.pos);
					#end
				case "hxs":
					var s = new haxe.Unserializer(line.substr(3));
					stack =
						try s.unserialize()
						catch(e:Dynamic) throw RUnserializeFailed( remotingCallString, line.substr(3), '$e' )
					;
				case "hxe":
					var s = new haxe.Unserializer(line.substr(3));
					ret =
						try s.unserialize()
						catch(e:Dynamic) throw RServerSideException( remotingCallString, e, stack )
					;
				default:
					throw RUnserializeFailed( remotingCallString, line, "Invalid line in response" );
			}
			catch( err:Dynamic ) errors.push( err );
		}

		if ( errors.length==0 ) {
			if ( hxrFound ) {
				// It is actually easier to debug these errors if we don't catch them, because the browser debugger can then provide a stack trace.
				#if debug
					onResult( ret );
				#else
					try onResult( ret ) catch (e:Dynamic) onError( RClientCallbackException(remotingCallString, e) );
				#end
			}
			else onError( RNoRemotingResult(remotingCallString,response) );
		}
		else for ( err in errors ) onError( err );
	}

	/**
	Take an error handler function that expects a RemotingError, and return a function that can take any exception.
	If the exception is not already a RemotingError, it will be wrapped in `RemotingError.UnknownException(e)`.
	**/
	public static function wrapErrorHandler( errorHandler:RemotingError<Dynamic>->Void ):Dynamic->Void {
		return function( e:Dynamic ) {
			if ( Std.is(e,RemotingError) )
				errorHandler(e);
			else
				errorHandler( RUnknownException(e) );
		}
	}

	/**
	A default error handler that traces lots of information.
	**/
	public static function defaultErrorHandler( error:RemotingError<Dynamic> ):Void {
		switch error {
			case RHttpError( remotingCallString, responseCode, responseData ):
				trace( 'Error during remoting call $remotingCallString: The HTTP Request returned status [$responseCode].' );
				trace( 'Returned data: $responseData' );
			case RApiNotFound( remotingCallString, err ):
				trace( 'Error during remoting call $remotingCallString: API or Method is not found or not available in the remoting context.' );
				trace( 'Error message: $err' );
			case RServerSideException( remotingCallString, e, stack ):
				trace( 'Error during remoting call $remotingCallString: The server threw an error "$e".' );
				trace( stack );
			case RClientCallbackException( remotingCallString, e ):
				trace( 'Error during remoting call $remotingCallString: The client throw an error "$e" during the remoting callback.' );
				trace( 'Compiling with "-debug" will prevent this error being caught, so you can use your browser\'s debugger to collect more information.' );
			case RUnserializeFailed( remotingCallString, troubleLine, err ):
				trace( 'Error during remoting call $remotingCallString: Failed to unserialize this line in the response: "$err"' );
				trace( 'The line that failed: "$err"' );
			case RNoRemotingResult( remotingCallString, responseData ):
				trace( 'Error during remoting call $remotingCallString: No remoting result in data.' );
				trace( 'Returned data: $responseData' );
			case RApiFailure( remotingCallString, data ):
				trace( 'The remoting call $remotingCallString functioned correctly, but the API returned a failure: $data' );
			case RUnknownException( e ):
				trace( 'Unknown error encountered during remoting call: $e' );
		}
	}
}
