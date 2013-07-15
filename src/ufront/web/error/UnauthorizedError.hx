package ufront.web.error;
import haxe.PosInfos;

/**
	A Http 401 "Unauthorized Access" error
**/
class UnauthorizedError extends HttpError
{             
	public function new(?pos : PosInfos)
	{
		super(401, "Unauthorized Access", pos); 
	}
}