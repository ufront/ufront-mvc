package ufront.web.result;

import ufront.web.context.*;
import ufront.core.AsyncTools;
#if client
	import js.Browser.*;
#end
using tink.CoreApi;

/**
A `CallJavascriptResult` wraps another `ActionResult`, and if it is a `text/html` response, it will insert some Javascript code to be executed on the client.

It is easiest to use this through static extension:

```haxe
using ufront.web.result.CallJavascriptResult;

public function showHomepage() {
  return
  new ViewResult({ title: "Home" })
    .addInlineJsToResult( "console.log('arbitrary JS')" )
    .addJsScriptToResult( "datepicker.jquery.js" );
}
```

On the server side, a `<script>` tag will be inserted before the closing `</body>` tag.
On the client side, the scripts will be inserted into the DOM (triggering them to execute) and then removed immediately.
**/
class CallJavascriptResult<T:ActionResult> extends ActionResult implements WrappedResult<T> {

	// Static helpers

	/** Wrap an `ActionResult` in a `CallJavascriptResult`, adding some inline JS. **/
	public static function addInlineJsToResult<T:ActionResult>( originalResult:T, js:String )
		return new CallJavascriptResult( originalResult ).addInlineJs( js );

	/** Wrap an `ActionResult` in a `CallJavascriptResult`, adding a JS script. **/
	public static function addJsScriptToResult<T:ActionResult>( originalResult:T, path:String )
		return new CallJavascriptResult( originalResult ).addJsScript( path );

	// In future it may be good to add some macro helpers, which take Haxe expressions, and somehow compile them to Javascript.
	// Obviously that will be slightly more complicated than inserting JS directly, but it would be pretty fancy!
	// Especially if you could pass variables in from the server context in a type-safe way.

	// Member

	public var originalResult:T;
	/** The collection of script tags that we are adding to the response. **/
	public var scripts:Array<String>;

	public function new( originalResult:T ) {
		this.originalResult = originalResult;
		this.scripts = [];
	}

	public function addInlineJs( js:String ):CallJavascriptResult<T> {
		scripts.push( '<script type="text/javascript">$js</script>' );
		return this;
	}

	public function addJsScript( path:String ):CallJavascriptResult<T> {
		scripts.push( '<script type="text/javascript" src="$path"></script>' );
		return this;
	}

	/**
	Execute the result.

	This will execute the original result, and then add the scripts to be executed.

	If the result is not does not have a content type of `text/html`, then any scripts wil be ignored.
	If there are no scripts added, then the result will not be effected.

	The scripts will be executed using `executeScripts`, with the appropriate behaviour for both client and server side code.
	**/
	override public function executeResult( actionContext:ActionContext ):Surprise<Noise,Error> {
		return originalResult.executeResult( actionContext ) >> function(n:Noise) {
			var response = actionContext.httpContext.response;
			if( response.contentType=="text/html" && scripts.length>0 ) {
				executeScripts( response, scripts );
			}
			return Noise;
		};
	}

	/**
	This will run a series of JS snippets.

	On the server-side it will use `insertScriptsBeforeBodyTag`, and update the response content as required.

	On the client side it will create the scripts as DOM objects and execute them immediately.
	**/
	public static function executeScripts( response:HttpResponse, scripts:Array<String> ) {
		#if server
			var newContent = insertScriptsBeforeBodyTag( response.getBuffer(), scripts );
			response.clearContent();
			response.write( newContent );
		#else
			var tmpDiv = document.createDivElement();
			tmpDiv.innerHTML = scripts.join( "" );
			for ( i in 0...tmpDiv.children.length ) {
				// We have to recreate the script element to get it to execute.
				// See http://stackoverflow.com/questions/22945884/domparser-appending-script-tags-to-head-body-but-not-executing
				// TODO: DRY-ify this and HttpResponse for client-side JS.
				var node = tmpDiv.children[i];
				var script = document.createScriptElement();
				script.setAttribute( "type", 'text/javascript' );
				var src = node.getAttribute( "src" );
				if( src!=null )
					script.setAttribute("src", src);
				script.innerHTML = node.innerHTML;
				document.body.appendChild( script );
				document.body.removeChild( script );
			}
		#end
	}

	/**
	This helper function will take a HTML string, and insert the given scripts before the `</body>` tag.

	If there is no `</body>` substring, then the scripts will be inserted at the end of the content.
	**/
	public static function insertScriptsBeforeBodyTag( content:String, scripts:Array<String> ):String {
		var script = scripts.join("");
		var bodyCloseIndex = content.lastIndexOf( "</body>" );
		if ( bodyCloseIndex==-1 ) {
			// In the event that </body> is not found, let's throw our scripts right at the end.
			// This probably isn't valid HTML, but then maybe their result isn't either.
			content += script;
		}
		else {
			content = content.substring(0,bodyCloseIndex)+script+content.substr(bodyCloseIndex);
		}
		return content;
	}
}
