package ufront.test;

import ufront.web.context.HttpResponse;

/**
A mock HttpResponse class that allows you to emulate HTTP repsonses.

This is the same as any other HttpResponse class, except that the flush method will simply set the value of `this.flushedContent`.
**/
class MockHttpResponse extends HttpResponse {

	/**
	The content that has been written to the response.
	This will be `null` until `flush()` has been called.
	**/
	public var flushedContent:String;

	public function new() {
		super();
		this.flushedContent = null;
	}

	override function flush() {

		// Set HTTP status code
		if ( !_flushedStatus ) {
			_flushedStatus = true;
		}

		// Set Cookies
		if ( !_flushedCookies ) {
			_flushedCookies = true;
		}

		// Write headers
		if ( !_flushedHeaders ) {
			_flushedHeaders = true;
		}

		// Write response content
		if ( !_flushedContent ) {
			_flushedContent = true;
			this.flushedContent = _buff.toString();
		}
	}
}
