package ufront.log;

import ufront.web.context.HttpContext;
import ufront.app.*;
import haxe.PosInfos;
import ufront.core.Sync;
using Types;

/**
	Trace module that adds javascript snippet to output trace to Javascript console.
	
	This will flush the messages (traces, logs, warnings and errors) from the current context to the browser.

	If `-debug` is defined, any application level messages (not necessarily associated with this request) will also be sent to the browser.
		
	If the `HttpResponse` output type is not "text/html", the traces will not be displayed.

	The trace output will be added as an inline javascript snippet at the very end of the response, after the closing `</html>` tag.

	This module will respect the trace types specified in the `haxe.log.Message`, using `console.log`, `console.info`, `console.warn` and `console.error` as appropriate.
**/
class BrowserConsoleLogger implements UFLogHandler
{
	/** A reference to the applications messages, so we can also flush those if required **/
	var appMessages:Array<Message>;

	public function new() {}

	public function log( ctx:HttpContext, appMessages:Array<Message> ) {

		if( ctx.response.contentType=="text/html" ) {
			var results = [];
			for( msg in ctx.messages )
				results.push( formatMessage(msg) );
			
			#if debug
				if ( appMessages!=null) {
					for( msg in appMessages )
						results.push( formatMessage(msg) );
				}
			#end
			
			if( results.length>0 ) {
				ctx.response.write(
					'\n<script type="text/javascript">\n${results.join("\n")}\n</script>'
				);
			}
		}

		return Sync.success();
	}

	function formatMessage( m:Message ):String {
		var type = switch (m.type) {
			case Trace: "log";
			case Log: "info";
			case Warning: "warn";
			case Error: "error";
		}
		var extras = 
			if ( m.pos!=null && m.pos.customParams!=null ) " "+m.pos.customParams.join(" ")
			else "";
		var msg = '${m.pos.className}.${m.pos.methodName}(${m.pos.lineNumber}): ${m.msg}$extras';
		return 'console.${type}(decodeURIComponent("${StringTools.urlEncode(msg)}"))';
	}
}