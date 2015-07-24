package ufront.log;

import ufront.web.context.HttpContext;
import ufront.app.*;
import haxe.PosInfos;
import ufront.web.result.CallJavascriptResult;
import ufront.core.AsyncTools;
using tink.CoreApi;

/**
This logger uses the original trace that was in place before the `HttpApplication.init()` was called.

This is useful if that trace function was being used for unit testing etc.

Please note calls to `ufTrace`, `ufLog`, `ufWarn` and `ufError` are always passed through.
Plain `trace()` calls are only passed through when the `-debug` compilation flag is being used.
**/
class OriginalTraceLogger implements UFLogHandler implements UFInitRequired {

	var originalTrace:Dynamic->PosInfos->Void;

	public function new() {}

	public function init( app:HttpApplication ):Surprise<Noise,Error>{
		this.originalTrace = app.originalTrace;
		return SurpriseTools.success();
	}

	public function dispose( app:HttpApplication ):Surprise<Noise,Error>{
		return SurpriseTools.success();
	}

	public function log( ctx:HttpContext, appMessages:Array<Message> ) {
		for( msg in ctx.messages )
			originalTrace( msg.msg, msg.pos );

		#if debug
			if ( appMessages!=null) {
				for( msg in appMessages )
					originalTrace( msg.msg, msg.pos );
			}
		#end

		return SurpriseTools.success();
	}
}
