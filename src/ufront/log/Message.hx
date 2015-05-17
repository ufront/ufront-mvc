package ufront.log;

import haxe.PosInfos;

/** A `Message` contains information similar to a `trace`, but also adds a `MessageType` to differentiate messages by severity. **/
typedef Message = {
	/** The message being traced. **/
	public var msg:Dynamic;
	/** The position information, including any extra parameters included in the trace. **/
	public var pos:PosInfos;
	/** The type of the message. **/
	public var type:MessageType;
}

/** A simple enum to differentiate the severity of the message being logged. **/
enum MessageType {
	Trace;
	Log;
	Warning;
	Error;
}
