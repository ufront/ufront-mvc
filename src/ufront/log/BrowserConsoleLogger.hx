package ufront.log;

import ufront.web.context.HttpContext;
import ufront.app.*;
import haxe.PosInfos;
import ufront.web.result.CallJavascriptResult;
import ufront.core.AsyncTools;

/**
Logger module that prints to a JS console, either on the client directly, or on the server by adding a JS snippet to the output.

This will flush the messages (traces, logs, warnings and errors) from the current context to the browser.

This module will respect the trace types specified in the `haxe.log.Message`, using `console.log`, `console.info`, `console.warn` and `console.error` as appropriate.

__Server Behaviour__

On the server, if `-debug` is defined, any application level messages (not necessarily associated with this request, made using "trace()" rather than "ufTrace()") will also be sent to the browser.

If the `HttpResponse` output type is not "text/html", the traces will not be displayed.

The trace output will be added as an inline javascript snippet at the very end of the response, before the closing `</body>` tag.

__Client Behaviour__

If running client-side, the message will be traced to the console directly using Javascript.
**/
class BrowserConsoleLogger implements UFLogHandler {
	var messageFormatter:UFMessageFormatter;
	
	public function new(?messageFormatter:UFMessageFormatter) {
		this.messageFormatter = messageFormatter == null ? new MessageFormatter() : messageFormatter;
	}

	public function log( ctx:HttpContext, appMessages:Array<Message> ) {
		#if server
			if( ctx.response.contentType=="text/html" && !ctx.response.isRedirect() ) {
				var results = [];
				for( msg in ctx.messages )
					results.push( messageFormatter.format(msg) );

				#if debug
					if ( appMessages!=null) {
						for( msg in appMessages )
							results.push( messageFormatter.format(msg) );
					}
				#end

				if( results.length>0 ) {
					var script = '\n<script type="text/javascript">\n${results.join("\n")}\n</script>';
					var newContent = CallJavascriptResult.insertScriptsBeforeBodyTag( ctx.response.getBuffer(), [script] );
					ctx.response.clearContent();
					ctx.response.write( newContent );
				}
			}
		#elseif client
			for ( msg in ctx.messages )
				printMessage( msg );
			for ( msg in appMessages )
				printMessage( msg );
		#end

		return SurpriseTools.success();
	}

	#if client
		/**
		A client-side helper to print the current message to the `js.html.Console`.

		This will call `Console.log`, `Console.info`, `Console.warn` or `Console.error` with several arguments:

		- A String naming the position the message was written from.
		- The main message value.
		- Ane `customParams` contained in the message.

		The main message value will *not* be coerced into a String, meaning Javascript console features allowing the inspection of objects are able to function.
		**/
		public static function printMessage( m:Message ):Void {
			var console = js.Browser.window.console;
			var logMethod = switch (m.type) {
				case MTrace: console.log;
				case MLog: console.info;
				case MWarning: console.warn;
				case MError: console.error;
			}
			var posString = '${m.pos.className}.${m.pos.methodName}(${m.pos.lineNumber})';
			var params = [posString,m.msg];
			if ( m.pos!=null && m.pos.customParams!=null )
				for ( p in m.pos.customParams )
					params.push( p );
			Reflect.callMethod( console, logMethod, params );
		}
	#end
}

/**
A helper to create a `console.log`, `console.info`, `console.warn` or `console.error` Javascript snippet.
When executed by the client, this snippet will send the given message to the client's browser console.
**/
private class MessageFormatter implements UFMessageFormatter {
	public function new(){}
	
	public function format(m:Message):String {
		var type = switch (m.type) {
			case MTrace: "log";
			case MLog: "info";
			case MWarning: "warn";
			case MError: "error";
		}
		var extras =
			if ( m.pos!=null && m.pos.customParams!=null ) ", "+m.pos.customParams.join(", ")
			else "";
		var msg = '${m.pos.className}.${m.pos.methodName}(${m.pos.lineNumber}): ${m.msg}$extras';
		return 'console.${type}(decodeURIComponent("${StringTools.urlEncode(msg)}"))';
	}
}
