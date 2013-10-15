package ufront.log;

import ufront.web.context.HttpContext;
import ufront.application.*;
import ufront.module.IHttpModule;
import haxe.PosInfos;
using Types;

/**
	Trace module that adds a "hxt" line to haxe remoting call, that can work with `ufront.remoting.HttpAsyncConnectionWithTraces`

	When `onLogRequest` is fired, this will flush the messages (traces, logs, warnings and errors) from the current context to the remoting response.

	If `-debug` is defined, any application level messages (not necessarily associated with this request) will also be sent to the remoting response.
		
	If the `HttpResponse` output type is not "application/x-haxe-remoting", the traces will not be displayed.
**/
class RemotingLogger implements IHttpModule
{
	/** A reference to the applications messages, so we can also flush those if required **/
	var appMessages:Array<Message>;

	public function new() {}

	public function init( application:HttpApplication ) {
		application.onLogRequest.add( _sendContent );
		application.ifIs( UfrontApplication, function(ufrontApp) {
			appMessages = ufrontApp.messages;
		});
	}

	public function dispose() {}

	function _sendContent( httpContext:HttpContext ) {

		if( httpContext.response.contentType!="application/x-haxe-remoting" ) {
			return;
		}
		
		var results = [];
		for( msg in httpContext.messages )
			results.push( formatMessage(msg) );
		
		#if debug
			if ( appMessages!=null) {
				for( msg in appMessages )
					results.push( formatMessage(msg) );
			}
		#end
		
		if( results.length>0 ) {
			httpContext.response.write( '\n' + results.join("\n") );
		}
	}

	function formatMessage( m:Message ):String {
		// Make sure everything is toString()'d before we serialize it
		m.msg = try Std.string( m.msg ) catch ( e:Dynamic ) "ERROR: unable to format message in RemotingLogger.formatMessage";
		if ( m.pos.customParams != null)
			m.pos.customParams = m.pos.customParams.map( function (v) return Std.string(v) );

		return "hxt" + haxe.Serializer.run(m);
	}
}