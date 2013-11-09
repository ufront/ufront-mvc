package ufront.email;
import thx.error.NullArgument;

class SimpleEmail extends Email {
	override public function setMsg( msg:String ) {
		NullArgument.throwIfNull( msg );

		setContent( msg );
		setContent( EmailConstants.TEXT_HTML );

		return this;
	}
}