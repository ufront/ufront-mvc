package ufront.email;

class Part {
	/** A string representation of the content of this part **/
	public var content(get,set):String;

	/** Any sub parts that belong to this part **/
	public var parts:List<Part>;

	/** The content type of this part **/
	public var contentType(get,null):String;
	/** The charset of this type.  This will be used for all sub-types also **/
	public var charset(get,null):String;
	/** Whether or not this part is embedded in an existing part **/
	public var isSubPart(get,null):Bool
	/** The name of this part, if this part has a filename (for example, if it is an attachment) **/
	public var name:Null<String>;

	public function new( ?contentType:String, ?charset:String, ?isSubPart=false ) {
		this.charset = (charset!=null) ? charset : EmailConstants.ISO_8859_1;
		this.contentType = (contentType!=null) ? contentType : EmailConstants.TEXT_PLAIN;

		this.parts  new List();
	}

	public function newPart( ?cType:String ) {
		var p = new Part( cType, this.charset, true )
		parts.add( p );
		return p;
	}
}