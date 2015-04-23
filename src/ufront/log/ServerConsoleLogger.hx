package ufront.log;

import ufront.web.context.HttpContext;
import ufront.log.Message;
import ufront.app.*;
import haxe.PosInfos;
import ufront.core.Sync;
using thx.core.Types;

/**
	Trace module that prints to the server console where it makes sense to do so.

	This will use a different method on each platform where it makes sense:

	- `neko.Web.logMessage()` on Neko.
	- `error_log()` on PHP.
	- `console.log()`, `console.info()`, `console.warn()`, and `console.error()` on JS.

	This will flush the messages (traces, logs, warnings and errors) from the current context to the appropriate server log.
**/
class ServerConsoleLogger implements UFLogHandler
{
	public function new() {}

	public function log( ctx:HttpContext, appMessages:Array<Message> ) {
		var messages = [];

		var userDetails = ctx.request.clientIP;
		if ( ctx.sessionID!=null ) userDetails += ' ${ctx.sessionID}';
		if ( ctx.currentUserID!=null ) userDetails += ' ${ctx.currentUserID}';
		var requestLog = '[${ctx.request.httpMethod} ${ctx.request.uri}] from [$userDetails], response: [${ctx.response.status} ${ctx.response.contentType}]';

		messages.push( requestLog );

		for( msg in ctx.messages )
			messages.push( formatMsg(msg) );

		if ( appMessages!=null) {
			for( msg in appMessages )
				messages.push( formatMsg(msg) );
		}

		writeLog( messages.join("\n  ") );

		return Sync.success();
	}

	public static function formatMsg( m:Message ):String {
		var extras =
			if ( m.pos!=null && m.pos.customParams!=null ) ", "+m.pos.customParams.join(", ")
			else "";
		return '${m.type}: ${m.pos.className}.${m.pos.methodName}(${m.pos.lineNumber}): ${m.msg}$extras';
	}

	public static function writeLog( message:String, ?type:MessageType=null ):Void {
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
