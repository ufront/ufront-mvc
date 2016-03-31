package tink.ufront.web.middleware;

import ufront.app.UFMiddleware;
import ufront.web.context.HttpContext;
import tink.http.Multipart;

using ufront.core.AsyncTools;
using tink.CoreApi;

class MultipartMiddleware implements UFRequestMiddleware {
	
	public function new() {
		
	}
	
	public function requestIn( ctx:HttpContext ):Surprise<Noise,Error> {
		
		var request = cast(ctx.request, tink.ufront.web.context.HttpRequest).request;
		return switch Multipart.check(request)
		{
			case Some(stream):
				var headers = [];
				stream.forEach(function(chunk) {
					// headers = headers.concat(chunk.header.fields);
					return true;
				}) >>
					function(_)
					{
						// headers.map(function(header) return header.name + (header.value == null ? '' : '=' + header.value)).join("&");
						return Noise;
					}
			case None:
				SurpriseTools.success();
		}
	}
}