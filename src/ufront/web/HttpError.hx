package ufront.web;

import tink.core.Error;
using tink.CoreApi;

/**
	A base class for various Http error messages.

	@todo Now that `code` is included in tink.core.Error, explore if this is needed. Probably not.
**/
class HttpError extends Error {

	@:keep override public function toString() {
		return '$code Error: $message';
	}

	override public function printPos() {
		return super.printPos();
	}

	/**
		Wrap an existing error into a HttpError

		- If it was a HttpError already, return it as is
		- If it was a tink.core.Error, use code 500, copy it's message, pos and data.
		- If it was a normal exception, use code 500, with "Internal Server Error" as the message, the exception as the data, and the pos that call site for `wrap()` as the pos.
	**/
	static public function wrap( e:Dynamic, ?msg="Internal Server Error", ?pos:Pos ):HttpError {
		if ( Std.is(e, HttpError) ) return cast e;
		else if ( Std.is(e, Error) ) return internalServerError( e.message, e.data, e.pos );
		else return HttpError.internalServerError( msg, e, pos );
	}

	/**
		A Http 400 "Bad Request" error
	**/
	static public inline function badRequest( ?pos ):HttpError {
		return new HttpError(400, "Bad Request", pos);
	}

	/**
		A Http 500 "Internal Server Error", optionally containing the inner error
	**/
	static public function internalServerError( ?msg="Internal Server Error", ?inner:Dynamic, ?pos ):HttpError {
		var e = new HttpError( 500, msg, pos );
		e.data = inner;
		return e;
	}

	/**
		A Http 405 "Method Not Allowed" error
	**/
	static public function methodNotAllowed( ?pos ):HttpError {
		return new HttpError( 405, "Method Not Allowed", pos );
	}

	/**
		A Http 404 "Page Not Found" error
	**/
	static public function pageNotFound( ?pos ):HttpError {
		return new HttpError( 404, "Page Not Found", pos );
	}

	/**
		A Http 401 "Unauthorized Access" error
	**/
	static public function unauthorized( ?pos ):HttpError {
		return new HttpError( 401, "Unauthorized Access", pos );
	}

	/**
		A Http 422 "Unprocessable Entity" error
	**/
	static public function unprocessableEntity( ?pos ):HttpError {
		return new HttpError( 422, "Unprocessable Entity", pos );
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
			customParams: (args!=null) ? args : [],
			className: Type.getClassName(Type.getClass(obj))
		};
	}
}