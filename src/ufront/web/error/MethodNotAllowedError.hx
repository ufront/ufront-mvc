package ufront.web.error;
import haxe.PosInfos;

/**
	A Http 405 "Method Not Allowed" error
**/
class MethodNotAllowedError extends HttpError
{                   
	public function new( ?pos:PosInfos )
	{
		super( 405, "Method Not Allowed", pos );
	}
}