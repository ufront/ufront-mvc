package ufront.web.error;
import haxe.PosInfos;
import thx.error.Error;

/**
	A base class for various Http error messages.
**/
class HttpError extends Error
{
	/** The HTTP response code to use **/
	public var code : Int;

	/** 
		Construct a new HTTP error.  

		Usually it is easier to use one of the subclass constructors. 
	**/
	public function new(code : Int, message : String, ?params : Array<Dynamic>, ?param : Dynamic, ?pos : PosInfos)
	{
		super("Error " + code + ": " + message, params, param, pos); 
		this.code = code;
	}
}