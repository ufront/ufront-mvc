package ufront.module;

import haxe.CallStack;
import ufront.web.error.InternalServerError;
import ufront.web.error.HttpError;
import ufront.application.HttpApplication;
import ufront.module.IHttpModule;
import haxe.ds.StringMap;
import thx.error.Error;
using DynamicsT;
using Strings;
using Types;

/**
	A module which adds an error handler to your application.

	If an error is of the type `ufront.web.error.HttpError`, it will display the details of the given error.

	Otherwise, it will wrap the exception in a `ufront.web.error.InternalServerError`.

	It will display the error message in a simple template, and set the appropriate HTTP response code.
**/
class ErrorModule implements IHttpModule
{
	public function new(){}

	var application:HttpApplication;

	/**
		HttpModule initialization.  

		Will add the error handler to the `onApplicationError` event of your `HttpApplication`.
	**/
	public function init(application : HttpApplication) {
		this.application = application;
		application.onApplicationError.add(_onError);
	}

	/** Nothing much to dispose for this module. **/
	public function dispose() {}

	/**
		Event handler for an error on HttpApplication.
		
		It will use a HttpError, or wrap a different kind of exception in an InternalServerError, and display an appropriate error message.

		Http Response Codes will be set as per the HttpError, and any existing output will be cleared.

		You can change the output by overriding the 

		TODO: give more options for processing different kinds of errors
		TODO: figure out async support
	**/
	public function _onError(e : { application : HttpApplication, error : Error })
	{
		// Get the error into the HttpError type, wrap it if necessary
		var httpError : HttpError;
		if( !Std.is(e.error, HttpError) ) {
			httpError = new InternalServerError();
			httpError.setInner(e.error);
		}
		else httpError = cast e.error;

		// Is this required?
		var action = httpError.className().lcfirst();
		if("httpError" == action)
			action = "internalServerError";

		var showStack = #if debug true #else false #end;

		// Clear the output, set the response code, and output.
		application.response.clear();
		application.response.status = httpError.code; 
		application.response.write( renderError(httpError, showStack) );
		application.completeRequest();
	}

	/**
		Render the given error message into a String (usually HTML) to be sent to the browser.

		You can override this function if you wish to supply a different error template.

		It is recommended that this method have as few dependencies as possible, for example,
		avoid using templating engines as any errors in displaying the error template will not
		be displayed correctly.
	**/
	dynamic public function renderError(error : HttpError, ?showStack:Bool = false):String
	{
		var inner = (null != error.inner) ? '<p>' + error.inner.toString() + '</p>' : "";
		
		var exceptionStackItems = errorStackItems( CallStack.exceptionStack() );
		var callStackItems = errorStackItems( CallStack.callStack() );

		var exceptionStack = 
			if ( showStack && exceptionStackItems.length>0 ) 
				'<div><p><i>exception stack:</i></p>\n<ul><li>' + exceptionStackItems.join("</li><li>") + '</li></ul></div>'
			else "";

		var callStack = 
			if ( showStack && callStackItems.length>0 ) 
				'<div><p><i>call stack:</i></p>\n<ul><li>' + callStackItems.join("</li><li>") + '</li></ul></div>'
			else "";
		
		return '<!doctype html>
<html>
	<head>
		<title>$error</title>
		<style>
			body { text-align: center;}
			h1 { font-size: 50px; }
			body { font: 20px Constantia, "Hoefler Text",  "Adobe Caslon Pro", Baskerville, Georgia, Times, serif; color: #999; text-shadow: 2px 2px 2px rgba(200, 200, 200, 0.5)}
			a { color: rgb(36, 109, 56); text-decoration:none; }
			a:hover { color: rgb(96, 73, 141) ; text-shadow: 2px 2px 2px rgba(36, 109, 56, 0.5) }
			span[frown] { transform: rotate(90deg); display:inline-block; color: #bbb; }
		</style>
	</head>
	<body>
		<details>
			<summary><h1>$error</h1></summary>  
			$inner
			$exceptionStack
			$callStack
			<p><span frown>:(</p>
		</details>
	</body>
</html>';
	}
	
	/**
		Turns an `Array<StackItem>` into an `Array<String>`, ready to print.
	**/
	public static function errorStackItems( stack:Array<StackItem> ) : Array<String> {
		var arr = [];

		#if php
			stack.pop();
			stack = stack.slice(2);
		#end

		for(item in stack)
			arr.push(stackItemToString(item));

		return arr;
	}

	private static function stackItemToString(s:StackItem) {
		switch( s ) {
		case Module(m):
			return "module " + m;
		case CFunction:
			return "a C function";
		case FilePos(s,file,line):
			var r = "";
			if( s != null ) {
				r += stackItemToString(s) + " (";
			}
			r += file + " line " + line;
			if( s != null ) 
				r += ")";
			return r;
		case Method(cname,meth):
			return cname + "." + meth;
		case Lambda(n):
			return "local function #" + n;
		}
	}
}