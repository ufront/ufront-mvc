package ufront.module;

import haxe.CallStack;
import ufront.web.error.InternalServerError;
import ufront.web.error.HttpError;
import ufront.application.HttpApplication;
import ufront.web.context.HttpContext;
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
	/**
		A flag for catching and handling errors.

		The only reason you would disable this is for debugging or unit testing.  

		`true` by default.
	**/
	public var catchErrors:Bool = true;

	public function new() {}

	/**
		HttpModule initialization.  

		Will add the error handler to the `onApplicationError` event of your `HttpApplication`.
	**/
	public function init( application:HttpApplication ) {
		application.onApplicationError.handle( _onError );
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
	public function _onError( e:{ context:HttpContext, error:Dynamic } )
	{
		// Pass the error to our log...
		var callStack = #if debug " "+CallStack.toString( CallStack.exceptionStack() ) #else "" #end;
		e.context.ufError( 'Handling error: ${e.error}$callStack' );

		// Get the error into the HttpError type, wrap it if necessary
		var httpError:HttpError;
		if( !Std.is(e.error, HttpError) ) {
			httpError = new InternalServerError( e.error );
		}
		else httpError = cast e.error;

		var showStack = #if debug true #else false #end;

		// Clear the output, set the response code, and output.
		e.context.response.clear();
		e.context.response.status = httpError.code; 
		e.context.response.contentType = "text/html";
		e.context.response.write( renderError(httpError,showStack) );
		e.context.completed = true;

		// rethrow error if catchErrors has been disabled
		if (!catchErrors) throw e.error;
	}

	/**
		Render the given error message into a String (usually HTML) to be sent to the browser.

		You can override this function if you wish to supply a different error template.

		It is recommended that this method have as few dependencies as possible, for example,
		avoid using templating engines as any errors in displaying the error template will not
		be displayed correctly.

		It is also expected that this method should be synchronous.
	**/
	dynamic public function renderError( error:HttpError, ?showStack:Bool=false ):String {
		var inner = (null!=error.data) ? '<p>${error.data}</p>':"";
		
		var exceptionStackItems = errorStackItems( CallStack.exceptionStack() );
		var callStackItems = errorStackItems( CallStack.callStack() );

		var exceptionStack = 
			if ( showStack && exceptionStackItems.length>0 ) 
				'<div><h3>Exception Stack:</h3>
					<pre><code>' + exceptionStackItems.join("\n") + '</pre></code>
				</div>'
			else "";

		var callStack = 
			if ( showStack && callStackItems.length>0 ) 
				'<div><h3>Call Stack:</h3>
					<pre><code>' + callStackItems.join("\n") + '</pre></code>
				</div>'
			else "";
		
		return CompileTime.interpolateFile( "ufront/web/ErrorPage.html" );
	}
	
	/**
		Turns an `Array<StackItem>` into an `Array<String>`, ready to print.
	**/
	public static function errorStackItems( stack:Array<StackItem> ):Array<String> {
		var arr = [];

		#if php
			stack.pop();
			stack = stack.slice( 2 );
		#end

		for( item in stack )
			arr.push( stackItemToString(item) );

		return arr;
	}

	private static function stackItemToString( s:StackItem ) {
		switch( s ) {
		case Module( m ):
			return 'module $m';
		case CFunction:
			return "a C function";
		case FilePos( s, file, line ):
			var r = "";
			if( s != null ) {
				r += stackItemToString( s ) + " (";
			}
			r += '$file line $line';
			if( s != null ) 
				r += ")";
			return r;
		case Method( cname, meth ):
			return '$cname.$meth';
		case #if (haxe_ver >= 3.1) LocalFunction #else Lambda #end(n):
			return 'local function #$n';
		}
	}
}