package ufront.email;

/**
	A representation of an Email Message.

	This is simple a data structure, it does not contain logic on how to send the email.  An appropriate `ufront.email.IMailer` must be used to send the message.

	This class uses a "fluent" (chainable, jQuery like) API for quickly putting together an email.

	For example: 

	```haxe
	new Email().to("boss@example.org").from("worker@example.org").subject("Where is my pay check?!?");
	```

	It is expected that you will use a subclass of email, in particular `SimpleEmail`, `MultiPartEmail`, or `EmailAddress`.
**/
class Email {

	// Variables

	public var bounceAddress(default,null):EmailAddress = null;
	public var fromAddress(default,null):EmailAddress = null;
	public var toList(default,null):List<EmailAddress>
	public var ccList(default,null):List<EmailAddress>
	public var bccList(default,null):List<EmailAddress>
	public var charset(default,null):String = null;
	public var content(default,null):String = null;
	public var contentType(default,null) = null;
	public var emailBody(default,null):MimeMultipart = null;
	public var headers(default,null):Map<String,Array<String>>
	public var message(default,null):MimeMessage = null;
	public var replyList(default,null):List<EmailAddress>
	public var date(default,null):Date;
	public var subject(default,null):String = null;

	// Constructor

	public function new() {
		toList = new List();
		ccList = new List();
		bccList = new List();
		headers = new Map();
		replyList = new List();
		date = Date.now();
	}

	// Fluent API

	/**
		Add an email address (or list of addresses) to the `toList`
	**/
	public function to( ?email:EmailAddress, ?emails:Iterable<EmailAddress> ):Email {
		if ( email!=null ) toList.add( email );
		if ( emails!=null ) for ( e in emails ) toList.add( email );
		return this;
	}

	/**
		Add an email address (or list of addresses) to the `ccList`
	**/
	public function cc( ?email:EmailAddress, ?emails:Iterable<EmailAddress> ):Email {
		if ( email!=null ) ccList.add( email );
		if ( emails!=null ) for ( e in emails ) ccList.add( email );
		return this;
	}

	/**
		Add an email address (or list of addresses) to the `bccList`
	**/
	public function bcc( ?email:EmailAddress, ?emails:Iterable<EmailAddress> ):Email {
		if ( email!=null ) bccList.add( email );
		if ( emails!=null ) for ( e in emails ) bccList.add( email );
		return this;
	}

	/**
		Add an email address (or list of addresses) to the `replyList`
	**/
	public function replyTo( ?email:EmailAddress, ?emails:Iterable<EmailAddress> ):Email {
		if ( email!=null ) replyList.add( email );
		if ( emails!=null ) for ( e in emails ) replyList.add( email );
		return this;
	}

	/**
		Set the `from` email address
	**/
	public function from( email:EmailAddress ):Email {
		fromAddress = email;
		return this;
	}

	/**
		Set the "sent date" for this email
	**/
	public function setDate( date:Date ):Email {
		this.date = date;
		return this;
	}

	/**
		Add a header.  

		If a header with the same name already exists, this will be included as well.
	**/
	public function addHeader( name, value ):Email {
		if ( headers.exists(name) )
			headers.get( name ).push( value );
		else
			headers.set( name, [value] );

		return this;
	}

	/**
		Set a header.  

		If a header with the same name already exists, this value will replace the existing value.
	**/
	public function setHeader( name, value ):Email {
		headers.set( name, [value] );
		return this;
	}

	/**
		Get a header.

		If more than one header with this name exists, it will use the first header.  

		If no such header exists, it will return `null`
	**/
	public function getHeader( name ):Null<String> {
		if ( headers.exists(name) )
			return headers.get( name )[0];
		else 
			return null;
	}

	/**
		Get all headers with the given name as an array of strings.

		If there is only one header with the given name, the array will contain only one item.

		If no such header exists, an empty array will be returned.  
	**/
	public function getHeadersNamed( name ):Array<String> {
		if ( headers.exists(name) )
			return headers.get( name );
		else 
			return [];
	}

	/**
		Get all the headers set.

		The order of the headers is not guaranteed to be the order you added them, or the order required for sending.  The `ufront.mail.IMailer` needs to take care of that.

		Returns an array where each item is an object containing a name and a value.
	**/
	public function getHeaders():Array<{ name:String, value:String }> {
		var arr = [];
		for ( n in headers.keys() ) {
			for ( v in headers.get(n) ) {
				arr.push({ name: n, value: v });
			}
		}
		return arr;
	}

	/**
		Set the subject for this email
	**/
	public function subject( ?subject:String="" ):Email {
		this.subject = subject;
		return this;
	}

	/**
		Set the content type for this email
	**/
	public function setContentType( contentType:String ):Email {
		this.contentType = contentType;
		return this;
	}

	/**
		Set the content for this email.

		@todo define what content exactly this is...
	**/
	public function setContent( content:String ):Email {
		this.content = content;
		return this;
	}
}