package ufront.web;
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

	/**
		A Http 400 "Bad Request" error
	**/
	static public inline function badRequest( ?pos ):HttpError {
		return new HttpError(400, "Bad Request", pos);
	}

	/**
		A Http 500 "Internal Server Error", optionally containing the inner error
	**/
	static public function internalServerError( ?inner:Dynamic, ?pos ):HttpError {
		var e = new HttpError( 500, "Internal Server Error", pos );
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