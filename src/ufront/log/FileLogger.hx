package ufront.log;

#if sys
	import sys.FileSystem;
	import sys.io.File;
	import sys.io.FileOutput;
#elseif nodejs
	import js.node.Fs;
	using ufront.core.SurpriseTools;
#end
import ufront.app.*;
import haxe.PosInfos;
import ufront.sys.SysUtil;
import ufront.web.context.HttpContext;
import ufront.core.AsyncTools;
using tink.CoreApi;
using haxe.io.Path;

/**
Trace module that logs traces to a file.

During the `onLogRequest` event, this will open a file (relative to the `HttpContext.contentDirectory`) and append entries to the log.

This will log traces, logs, warnings and errors from the current request.
It will also log messages from `HttpApplication.messages`, which may not associated with a particular request.

Entries are as follows:

- A general request log: `$datetime [$method] [$uri] from [$clientIP] with session [$sessionID], response: [$code $contentType]`
- Any messages from the HttpContext, in the format `\t[$messageType] $className($line): "$message"` (note the leading tab)
- Any messages from the HttpApplication, in the same format.

New lines will be removed from the log, and added as a literal "\n".

Example output:

```
2013-09-18 11:11:07 [GET] [/staff/view/1033/] from [10.1.1.36] with session [2AijlXS3PUbxnaoFYc1pVQwPtMzigWAPfYB2y6x2], response: [200 text/html]
2013-09-18 11:11:07 [POST] [/remoting/] from [10.1.1.36] with session [null], response: [500 text/html]
	[Error] ufront.module.ErrorModule._onError(64): "Handling error: cgi.c(165) : Cannot set Return code : Headers already sent"
	[Trace] ufront.application.HttpApplication._conclude(263): "in _conclude()"
2013-09-18 11:11:07 [POST] [/remoting/] from [10.1.1.36] with session [2AijlXS3PUbxnaoFYc1pVQwPtMzigWAPfYB2y6x2], response: [500 text/html]
```

The file will be opened, written to, and closed for each request during the `FileLogger.log()` method.
**/
class FileLogger implements UFLogHandler implements UFInitRequired {
	/** The relative or absolute path to the log file. **/
	public var path(default,null):String;

	public function new( path:String ) {
		this.path = path;
	}

	public function init( app:HttpApplication ) {
		return SurpriseTools.success();
	}

	/** Close the log file, dispose of the module **/
	public function dispose( app:HttpApplication ) {
		path = null;
		return SurpriseTools.success();
	}

	/** Write any messages from the context or application. **/
	public function log( context:HttpContext, appMessages:Array<Message> ):Surprise<Noise,Error> {
		var logFile = context.contentDirectory+path;
		var req = context.request;
		var res = context.response;
		var userDetails = req.clientIP;
		if ( context.sessionID!=null ) userDetails += ' ${context.sessionID}';
		if ( context.currentUserID!=null ) userDetails += ' ${context.currentUserID}';

		var content = '${Date.now()} [${req.httpMethod}] [${req.uri}] from [$userDetails], response: [${res.status} ${res.contentType}]\n';
		for( msg in context.messages )
			content += '\t${format(msg)}\n';
		if ( appMessages!=null) for( msg in appMessages )
			content += '\t${format(msg)}\n';

		#if sys
			SysUtil.mkdir( logFile.directory() );
			var file = File.append( context.contentDirectory + path );
			file.writeString( content );
			file.close();
			return SurpriseTools.success();
		#elseif nodejs
			return Fs.appendFile.bind( logFile, content ).asVoidSurprise();
		#else
			return throw "Not implemented";
		#end
	}

	/** Format a message in a suitable way for a text-only log file. **/
	static function format( msg:Message ) {
		var msgStr = Std.string( msg.msg );
		var text = REMOVENL.replace( msgStr, '\\n' );
		var type = Type.enumConstructor( msg.type );
		var pos = msg.pos;
		return '[$type] ${pos.className}.${pos.methodName}(${pos.lineNumber}): $text';
	}

	static var REMOVENL = ~/[\n\r]/g;
}
