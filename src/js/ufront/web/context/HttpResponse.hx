package js.ufront.web.context;

import js.Browser.*;
using Detox;
using StringTools;

/**
	An implementation of HttpResponse for Client Side JS.

	It sets cookies, ignores headers, and, if the response type is text/html, attempts to replace the elements on the page with the new content.

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
			throw 'Cannot set cookies on response: $e';
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
			var newDoc = document.implementation.createHTMLDocument("MY TITLE");
			newDoc.documentElement.innerHTML = _buff.toString();

			// TODO: deleting all old elements and replacing them is fairly brutal.
			// A DOM diffing algorithm could be better.
			// Apparently react does diffs level by level in the DOM heirarchy, which would be less complicated to resolve.
			// On the other hand, we could leave it up to the ActionResult classes to be more clever with templating etc, and this is just a crude fallback.
			newDoc.find( "head" ).children(false).appendTo( document.head.empty() );
			newDoc.find( "body" ).children(false).appendTo( document.body.empty() );
		}
		else throw 'Cannot use ufront-client-mvc to render content type "$contentType". Only "text/html" is supported.';
	}
}
