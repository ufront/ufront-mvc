/**
 * ...
 * @author Franco Ponticelli
 */

package nodejs.ufront.web.context;
import thx.error.NotImplemented; 
import js.Node;
import thx.error.Error; 
using StringTools;

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
				for ( cookie in _cookies ) '${cookie.name}=${cookie.description()}'
			];
			res.setHeader( "Set-Cookie", cookieHeader );
		}
		catch ( e:Dynamic ) {
			throw new Error( "Cannot flush cookies on response, output already sent" );
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
				throw new Error( "Invalid header: '{0}: {1}', or output already sent", [key,val] );
			}
		}

		// Write response content
		res.write( _buff.toString() );
	}
}