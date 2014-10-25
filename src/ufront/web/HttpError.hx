package ufront.web;

import haxe.PosInfos;
import tink.core.Error.ErrorCode;
using tink.CoreApi;

/**
	Some helpers for error functions.
**/
class HttpError {

	/**
		Wrap an existing error into a Error

		- If it was an Error already, return it as is
		- If it was a normal exception, use code 500, with "Internal Server Error" as the message, the exception as the data, and the pos that call site for `wrap()` as the pos.
	**/
	static public function wrap( e:Dynamic, ?msg="Internal Server Error", ?pos ):Error {
		if ( Std.is(e, Error) ) return cast e;
		else return Error.withData( ErrorCode.InternalError, msg, e, pos );
	}

	/**
		A Http 400 "Bad Request" error
	**/
	static public inline function badRequest( ?reason:String, ?pos ):Error {
		var message = "Bad Request";
		if ( reason!=null )
			message += ': $reason';
		return new Error(400, message, pos);
	}

	/**
		A Http 500 "Internal Server Error", optionally containing the inner error
	**/
	static public function internalServerError( ?msg="Internal Server Error", ?inner:Dynamic, ?pos ):Error {
		return Error.withData( 500, msg, inner, pos );
	}

	/**
		A Http 405 "Method Not Allowed" error
	**/
	static public function methodNotAllowed( ?pos ):Error {
		return new Error( 405, "Method Not Allowed", pos );
	}

	/**
		A Http 404 "Page Not Found" error
	**/
	static public function pageNotFound( ?pos ):Error {
		return new Error( 404, "Page Not Found", pos );
	}

	/**
		A Http 401 "Unauthorized Access" error
	**/
	static public function unauthorized( ?pos ):Error {
		return new Error( 401, "Unauthorized Access", pos );
	}

	/**
		A Http 422 "Unprocessable Entity" error
	**/
	static public function unprocessableEntity( ?pos ):Error {
		return new Error( 422, "Unprocessable Entity", pos );
	}

	/**
		Generate a fake HaxePos position for a given class, method and args.

		Useful for debugging async code when you're not sure where the error came from.

		@param obj - The object (controller / module / handler) from which we derive the class name
		@param method - the method name to use in our position
		@param args - any arguments parsed to that method.  If not given, an empty array will be used.
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