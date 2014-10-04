/**
 * ...
 * @author Franco Ponticelli
 */

package neko.ufront.web.context;

import thx.error.Error;
import neko.Web;
using StringTools;

class HttpResponse extends ufront.web.context.HttpResponse {
	public function new() {
		super();
	}

	override function flush() {
		if ( _flushed )
			return;

		_flushed = true;
		
		// Set HTTP status code
		Web.setReturnCode( status );

		// Set Cookies
		try {
			for ( cookie in _cookies ) {
				Web.setCookie( cookie.name, cookie.value, cookie.expires, cookie.domain, cookie.path, cookie.secure, cookie.httpOnly );
			}
		}
		catch ( e:Dynamic ) {
			throw new Error( 'Cannot flush cookies on response: $e' );
		}

		// Write headers
		for ( key in _headers.keys() ) {
			var val = _headers.get(key);
			if ( key=="Content-type" && null!=charset && val.startsWith('text/') ) {
				val += "; charset=" + charset;
			}
			try {
				Web.setHeader( key, val );
			}
			catch ( e:Dynamic ) {
				throw new Error( "Invalid header: '{0}: {1}', or output already sent", [key,val] );
			}
		}

		// Write response content
		Sys.print( _buff.toString() );
	}
}
