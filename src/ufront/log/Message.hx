package ufront.log;

import haxe.PosInfos;

typedef Message = {
	msg: Dynamic,
	pos: PosInfos,
	type: MessageType
}

/**
	A simple enum to differentiate what sort of message was being traced.
**/
enum MessageType {
	Trace;
	Log;
	Warning;
	Error;
}

/**
	A class that can be used to take messages, and either push them to an array, or process them immediately.

	In some contexts, for example, the remoting APIs, we are not sure if we want to:

	1. collect traces and process them all together at a later stage (eg in a Http Context, where we log to file or browser at the end of the request).
	2. display the traces immediately (eg in a UFTask context or in an interactive context).

	This class is a generic implementation that allows us to do either or both.

	This would be better written as an abstract or typedef wrapping `Message->Void`, but minject only allows injecting class instances at this time.

	See `ufront.api.UFApi.messages` for the main place this class is used.
**/
class MessageList {

	/** The messages array to push each message to.  Set via the constructor. **/
	public var messages(default,null):Null<Array<Message>>;

	/** The callback to process each message as it comes through.  Set via the constructor. **/
	public var onMessage(default,null):Null<Message->Void>;

	/** Create a new MessageList, parsing in either an array or callback, or both. **/
	public function new( ?messages:Array<Message>, ?onMessage:Message->Void ) {
		this.messages = messages;
		this.onMessage = onMessage;
	}

	/** Process a new message. **/
	public function push( m:Message ) {
		if (messages!=null) messages.push( m );
		if (onMessage!=null) onMessage( m );
	}
}