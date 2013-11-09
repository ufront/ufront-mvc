package ufront.email;

abstract EmailAddress({ e:String, n:Null<String> }) {

	public inline function new( email:String, ?name:String ) {
		if ( email==null || !validate(email) ) 
			throw 'Invalid email address $email';

		this = { e:String, n:String }
	}

	/** The email address **/
	public var email(get,null):String;
	inline function get_email() return this.e;

	/** The username part of the email address (before the @) **/
	public var username(get,null):String;
	inline function get_username() return this.e.split("@")[0];

	/** The domain part of the email address (after the @) **/
	public var domain(get,null):String;
	inline function get_domain() return this.e.split("@")[1];
	
	/** The personal name associated with the email address **/
	public var name(get,null):String;
	inline function get_name() return this.n;

	/**
		Convert a string into an email address (with no name). 

		The string should only contain the email address, not a name

		Will throw an exception if the address is invalid. 
	**/
	@:from static inline function fromString( email:String ):EmailAddress {
		return new EmailAddress( email );
	}

	/**
		Convert an array into an email address.  

		It will assume the first String in the array is the email address, and the second is the name.

		If an email address is not provided, or is invalid, an exception will be thrown.

		If a name is not provided, it will be null.

		If there are extra parts in the array, they will be ignored.
	**/
	@:from static function fromArray( parts:Array<String> ):EmailAddress {
		var email = parts[0];
		var name = parts[1];
		
		return new EmailAddress( email, name );
	}

	/** 
		A string of the address.  

		If "name" is not null, it will display it as `"$name" <$address>`.  
		If name is null, it will just display the address. 
	**/
	@:to static inline function toString( email:String ):EmailAddress {
		return (this.n!=null) ? '"${this.n}" <${this.e}>' : this.e;
	}

	static inline function validate( email:String ) {
		/** Taken from http://www.regular-expressions.info/email.html ... need to check it's sensible! **/
		return new Ereg( "^[a-z0-9!#$%&'*+/=?^_`{|}~-]+(?:\.[a-z0-9!#$%&'*+/=?^_`{|}~-]+)*@(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$", "i" )
		.match( email );
	}
}
