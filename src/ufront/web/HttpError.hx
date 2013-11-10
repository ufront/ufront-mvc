package ufront.web;

import tink.core.Error.Pos;
using tink.CoreApi;

/**
	A base class for various Http error messages.
**/
class HttpError extends Error {
	/** The HTTP response code to use **/
	public var code:Int;

	/** 
		Construct a new HTTP error.  

		Usually it is easier to use one of the subclass constructors. 
	**/
	public function new( code:Int, message:String, ?pos ) {
		super( message, pos );
		this.code = code;
	}

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
	static public function wrap( e:Dynamic, ?pos:Pos ):HttpError {
		if ( Std.is(e, HttpError) ) return cast e;
		else if ( Std.is(e, Error) ) return internalServerError( e.message, e.data, e.pos );
		else return HttpError.internalServerError( "Internal Server Error", e, pos );
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
}