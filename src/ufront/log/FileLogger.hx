package ufront.log;

import sys.io.File;
import ufront.application.*;
import haxe.PosInfos;
import sys.io.FileOutput;
import ufront.web.context.HttpContext;
import ufront.module.IHttpModule;
using Types;

/**
	Trace module that logs traces to a file.

	During the `onLogRequest` event, this will open a file (relative to the `HttpContext.contentDirectory`) and append entries to the log.

	This will log traces, logs, warnings and errors from the current request.  	If the current application is a UfrontApplication, it will also log messages which are not associated with a particular request.

	Entries are as follows:

	- A general request log: `$datetime [$method] [$uri] from [$clientIP] with session [$sessionID], response: [$code $contentType]`
	- Any messages from the HttpContext, in the format `\t[$messageType] $className($line): "$message"` (note the leading tab)
	- Any messages from the UfrontApplication, in the same format.

	New lines will be removed from the log, and added as a literal "\n".

	Example output:

	```
	2013-09-18 11:11:07 [GET] [/staff/view/1033/] from [10.1.1.36] with session [2AijlXS3PUbxnaoFYc1pVQwPtMzigWAPfYB2y6x2], response: [200 text/html]
	2013-09-18 11:11:07 [POST] [/remoting/] from [10.1.1.36] with session [null], response: [500 text/html]
		[Error] ufront.module.ErrorModule._onError(64): "Handling error: cgi.c(165) : Cannot set Return code : Headers already sent"
		[Trace] ufront.application.HttpApplication._conclude(263): "in _conclude()"
	2013-09-18 11:11:07 [POST] [/remoting/] from [10.1.1.36] with session [2AijlXS3PUbxnaoFYc1pVQwPtMzigWAPfYB2y6x2], response: [500 text/html]
	```

	The file will be flushed after the log is written, and closed when the module is disposed
**/
class FileLogger implements IHttpModule
{
	/** A reference to the applications messages, so we can also flush those if required **/
	var appMessages:Array<Message>;

	/** the relative path to the log file **/
	var path:String;

	/** the currently open file **/
	var file:FileOutput;

	// var file:
	
	/**
		Initiate the new module.  Specify the path to the file that you will be logging to.
	**/
	public function new( path:String ) {
		this.path = path;
	}

	/** Initialize the module **/
	public function init( application:HttpApplication ) {
		application.onLogRequest.add( writeFile );
		application.ifIs( UfrontApplication, function(ufrontApp) {
			appMessages = ufrontApp.messages;
		});
	}

	public function dispose() {
		path = null;
		appMessages = null;
		if ( file!=null ) {
			file.close();
			file = null;
		}
	}

	function writeFile( context:HttpContext ) {
		if ( file==null ) {
			file = File.append( context.contentDirectory + path );
		}

		var req = context.request;
		var res = context.response;
		var sessionID = ( context.isSessionActive() ) ? ' with session [${context.session.getID()}]' : "";
		file.writeString( '${Date.now()} [${req.httpMethod}] [${req.uri}] from [${req.clientIP}]$sessionID, response: [${res.status} ${res.contentType}]\n' );

		for( msg in context.messages )
			file.writeString( format(msg) );
		if ( appMessages!=null) {
			for( msg in appMessages )
				file.writeString( format(msg) );
		}

		file.flush();
	}

	static var REMOVENL = ~/[\n\r]/g;
	static function format( msg:Message ) {
		var text = REMOVENL.replace( Dynamics.string(msg.msg), '\\n' );
		var type = Type.enumConstructor( msg.type );
		var pos = msg.pos;
		return '\t[$type] ${pos.className}.${pos.methodName}(${pos.lineNumber}): $text\n';
	}
}