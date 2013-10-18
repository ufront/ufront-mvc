package ufront.web.error;
import haxe.PosInfos;
import tink.core.Error;

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
	public function new( code:Int, message:String, ?pos:PosInfos ) {
		super( message, pos );
		this.code = code;
	}

	@:keep override public function toString() {
		return '$code Error: $message';
	}
}