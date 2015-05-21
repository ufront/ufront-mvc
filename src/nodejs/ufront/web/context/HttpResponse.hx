package nodejs.ufront.web.context;
import js.Node;
using StringTools;

/**
An implementation of `ufront.web.context.HttpRequest` for NodeJS, based on `js.npm.express.Response`.

@author Franco Ponticelli, Jason O'Neil
**/
class HttpResponse extends ufront.web.context.HttpResponse {

	var res:js.node.http.ServerResponse;

	public function new( res:js.node.http.ServerResponse ) {
		super();
		this.res = res;
	}

	override function flush() {
		if ( _flushed )
			return;

		_flushed = true;

		// Set HTTP status code
		res.statusCode = status;

		// Set Cookies
		try {
			var cookieHeader = [
				for ( cookie in _cookies ) '${cookie.name}=${cookie.description}'
			];
			res.setHeader( "Set-Cookie", cookieHeader );
		}
		catch ( e:Dynamic ) {
			throw 'Cannot flush cookies on response, output already sent: $e';
		}

		// Write headers
		for ( key in _headers.keys() ) {
			var val = _headers.get(key);
			if ( key=="Content-type" && null!=charset && val.startsWith('text/') ) {
				val += "; charset=" + charset;
			}
			try {
				res.setHeader(key, val);
			}
			catch ( e:Dynamic ) {
				throw 'Invalid header: "$key: $val", or output already sent';
			}
		}

		// Write response content
		res.end( _buff.toString() );
	}
}
