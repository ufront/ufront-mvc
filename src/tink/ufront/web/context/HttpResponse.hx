package tink.ufront.web.context;

import tink.http.Response;
import tink.http.Header;
import ufront.web.HttpError;
import haxe.io.Bytes;
using StringTools;

class HttpResponse extends ufront.web.context.HttpResponse {
	
	public function toTinkResponse() {
		
		var contentType = _headers.get('Content-type');
		if ( null!=charset && (contentType == 'application/json' || contentType.startsWith('text/')))
			_headers.set('Content-type', contentType + "; charset=" + charset);
			
		_headers.set('Cookie', [for ( cookie in _cookies ) '${cookie.name}=${cookie.description}'].join('; '));
		
		return new OutgoingResponse(
			new ResponseHeader(
				status, 
				'OK', 
				[for(key in _headers.keys()) new HeaderField(key, _headers.get(key))]
			), 
			#if nodejs _bytesBuffer.length > 0 ? _bytesBuffer.getBytes() : #end Bytes.ofString(_buff.toString())
		);
	}
}
