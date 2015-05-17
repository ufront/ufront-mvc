package ufront.handler;

import haxe.CallStack;
import tink.core.Error;
import ufront.app.*;
import ufront.core.AsyncTools;
import ufront.web.context.HttpContext;
import haxe.ds.StringMap;
using thx.Strings;
using thx.Types;

/**
A `UFErrorHandler` module which displays an error page for the client when uncaught failures or errors are encountered.

It will display the error message in a simple template, and set the appropriate HTTP response code.

The template can be modified by using your own implementations of `this.renderErrorForContent()` and `this.renderErrorPage()`.
**/
class ErrorPageHandler implements UFErrorHandler
{
	/**
	A flag dictating whether errors should be caught and displayed (`true`) or simply passed through unprocessed (`false`).

	The only reason you would disable this is for debugging or unit testing.

	The default value is `true`.
	**/
	public var catchErrors:Bool = true;

	public function new() {}

	/** Process the given error and display an appropriate error page. **/
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
			ctx.response.status = (httpError.code!=null) ? httpError.code : 500;
			ctx.response.contentType = "text/html";
			ctx.response.write( renderError(httpError,showStack) );
			ctx.completion.set( CRequestHandlersComplete );
		}

		// rethrow error if catchErrors has been disabled
		if (!catchErrors) throw httpError;

		return SurpriseTools.success();
	}

	/**
	Render the given error message into a String (usually HTML) to be used in `renderErrorPage()`.

	This method provides HTML for the error message content, to be inserted into your usual site layout.

	This function is dynamic, so you can set it to a custom function if you wish to use a different error template.

	It is recommended that this method have as few dependencies as possible.
	For example, avoid using templating engines as any errors encountered in the error handler can be difficult to debug.

	It is also expected that this method should be synchronous.
	If you require loading something asynchronously it will be easiest to create a new `UFErrorHandler`.

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
			<summary class="error-summary"><h1 class="error-message">${error.message}</h1></summary>
			<details class="error-details"> $inner $pos $exceptionStack</details>
		';

		return content;
	}

	/**
	Render the given error title and error content (from `renderErrorContent`) into a page to be sent to the browser.

	This method takes two arguments: a window title, and content representing the error page.
	It then renders a full HTML page with these variables inserted.

	This function is dynamic, so you can set a custom function if you wish to supply a different template.

	It is recommended that this method have as few dependencies as possible.
	For example, avoid using templating engines as any errors that occur during the error handler can be difficult to debug.

	It is also expected that this method should be synchronous.
	If you require loading something asynchronously it will be easiest to create a new `UFErrorHandler`.

	The default template uses an inline `<style>` element for CSS, a "jumbotron" style component and a giant sad-face.
	It took 1000 designers 1000 days to craft this work of art.
	**/
	dynamic public function renderErrorPage( title:String, content:String ):String {
		return CompileTime.interpolateFile( "ufront/web/ErrorPage.html" );
	}

	/**
	Renders the error content and places it in the error page.

	To change the look of your error messages, set a custom function for `this.renderErrorContent()` and `this.renderErrorPage()`.
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
