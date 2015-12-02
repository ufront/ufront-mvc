package ufront.log;

import ufront.web.context.HttpContext;
import ufront.log.Message;
import ufront.app.*;
import haxe.PosInfos;
import ufront.core.AsyncTools;

/**
Trace module that prints to the server console where it makes sense to do so.

This will use a different method on each platform where it makes sense:

- `neko.Web.logMessage()` on Neko and Tora.
- `error_log()` on PHP.
- `console.log()`, `console.info()`, `console.warn()`, and `console.error()` on JS.

This will flush the messages (traces, logs, warnings and errors) from the current context to the appropriate server log.
**/
class ServerConsoleLogger implements UFLogHandler {
	var messageFormatter:UFMessageFormatter;
	
	public function new(?messageFormatter:UFMessageFormatter) {
		this.messageFormatter = messageFormatter == null ? new MessageFormatter() : messageFormatter;
	}


	public function log( ctx:HttpContext, appMessages:Array<Message> ) {
		var messages = [];

		var userDetails = ctx.request.clientIP;
		try {
			if ( ctx.sessionID!=null ) userDetails += ' ${ctx.sessionID}';
			if ( ctx.currentUserID!=null ) userDetails += ' ${ctx.currentUserID}';
		}
		catch (e:Dynamic) {}
		var requestLog = '[${ctx.request.httpMethod} ${ctx.request.uri}] from [$userDetails], response: [${ctx.response.status} ${ctx.response.contentType}]';

		messages.push( requestLog );

		for( msg in ctx.messages )
			messages.push( messageFormatter.format(msg) );

		if ( appMessages!=null) {
			for( msg in appMessages )
				messages.push( messageFormatter.format(msg) );
		}

		writeLog( messages.join("\n  ") );

		return SurpriseTools.success();
	}

	static function writeLog( message:String, ?type:MessageType=null ):Void {
		#if neko
			neko.Web.logMessage( message );
		#elseif php
			untyped __call__( "error_log", message );
		#elseif js
			// We're choosing to include these all as one 'log', rather than separate 'log', 'warn', 'trace' and 'error' entries.
			var console:js.html.Console = untyped console;
			console.log( message );
		#end
	}
}

private class MessageFormatter implements UFMessageFormatter {
	public function new() {}
	
	public function format(m:Message):String {
		var extras =
			if ( m.pos!=null && m.pos.customParams!=null ) ", "+m.pos.customParams.join(", ")
			else "";
		var type = Type.enumConstructor( m.type ).substr( 1 );
		return '$type: ${m.pos.className}.${m.pos.methodName}(${m.pos.lineNumber}): ${m.msg}$extras';
	}
}