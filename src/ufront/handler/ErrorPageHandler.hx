package ufront.handler;

import haxe.CallStack;
import tink.core.Error;
import ufront.app.*;
import ufront.core.Sync;
import ufront.web.context.HttpContext;
import haxe.ds.StringMap;
using DynamicsT;
using Strings;
using Types;

/**
	A module which adds an error handler to your application.

	If an error is of the type `tink.core.Error`, it will display the details of the given error.

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
	@:access( tink.core.Error )
	public function handleError( httpError:Error, ctx:HttpContext ) {

		// Pass the error to our log...
		var callStack = #if debug " "+CallStack.toString( CallStack.exceptionStack() ) #else "" #end;
		var inner = (httpError!=null && httpError.data!=null) ? ' (${httpError.data})' : "";
		ctx.ufError( 'Handling error: $httpError$inner $callStack' );

		if ( !ctx.completion.has(CRequestHandlersComplete) ) {
			var showStack = #if debug true #else false #end;

			// Clear the output, set the response code, and output.
			ctx.response.clear();
			ctx.response.status = httpError.code;
			ctx.response.contentType = "text/html";
			ctx.response.write( renderError(httpError,showStack) );
			ctx.completion.set( CRequestHandlersComplete );
		}

		// rethrow error if catchErrors has been disabled
		if (!catchErrors) throw httpError;

		return Sync.success();
	}

	/**
		Render the given error message into a String (usually HTML) to be used in `renderErrorPage()`.

		This method provides HTML for the error message content, to be inserted into your usual site layout.

		This function is dynamic, so you can override it if you wish to supply a different error template.

		It is recommended that this method have as few dependencies as possible, for example,
		avoid using templating engines as any errors in displaying the error template will not
		be displayed correctly.

		It is also expected that this method should be synchronous.  If you require loading
		something asynchronously it will be easiest to create a new ErrorHandler.

		The default template looks like:

		```
		<summary class="error-summary">
			<h1 class="error-message">${error.toString()}</h1>
		</summary>
		<details class="error-details">
			<p class="error-data">${error.data}</p>
			<p class="error-pos">${error.pos}</p>
			<p class="error-exception-stack">${exceptionStackFromError}</p>
			<p class="error-call-stack">${callStackFromError}</p>
		</details>
		```
	**/
	@:access( tink.core.TypedError )
	dynamic public function renderErrorContent( error:Error, ?showStack:Bool=false ):String {

		var inner = (null!=error.data) ? '<p class="error-data">${error.data}</p>':"";
		var pos = showStack ? '<p class="error-pos">&gt; ${error.printPos()}</p>' : '';

		var exceptionStackItems = errorStackItems( CallStack.exceptionStack() );

		var exceptionStack =
			if ( showStack && exceptionStackItems.length>0 )
				'<div class="error-exception-stack"><h3>Exception Stack:</h3>
					<pre><code>' + exceptionStackItems.join("\n") + '</pre></code>
				</div>'
			else "";

		var content = '
			<summary class="error-summary"><h1 class="error-message">$error</h1></summary>
			<details class="error-details"> $inner $pos $exceptionStack</details>
		';

		return content;
	}

	/**
		Render the given error title and error content (from `renderErrorContent`) into a page to be sent to the browser.

		This method takes two arguments: a window title, and content representing the error page.
		It then renders a full HTML page with these variables inserted.

		This function is dynamic, so you can override it if you wish to supply a different template.

		It is recommended that this method have as few dependencies as possible, for example,
		avoid using templating engines as any errors in displaying the error template will not
		be displayed correctly.

		It is also expected that this method should be synchronous.  If you require loading
		something asynchronously it will be easiest to create a new ErrorHandler.

		The default template uses a CDN-hosted Bootstrap stylesheet, a "jumbotron" component and a giant sad-face.  It took 1000 designers 1000 days to craft this work of art.
	**/
	dynamic public function renderErrorPage( title:String, content:String ):String {
		return CompileTime.interpolateFile( "ufront/web/ErrorPage.html" );
	}

	/**
		Renders the error content and places it in the error page.

		To change the look of your error messages, edit either `renderErrorContent` or `renderErrorPage`.
	**/
	public function renderError( error:Error, ?showStack:Bool ):String {
		var content = renderErrorContent( error, showStack );
		return renderErrorPage( error.toString(), content );
	}

	/**
		Turns an `Array<StackItem>` into an `Array<String>`, ready to print.
	**/
	@:access( haxe.CallStack )
	public static function errorStackItems( stack:Array<StackItem> ):Array<String> {
		var arr = [];

		#if php
			stack.pop();
			stack = stack.slice( 2 );
		#end

		var arr = CallStack.toString( stack ).split( "\n" );

		return arr;
	}
}
