package sys.ufront.web.context;

#if neko
	import neko.Web;
#elseif php
	import php.Web;
#end
import ufront.web.HttpError;
using StringTools;

/**
An implementation of `ufront.web.context.HttpRequest` for Neko and PHP, based on the `neko.Web` and `php.Web` API.

@author Franco Ponticelli, Jason O'Neil
**/
class HttpResponse extends ufront.web.context.HttpResponse {
	override function flush() {

		// Set HTTP status code
		if ( !_flushedStatus ) {
			_flushedStatus = true;
			Web.setReturnCode( status );
		}

		// Set Cookies
		if ( !_flushedCookies ) {
			_flushedCookies = true;
			try {
				for ( cookie in _cookies ) {
					Web.setCookie( cookie.name, cookie.value, cookie.expires, cookie.domain, cookie.path, cookie.secure, cookie.httpOnly );
				}
			}
			catch ( e:Dynamic ) {
				throw HttpError.internalServerError( 'Failed to set cookie on response', e );
			}
		}

		// Write headers
		if ( !_flushedHeaders ) {
			_flushedHeaders = true;
			for ( key in _headers.keys() ) {
				var val = _headers.get(key);
				if ( key=="Content-type" && null!=charset && (val == 'application/json' || val.startsWith('text/')) ) {
					val += "; charset=" + charset;
				}
				try {
					Web.setHeader( key, val );
				}
				catch ( e:Dynamic ) {
					throw HttpError.internalServerError( 'Invalid header: "$key: $val", or output already sent', e );
				}
			}
		}

		// Write response content
		if ( !_flushedContent ) {
			_flushedContent = true;
			Sys.print( _buff.toString() );
		}
	}
}
