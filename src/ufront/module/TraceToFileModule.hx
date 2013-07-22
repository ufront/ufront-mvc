package ufront.module;

import sys.io.File;
import ufront.application.HttpApplication;
import haxe.PosInfos;

/**
	Trace module that logs traces to a file.

	On the first trace, the given file will be opened with `sys.io.File.append`. 

	Every time `trace()` is called the trace will be written to the file.

	New lines will be removed from the log, and added as a literal "\n".

	The Date (YYYY-MM-DD hh:mm:ss) will be included at the start of each line.

	The file will be closed at the end of the request.
**/
class TraceToFileModule implements ITraceModule
{
	var file:haxe.io.Output;
	var path:String;
	static var REMOVENL = ~/[\n\r]/g;
	
	/**
		Initiate the new module.  Specify the path to the file that you will be logging to.
	**/
	public function new( path:String ) {
		this.path = path;
	}

	/** Initialize the module **/
	public function init( application:HttpApplication ) {
		application.onLogRequest.add( closeFile );
	}

	/** 
		Trace function.  
		Will be called by the custom trace implemented in `ufront.application.UfrontApplication`.
	**/
	public function trace( msg:Dynamic, ?pos:PosInfos ):Void {
		getFile().writeString( format(msg, pos) + "\n" );
	}

	/**
		Close the file and prevent this instance of the module being re-used
	**/
	public function dispose() {
		path = null; // prevents reusing the instance
	}

	function closeFile( context ) {
		if( null==file )
			return;
		file.close();
		file = null;
	}

	static function format( msg:Dynamic, pos:PosInfos ) {
		msg = REMOVENL.replace( msg, '\\n' );
		return '${Date.now()}: ${pos.className}.${pos.methodName}(${pos.lineNumber}) ${Dynamics.string(msg)}';
	}

	function getFile() {
		if( null==file )
			file = File.append( path );
		return file;
	}
}