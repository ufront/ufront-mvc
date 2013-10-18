package ufront.web.error;
import haxe.PosInfos;

/**
	A Http 500 "Internal Server Error"
**/
class InternalServerError extends HttpError
{
	@:access(tink.core.Error)
	public function new( ?inner:Dynamic, ?pos:PosInfos )
	{
		super( 500, "Internal Server Error", pos );
		this.data = inner;
	}
}