package ufront.web.error;
import haxe.PosInfos;

/**
	A Http 400 "Bad Request" error
**/
class BadRequestError extends HttpError
{       
	public function new( ?pos:PosInfos )
	{
		super(400, "Bad Request", pos); 
	}
}