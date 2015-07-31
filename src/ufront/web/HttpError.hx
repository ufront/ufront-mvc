package ufront.web;

import haxe.PosInfos;
import tink.core.Error;
import ufront.auth.AuthError;
using tink.CoreApi;

/**
Helper functions to create `tink.core.Error` objects that are common in Http requests.
**/
class HttpError {

	/**
	Wrap an existing error into a Error

	- If it was a `tink.core.Error` already, return it as is.
	- If it was a normal exception, use code 500, with "Internal Server Error" as the message, the exception as the data, and the call site as the pos.

	@param e The original exception.
	@param msg (optional) The message to use with the error.  The default message is "Internal Server Error".
	@param pos (optional) The position of the error. Can be supplied, otherwise the call site of this function is used.
	@return A wrapped `Error` object, with the error code 500.
	**/
	static public function wrap( e:Dynamic, ?msg="Internal Server Error", ?pos:PosInfos ):Error {
		if ( Std.is(e, Error) ) return cast e;
		else return Error.withData( ErrorCode.InternalError, msg, e, pos );
	}

	/**
	A Http 400 "Bad Request" error.

	@param reason (optional) If supplied, the error message will be `Bad Request: $reason`.
	@param pos (optional) The position of the error. Can be supplied, otherwise the call site of this function is used.
	@return A wrapped `Error` object, with the error code 400.
	**/
	static public inline function badRequest( ?reason:String, ?pos:PosInfos ):Error {
		var message = "Bad Request";
		if ( reason!=null )
			message += ': $reason';
		return new Error(400, message, pos);
	}

	/**
	A Http 500 "Internal Server Error", optionally containing the inner error.

	@param msg (optional) The error message. The default message is "Internal Server Error".
	@param inner (optional) The inner data of the error, if any.
	@param pos (optional) The position of the error. Can be supplied, otherwise the call site of this function is used.
	@return A wrapped `Error` object, with the error code 500.
	**/
	static public function internalServerError( ?msg="Internal Server Error", ?inner:Dynamic, ?pos:PosInfos ):Error {
		return Error.withData( 500, msg, inner, pos );
	}

	/**
	A Http 405 "Method Not Allowed" error.

	@param pos (optional) The position of the error. Can be supplied, otherwise the call site of this function is used.
	@return A wrapped `Error` object, with the error code 405.
	**/
	static public function methodNotAllowed( ?pos:PosInfos ):Error {
		return new Error( 405, "Method Not Allowed", pos );
	}

	/**
	A Http 404 "Page Not Found" error.

	@param pos (optional) The position of the error. Can be supplied, otherwise the call site of this function is used.
	@return A wrapped `Error` object, with the error code 404.
	**/
	static public function pageNotFound( ?pos:PosInfos ):Error {
		return new Error( 404, "Page Not Found", pos );
	}

	/**
	A Http 401 "Unauthorized Access" error.

	@param message (optional) A description of the error. Default is "Unauthorized Access".
	@param pos (optional) The position of the error. Can be supplied, otherwise the call site of this function is used.
	@return A wrapped `Error` object, with the error code 401.
	**/
	static public function unauthorized( ?message:String="Unauthorized Access", ?pos:PosInfos ):Error {
		return new Error( 401, message, pos );
	}

	/**
	A Http 401 "Unauthorized Access" error based on an `AuthError`.

	@param error The AuthError that has been raised.
	@param pos (optional) The position of the error. Can be supplied, otherwise the call site of this function is used.
	@return A wrapped `Error` object, with the error code 401.
	**/
	static public function authError( error:AuthError, ?pos:PosInfos ):TypedError<AuthError> {
		var msg = switch error {
			case ANotLoggedIn: 'Not Logged In';
			case ALoginFailed( msg ): 'Login Failed: $msg';
			case ANotLoggedInAs( u ): 'Not Logged In As $u';
			case ANoPermission( p ): 'Permission $p denied';
		}
		return Error.typed( 401, msg, error, pos );
	}

	/**
	A Http 422 "Unprocessable Entity" error.

	@param pos (optional) The position of the error. Can be supplied, otherwise the call site of this function is used.
	@return A wrapped `Error` object, with the error code 422.
	**/
	static public function unprocessableEntity( ?pos:PosInfos ):Error {
		return new Error( 422, "Unprocessable Entity", pos );
	}

	/**
	A shortcut for an error when a method is not implemented (Http 500).

	@param pos (optional) The position of the error. Can be supplied, otherwise the call site of this function is used.
	@return A wrapped `Error` object, with the error code 500.
	**/
	static public function notImplemented( ?pos:PosInfos ):Error {
		var methodName = pos.className + "." + pos.methodName;
		return new Error( 500, 'Internal Server Error: $methodName is not implemented on this platform', pos );
	}

	/**
	A shortcut for an error when a method is abstract and should be overridden (Http 500).

	@param pos (optional) The position of the error. Can be supplied, otherwise the call site of this function is used.
	@return A wrapped `Error` object, with the error code 500.
	**/
	static public function abstractMethod( ?pos:PosInfos ):Error {
		var methodName = pos.className + "." + pos.methodName;
		return new Error( 500, 'Internal Server Error: $methodName is an abstract method and should be overridden by a subclass', pos );
	}

	/**
	A shortcut to throw an `Error` if a particular value is `null` (Http 500).

	@param val The value to check.
	@param name (optional) The name of the argument that is being checked, to provide a more helpful error message. Default is "argument".
	@param pos (optional) The position of the error. Can be supplied, otherwise the call site of this function is used.
	@throws A wrapped `Error` object, with the error code 500, if `val` was null.
	**/
	static public function throwIfNull( val:Dynamic, ?name:String="argument", ?pos:PosInfos ):Void {
		if ( val==null )
			throw new Error( 500, '$name should not be null', pos );
	}

	/**
	Generate a fake `haxe.PosInfos` position for a given class, method and args.

	This is used by some ufront internals to give an accurate position for messages and errors, when we have details about the context but not the actual position.

	For example, `MVCHandler` knows the Controller, Action and Arguments that were called, but if an exception is thrown it does not have a valid position.
	This allows us to fake a "close enough" position, to aid in debugging.

	@param obj - The object (controller / module / handler) from which we derive the class name. Must be a class instance.
	@param method - The method name to use in our position
	@param args - Any arguments parsed to that method.  If not given, an empty array will be used.
	**/
	static inline public function fakePosition( obj:Dynamic, method:String, ?args:Array<Dynamic> ) {
		return {
			methodName: method,
			lineNumber: -1,
			fileName: "",
			customParams: args,
			className: Type.getClassName(Type.getClass(obj))
		};
	}
}
