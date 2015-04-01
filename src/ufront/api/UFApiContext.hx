package ufront.api;

import minject.Injector;

/**
	`UFApiContext` is a base class for setting up your Haxe remoting API context.

	If set in your `UfrontConfiguration.remotingApi`, your UFApiContext class will share all the APIs over both Haxe style remoting (using proxies with callbacks) and Ufront style remoting (using `UFApi` and `UFAsyncApi`).

	An example API context might look like this:

	```haxe
	class MainApi extends ufront.api.UFApiContext {
		var clientAPI:app.client.ClientAPI;
		var purchaseAPI:app.purchase.PurchasingAPI;
	}
	```

	This will make both ClientAPI and PurchasingAPI available to remoting calls.

	### Ufront Style Remoting.

	The `UFApi` and `UFAsyncApi` classes have build macros that allow them to work seamlessly on the client or the server.

	The `UFApi` will make synchronous remoting calls using an injected `haxe.remoting.Connection`, which will usually be a `ufront.remoting.HttpConnection`.
	Please note on Javascript making a synchronous HTTP call may result in the browser UI locking while the request completes, so it is generally recommended you use `UFAsyncApi`.
	Another note: APIs that execute asynchronously on the server, and return a Future or a Surprise, may not serialize correctly during synchronous remoting.  It is advised to use `UFAsyncApi` for these use cases.

	The `UFAsyncApi` will make asynchronous remoting calls using an injected `haxe.remoting.AsyncConnection`, which will usually be a `ufront.remoting.HttpAsyncConnection`.

	If we had the following `ClientAPI` class included in our UFApiContext:

	```haxe
	class ClientAPI extends UFApi {
		public function getClient( id:Int ):Client { ... }
	}
	```

	The Async API would be created with:

	```haxe
	class AsyncClientAPI extends UFAsyncApi<ClientAPI> {}
	```

	This would have transform the `getClient` method to return a `Surprise`:

	```haxe
	class AsyncClientAPI {
		public function getClient( id:Int ):Surprise<Client,RemotingError<Dynamic>>;
	}
	```

	You can use `UFAsyncApi` directly on the server as well, so that your client code and server code can interact with the API in the same way.

	### Haxe Style Remoting

	Haxe style remoting creates a proxy class on the client that uses asynchronous callbacks for each call.
	This style of remoting may feel more natural if you are not using ufront on your client.

	The build macro for `UFApiContext` will also create a "Client" version of the class when `-D client` is used during compilation:

	```haxe
	class MainApiClient {
		var clientAPI:app.client.ClientAPIProxy;
		var purchaseAPI:app.purchase.PurchasingApiProxy;
	}
	```

	Furthermore, it will create a "Proxy" class for each API.
	If we had the following `ClientAPI` class included in our UFApiContext:

	```haxe
	class ClientAPI extends UFApi {
		public function getClient( id:Int ):Client { ... }
	}
	```

	Then a proxy class would be generated:

	```haxe
	class ClientAPIProxy {
		public function getClient( id:Int, callback:Client->Void ):Void
	}
	```

	You could access this on your client application using:

	```haxe
	var api = new MainApiClient( url, errorHandler );
	api.clientAPI.getClient( 1, function(client) {
		trace( 'Found client 1: '+client.name );
	});
	```

	### Other Notes

	- Please only define public variables in the sub classes, each one representing a `UFApi` class.
	- Please don't create any methods, properties, private variables or a constructor. They will be removed during the macros.
	- The API variables do not need to be initialised - dependency injection will be used for that.
	- You can construct an API Context on the client using `new MyApiClient( url, errorHandler )`.
	- If you never import your API Context on the client, the build macro will not run and the Haxe style remoting proxy classes will not be generated.
	  The `UFApi` and `UFAsyncApi` classes are both generated with the correct remoting calls when you import them on the client, regardless of if the `UFApiContext` is imported.
**/

@:autoBuild(ufront.api.ApiMacros.buildApiContext())
class UFApiContext {
	var injector:Injector;

	public function new() {}

	public static function getApisInContext( context:Class<UFApiContext> ):Array<Class<UFApi>> {
		var apis = [];
		var meta = haxe.rtti.Meta.getType( context );
		if (meta.apiList!=null) for (apiName in meta.apiList) {
			var api:Class<UFApi> = cast Type.resolveClass(apiName);
			if (api!=null)
				apis.push(api);
		}
		return apis;
	}
}
