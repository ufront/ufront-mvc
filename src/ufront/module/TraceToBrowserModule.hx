package ufront.module;

import ufront.web.context.HttpContext;
import ufront.application.HttpApplication;
import haxe.PosInfos;

/**
	Trace module that adds javascript snippet to output trace to Javascript console.

	Every time `trace()` is called it is added to the collection of messages.  
	When "onLogRequest" is fired, it will add the traces as a Javascript snippet at the bottom of the page.
	
	If the `HttpResponse` output type is not "text/html", the traces will not be displayed.

	If a customParam[0] is provided in the traces `PosInfos`, it can specify whether to use "log", "warn", "error" or "debug" methods of the browser console.
	By default it will use `console.log`.
**/
class TraceToBrowserModule implements ITraceModule
{
	var messages:Array<{ msg:Dynamic, pos:PosInfos }>;
	
	public function new() {
		messages = [];
	}

	public function init( application:HttpApplication ) {
		application.onLogRequest.add( _sendContent );
	}

	public function trace( msg:Dynamic, ?pos:PosInfos ):Void {
		messages.push( { msg:msg, pos:pos } );
	}

	public function dispose() {

	}

	function _sendContent( application:HttpContext ) {
		
		if( application.response.contentType!="text/html" ) {
			messages = [];
			return;
		}
		
		var results = [];
		for( msg in messages )
			results.push( _formatMessage(msg) );
		
		if( results.length>0 ) {
			application.response.write(
				'\n<script type="text/javascript">\n${results.join("\n")}\n</script>'
			);
		}

		messages = [];
	}

	function _formatMessage( m:{ msg:Dynamic, pos:PosInfos } ):String {
		var type = ( m.pos!=null && m.pos.customParams!=null ) ? m.pos.customParams[0] : null;
		if ( type!="warn" && type!="info" && type!="debug" && type!="error" )
			type = ( m.pos==null ) ? "error" : "log";
	   	var msg = '${m.pos.className}.${m.pos.methodName}(${m.pos.lineNumber}): ${m.msg}';
	   	return 'console.${type}(decodeURIComponent("${StringTools.urlEncode(msg)}"))';
	}
}