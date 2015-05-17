package ufront.log;

/**
A class that can be used to take messages, and either push them to an array, or process them immediately.

In some contexts, for example, the remoting APIs, we are not sure if we want to:

1. collect traces and process them all together at a later stage (eg in a Http Context, where we log to file or browser at the end of the request).
2. display the traces immediately (eg in a UFTaskSet context or in an interactive context).

This class is a generic implementation that allows us to do either or both.

See `UFApi.messages` for the main place this class is used.
**/
class MessageList {

	/**
	The messages array to push each message to.
	This is used if we are collecting messages to process at the end of a request.

	Read-only, set via the constructor.
	**/
	public var messages(default,null):Null<Array<Message>>;

	/**
	The callback to process each message as it comes through.
	This is used if we wish to process and display a message immediately, rather than waiting until the end of a request.

	Read-only, set via the constructor.
	**/
	public var onMessage(default,null):Null<Message->Void>;

	/** Create a new MessageList, parsing in the desired values for `this.messages` and `this.onMessage`. **/
	public function new( ?messages:Array<Message>, ?onMessage:Message->Void ) {
		this.messages = messages;
		this.onMessage = onMessage;
	}

	/** Process a new message using the `this.messages` array or `this.onMessage` callback, if they have been provided. **/
	public function push( m:Message ) {
		if (messages!=null) messages.push( m );
		if (onMessage!=null) onMessage( m );
	}
}
