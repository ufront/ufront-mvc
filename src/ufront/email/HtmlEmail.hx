package ufront.email;

class HtmlEmail extends MultiPartEmail {

	static var HTML_START = "<html><body><pre>";
	static var HTML_END = "</pre></body></html>";
	
	public var text(default,null):String;
	public var html(default,null):String;
	public var inlineImages(default,null):Map<String,InlineImage>; 

	public function setText( text:String ):HtmlEmail {
		return this;
	}

	public function setHtml( html:String ):HtmlEmail {
		return this;
	}

	public function setMsg( msg:String ) {
		setText( msg );
		setHtml( HTML_START + msg + HTML_END );
	}

	embed( bytes? ) // or do we need to support each type of embed individually?

	override public function buildMimeMessage() {}
	private function build() {}
}

private class InlineImage {
	// Do we need this?  If we just embed haxe.io.Bytes instead of InlineImage, will that be sufficient?
	// I want to keep this as agnostic as possible, so it could be serialized, used in remoting, etc
}
