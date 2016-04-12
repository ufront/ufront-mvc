package tink.ufront.web.middleware;

import haxe.io.BytesOutput;
import ufront.app.UFMiddleware;
import ufront.web.context.HttpContext;
import tink.http.Multipart;
import tink.io.Sink;
import tink.io.Worker;

using ufront.core.AsyncTools;
using tink.CoreApi;

class MultipartMiddleware implements UFRequestMiddleware {
	
	public function new() {
		
	}
	
	public function requestIn( ctx:HttpContext ):Surprise<Noise,Error> {
		
		var request = cast(ctx.request, tink.ufront.web.context.HttpRequest);
		
		return switch Multipart.check(request.request)
		{
			case Some(stream):
				var headers = [];
				var postString = [];
				var futures = [];
				
				stream.forEach(function(chunk) 
				{
					return switch chunk.header.byName('content-disposition') {
						case Success(_.getExtension() => ext): 
							if(ext.exists('name'))
							{
								var name = ext['name'];
								var buf = new BytesOutput();
								var future = chunk.body.pipeTo(Sink.ofOutput('Multipart form-data "$name"', buf, Worker.EAGER));
								future.handle(function(_) {
									var bytes = buf.getBytes();
									postString.push(name + (bytes.length == 0 ? '' : '=' + bytes.toString()));
								});
								futures.push(future);
							}
							true;
						default:
							untyped console.log('default');
							false;
					}
				}) >>
					function(_) return Future.ofMany(futures) >> 
						function(_) {
							js.Node.console.log('poststring', postString.join("&"));
							request.setPostString(postString.join("&"));
							return SurpriseTools.success();
						}
			case None:
				SurpriseTools.success();
		}
	}
}