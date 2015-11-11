package js.ufront.web.context;

import js.Browser.*;
import js.html.*;
import ufront.web.HttpError;
using StringTools;

/**
An implementation of `ufront.web.context.HttpResponse` for client-side JS.

This fairly crudely tries to recreate a server side style response while staying on the same page in JS:

- Cookies are set using `Document.cookie`.
- HTTP Headers are mostly ignore.
- Redirects on the current domain are handled by calling `PushState.push()`.
- Redirects to a different domain are handled by setting `Document.location.href`.
- If the response content-type is `text/html`, then we attempt to parse the response, and:
  - Replace the current head tag's innerHTML with the new header's innerHTML.
  - Replace the current body tag's innerHTML with the new body's innerHTML.

Limitations:

- Currently the client does not defer to the server if it cannot handle a request. We should support this.
- Relative redirects (on the same domain) are always handled using PushState, which may not be desirable.
- Our method for replacing DOM nodes is incredibly crude, and can result in a FOUC (Flash of Unstyled Content).
  A DOM diffing algorithm would be preferable.

Given these limitations, it may be better to have a custom `ActionResult`, which on the client has more intelligent logic for replacing the current view smoothly.
Such an action result could call `HttpContext.completion.set(CFlushComplete)` to prevent this crude `HttpResponse.flush()` from taking place.

@author Jason O'Neil
**/
class HttpResponse extends ufront.web.context.HttpResponse {
	public function new() {
		super();
	}

	override function flush() {

		// Log the request to the console.
		if ( !_flushedStatus ) {
			_flushedStatus = true;
			var location = window.location.pathname+window.location.search;
			window.console.log( '[$status] ${location}' );
		}

		// Set Cookies
		if ( !_flushedCookies ) {
			_flushedCookies = true;
			try {
				for ( cookie in _cookies ) {
					// So, document.cookie behaves like a String, but actually will process the description string and add a cookie.
					// See http://www.quirksmode.org/js/cookies.html
					document.cookie = cookie.description;
				}
			}
			catch ( e:Dynamic ) {
				throw HttpError.internalServerError( 'Cannot set cookies on response', e );
			}
		}

		// Write headers
		if ( !_flushedHeaders ) {
			_flushedHeaders = true;

			// Process redirect headers.
			if ( this.isRedirect() ) {
				_flushedContent = true;
				#if pushstate
					if ( this.redirectLocation.startsWith("/") || this.redirectLocation.startsWith(window.location.origin) ) {
						// The URL is on this site, attempt a pushstate.
						// TODO: Not every request here should be on the client, for example, if the redirect points to a download.
						// We should add a mechanism for the client to defer to the server when it cannot display the appropriate content type.
						pushstate.PushState.replace( this.redirectLocation );
					}
					else {
						document.location.href = this.redirectLocation;
					}
				#else
					document.location.href = this.redirectLocation;
				#end
			}

			// TODO: consider if we support other headers, possibly using <meta http-equiv="" /> tags.
		}

		// Write response content
		if ( !_flushedContent ) {
			_flushedContent = true;
			if ( contentType=="text/html" ) {
				// This method only has IE9 support.  We might need something with more platform support.
				var newDoc = document.implementation.createHTMLDocument("");
				newDoc.documentElement.innerHTML = _buff.toString();

				document.title = newDoc.title;
				// We are fairly brutal - replacing all elements in the old head and body with elements in the new head and body.
				// Use a custom ActionResult and call `response.preventFlushContent()` for a more fine-grained approach.
				replaceNode( document.head, newDoc.head );
				replaceNode( document.body, newDoc.body );
				window.scrollTo( 0, 0 );

				// Re-run <script> with "uf-reload" attribute
				// e.g. <script uf-reload>console.log("test");</script>
				var scriptTags = document.getElementsByTagName('script');
				for ( i in 0...scriptTags.length ) {
					var node = scriptTags.item( i );
					var reload = node.getAttribute( "uf-reload" );
					if ( reload!=null && reload!="false" ) {
						var script = document.createElement( 'script' );
						script.setAttribute( "type", 'text/javascript' );
						var src = node.getAttribute( "src" );
						if( src!=null )
							script.setAttribute("src", src);
						script.innerHTML = node.innerHTML;
						// Append (which will cause it to execute) and then remove immediately.
						document.body.appendChild( script );
						document.body.removeChild( document.body.lastChild );
					}
				}
			}
			else {
				js.Browser.console.log( 'Cannot use ufront-client-mvc to render content type "$contentType". Redirecting to server for rendering this content.' );
				document.location.reload();
			}
		}
	}

	/**
	This is a utility function for replacing dom nodes in one parent with children from another parent.

	If `sourceParent` is null, the target parent will be emptied.
	If `targetParent` is null, the result is unspecified.

	@deprecated Please use `replaceNode` instead, as this will also update the element type and attributes.
	**/
	// TODO: Add @:deprecated() metadata.
	public static function replaceChildren( sourceParent:Null<Node>, targetParent:Node ):Void {
		while ( targetParent.firstChild!=null )
			targetParent.removeChild( targetParent.firstChild );
		if ( sourceParent!=null )
			while ( sourceParent.firstChild!=null )
				targetParent.appendChild( sourceParent.firstChild );
	}

	/**
	This is a utility function for replacing one DOM node with another.

	If `newNode` is null, then `oldNode` will be removed from the DOM with no replacement taking it's place.
	If `oldNode` is null, or is not attached to the DOM, the result is unspecified.
	**/
	public static function replaceNode( oldNode:Null<Node>, newNode:Null<Node> ) {
		if ( newNode!=null )
			oldNode.parentNode.insertBefore( newNode, oldNode );
		oldNode.parentNode.removeChild( oldNode );
	}
}
