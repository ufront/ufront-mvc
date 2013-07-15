package ufront.web.error;
import haxe.PosInfos;

/**
	A Http 422 "Unprocessable Entity" error
**/
class UnprocessableEntityError extends HttpError
{                                 
	public function new(?pos : PosInfos)
	{
		super(422, "Unprocessable Entity", pos); 
	}
}