package ufront.handler;

import haxe.CallStack;
import tink.core.Error;
import ufront.web.HttpError;
import ufront.app.*;
import ufront.core.Sync;
import ufront.web.context.HttpContext;
import haxe.ds.StringMap;
import thx.error.Error;
using DynamicsT;
using Strings;
using Types;

/**
	A module which adds an error handler to your application.

	If an error is of the type `ufront.web.error.HttpError`, it will display the details of the given error.

	Otherwise, it will wrap the exception with `ufront.web.HttpError.internalServerError()`.

	It will display the error message in a simple template, and set the appropriate HTTP response code.
**/
class ErrorPageHandler implements UFErrorHandler
{
	/**
		A flag for catching and handling errors.

		The only reason you would disable this is for debugging or unit testing.  

		`true` by default.
	**/
	public var catchErrors:Bool = true;

	public function new() {}

	/**
		Event handler for an error on HttpApplication.
		
		It will use a HttpError, or wrap a different kind of exception in an InternalServerError, and display an appropriate error message.

		Http Response Codes will be set as per the HttpError, and any existing output will be cleared.

		You can change the output by overriding the 

		TODO: give more options for processing different kinds of errors
		TODO: figure out async support
	**/
	@:access( ufront.web.HttpError )
	public function handleError( e:Dynamic, ctx:HttpContext, currentModule:String ) {
		// Pass the error to our log...
		var callStack = #if debug " "+CallStack.toString( CallStack.exceptionStack() ) #else "" #end;
		ctx.ufError( 'Handling error: ${e.error}$callStack' );

		// Get the error into the HttpError type, wrap it if necessary
		var httpError:HttpError;
		if( Std.is(e, HttpError) ) {
			httpError = cast e;
		}
		else {
			httpError = HttpError.internalServerError( e.error );
			if( Std.is(e, Error) ) {
				httpError.pos = e.pos;
				httpError.data = e.data;
			}
		}

		var showStack = #if debug true #else false #end;

		// Clear the output, set the response code, and output.
		ctx.response.clear();
		ctx.response.status = httpError.code; 
		ctx.response.contentType = "text/html";
		ctx.response.write( renderError(httpError,currentModule,showStack) );
		ctx.completion.set( CRequestHandlersComplete );

		// rethrow error if catchErrors has been disabled
		if (!catchErrors) throw e.error;

		return Sync.success();
	}

	/**
		Render the given error message into a String (usually HTML) to be sent to the browser.

		You can override this function if you wish to supply a different error template.

		It is recommended that this method have as few dependencies as possible, for example,
		avoid using templating engines as any errors in displaying the error template will not
		be displayed correctly.

		It is also expected that this method should be synchronous.  If you require loading something asynchronously it will be easiest to create a new ErrorHandler.
	**/
	dynamic public function renderError( error:HttpError, currentModule:String, ?showStack:Bool=false ):String {
		var inner = (null!=error.data) ? '<p>${error.data}</p>':"";
		var pos = showStack ? '<p>&gt; ${error.printPos()}</p>' : '';
		
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

		var lastKnownModule = 
			if ( showStack ) '<div><h3>Last module: $currentModule</h3></div>'
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