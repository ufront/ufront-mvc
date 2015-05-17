package ufront.log;

import ufront.web.context.HttpContext;
import ufront.app.*;
import haxe.PosInfos;
import ufront.core.AsyncTools;
using thx.Types;

/**
Trace module that adds a `hxt` line to haxe remoting call, that can be interpreted by either `ufront.remoting.HttpAsyncConnection` or `ufront.remoting.HttpConnection`.

When `log` is fired, this will flush the messages (traces, logs, warnings and errors) from the current context to the remoting response.

If `-debug` is defined, any application level messages (those from "trace" rather than "ufTrace", which may not necessarily be associated with this request) will also be sent to the remoting response.

If the `HttpRequest` does not contain the `X-Ufront-Remoting` header, or the `HttpResponse.contentType` is not "application/x-haxe-remoting", the traces will not be displayed.
**/
class RemotingLogger implements UFLogHandler {
	public function new() {}

	public function log( httpContext:HttpContext, appMessages:Array<Message> ) {

		if( httpContext.request.clientHeaders.exists("X-Ufront-Remoting") && httpContext.response.contentType=="application/x-haxe-remoting" ) {
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

		return SurpriseTools.success();
	}

	static function formatMessage( m:Message ):String {
		// Make sure everything is converted to a String before we serialize it.
		m.msg = ''+m.msg;
		if ( m.pos.customParams != null) {
			m.pos.customParams = [ for (p in m.pos.customParams) ""+p ];
		}

		return "hxt" + haxe.Serializer.run(m);
	}
}
