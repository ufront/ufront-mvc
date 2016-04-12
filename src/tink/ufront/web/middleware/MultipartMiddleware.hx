package tink.ufront.web.middleware;

import haxe.io.BytesOutput;
import ufront.app.UFMiddleware;
import ufront.core.Uuid;
import ufront.web.context.HttpContext;
import ufront.web.upload.TmpFileUpload;
import tink.http.Multipart;
import tink.io.Buffer;
import tink.io.Sink;
import tink.io.Worker;

using DateTools;
using haxe.io.Path;
using ufront.core.AsyncTools;
using tink.CoreApi;

typedef MultipartOptions = {
	?subDir:String,
}

class MultipartMiddleware implements UFRequestMiddleware {
	
	var subDir:String = "uf-upload-tmp";
	
	public function new( ?options:MultipartOptions ) {
		if(options == null) options = {};
		if(options.subDir != null) subDir = options.subDir;
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
								
								if(ext.exists('filename'))
								{
									var filename = ext['filename'];
									var dateStr = Date.now().format( "%Y%m%d-%H%M" );
									var dir = ctx.contentDirectory + subDir.addTrailingSlash();
									var tmpFilePath = dir + dateStr + "-" + Uuid.create() + ".tmp";
									var out = new MultipartSink(tmpFilePath);
									var future = chunk.body.pipeTo(out);
									future.handle(function(o) switch o {
										case AllWritten:
											var tmpFile = new TmpFileUpload( tmpFilePath, name, filename, out.size );
											ctx.request.files.add( filename, tmpFile );
										default: // TODO: handle error?
									});
									futures.push(future);
								}
								else
								{
									var buf = new BytesOutput();
									var future = chunk.body.pipeTo(Sink.ofOutput('Multipart form-data "$name"', buf, Worker.EAGER));
									future.handle(function(o) switch o {
										case AllWritten:
											var bytes = buf.getBytes();
											postString.push(name + (bytes.length == 0 ? '' : '=' + bytes.toString()));
										default: // TODO: handle error?
									});
									futures.push(future);
								}
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


private class MultipartSink extends #if nodejs tink.io.nodejs.NodejsSink #else StdSink #end
{
	public var size(default, null):Int = 0;
	
	public function new(path:String) {
		#if nodejs
			super(js.node.Fs.createWriteStream(path), 'Multipart file: $path');
		#else
			super('Multipart file: $path', sys.io.File.write(path, true), Worker.EAGER);
		#end
	}
	
	override public function write(from:Buffer) {
		size += from.size;
		return super.write(from);
	}
}
