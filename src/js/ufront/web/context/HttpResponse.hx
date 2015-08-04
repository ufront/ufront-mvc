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
		var location = window.location.pathname+window.location.search;
		window.console.log( '[$status] ${location}' );

		if ( _flushed )
			return;

		_flushed = true;

		// Set Cookies
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

		// Write headers
		for ( key in _headers.keys() ) {
			var val = _headers.get(key);
			if ( key=="Content-type" && null!=charset && val.startsWith('text/') ) {
				val += "; charset=" + charset;
			}
			// TODO: decide if any headers are worth reading, and implementing as specific behaviours.
			// For example, we could use <meta http-equiv="" /> tags.
			// Redirect headers also seem like a good culprit to pick up here.
		}

		// Write response content
		if ( contentType=="text/html" ) {
			// This method only has IE9 support.  We might need something better in future.
			var newDoc = document.implementation.createHTMLDocument("");
			newDoc.documentElement.innerHTML = _buff.toString();

			// TODO: deleting all old elements and replacing them is fairly brutal.
			// A DOM diffing algorithm could be better.
			// Apparently react does diffs level by level in the DOM heirarchy, which would be less complicated to resolve.
			// On the other hand, we could leave it up to the ActionResult classes to be more clever with templating etc, and this is just a crude fallback.
			function emptyElement( parent:Element ) {
				while ( parent.firstChild!=null )
					parent.removeChild( parent.firstChild );
			}
			function moveChildNodes( fromParent:Element, toParent:Element ) {
				while ( fromParent.firstChild!=null )
					toParent.appendChild( fromParent.firstChild );
			}
			document.title = newDoc.title;
			emptyElement( document.body );
			moveChildNodes( newDoc.body, document.body );
		}
		else if ( this.isRedirect() ) {
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
		else {
			// TODO: Figure out if there is a sensible way to fall back to the server.
			// Perhaps setting document.location to trigger a server load?
			js.Browser.console.log( 'Cannot use ufront-client-mvc to render content type "$contentType". Redirecting to server for rendering this content.' );
			document.location.reload();
		}
	}
}
