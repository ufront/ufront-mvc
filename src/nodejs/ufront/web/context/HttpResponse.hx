package nodejs.ufront.web.context;

import js.Node;
import ufront.web.HttpError;
using StringTools;

/**
An implementation of `ufront.web.context.HttpRequest` for NodeJS, based on `express.ServerResponse`.

@author Franco Ponticelli, Jason O'Neil
**/
class HttpResponse extends ufront.web.context.HttpResponse {

	var res:express.Response;

	public function new( res:express.Response ) {
		super();
		this.res = res;
	}

	override function flush() {

		// Set HTTP status code
		if ( !_flushedStatus ) {
			_flushedStatus = true;
			res.statusCode = status;
		}

		// Set Cookies
		if ( !_flushedCookies ) {
			_flushedCookies = true;
			try {
				var cookieHeader = [
					for ( cookie in _cookies ) '${cookie.name}=${cookie.description}'
				];
				res.setHeader( "Set-Cookie", cookieHeader );
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
					res.setHeader(key, val);
				}
				catch ( e:Dynamic ) {
					throw HttpError.internalServerError( 'Invalid header: "$key: $val", or output already sent', e );
				}
			}
		}

		// Write response content
		if ( !_flushedContent ) {
			_flushedContent = true;
			res.end( _buff.toString() );
		}
	}
}
