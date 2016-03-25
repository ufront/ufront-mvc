package ufront.app;

import tink.http.Application;
import tink.http.Container;
import tink.http.Request;
import tink.http.Response;

using tink.CoreApi;

class Server {
	
	public function new(config:ServerConfiguration) {
		var container =
			#if  (neko || php)
				CgiContainer.instance;
			#elseif nodejs
				new NodeContainer(config.port);
			#else
				#error
			#end
		
		container.run(config.app);
	}
}

typedef ServerConfiguration = {
	#if nodejs port:Int, #end
	app:Application,
}