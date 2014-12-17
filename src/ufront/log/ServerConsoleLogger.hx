package ufront.log;

import ufront.web.context.HttpContext;
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
		for( msg in ctx.messages )
			logMessage( msg );

		if ( appMessages!=null) {
			for( msg in appMessages )
				logMessage( msg );
		}

		return Sync.success();
	}

	public static function logMessage( m:Message ):Void {
		var extras =
			if ( m.pos!=null && m.pos.customParams!=null ) ", "+m.pos.customParams.join(", ")
			else "";
		var message = '${m.type}: ${m.pos.className}.${m.pos.methodName}(${m.pos.lineNumber}): ${m.msg}$extras';

		#if neko
			neko.Web.logMessage( message );
		#elseif php
			untyped __call__( "error_log", message );
		#elseif js
			var console:js.html.Console = untyped console;
			switch (m.type) {
				case Trace: console.log( message );
				case Log: console.info( message );
				case Warning: console.warn( message );
				case Error: console.error( message );
			}
		#end
	}
}
