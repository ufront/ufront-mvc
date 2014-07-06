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