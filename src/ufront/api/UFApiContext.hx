package ufront.api;

import minject.Injector;

/**
UFApiContext is a base class for setting up your Haxe remoting API context.

If set in your `UfrontConfiguration.remotingApi`, your UFApiContext class will share all the APIs over both Haxe style remoting (using proxies with callbacks) and Ufront style remoting (using `UFApi` and `UFAsyncApi`).

An example API context might look like this:

```haxe
class MainApi extends ufront.api.UFApiContext {
  var userAPI:app.client.UserAPI;
  var purchaseAPI:app.purchase.PurchasingAPI;
}
```

This will make both UserAPI and PurchasingAPI available to remoting calls.

#### Ufront and Haxe Remoting:

Ufront style remoting will use `UFAsyncApi<YourApi>` classes, which return a `Surprise` (A `Future<Outcome>`) rather than a synchronous result.
This works well with dependency injection and ufront controllers, and is probably the best choice if you are using Ufront on your client side app.
See `UFAsyncApi` for more details.

Haxe style remoting will use `UFCallbackApi<YourApi>` classes, which use asynchronous callbacks rather than returning a result.
This style may feel familiar to Javascript developers, and is almost certainly the best option if your client code is not written in Ufront (or even Haxe).
See `UFCallbackApi` and `UFApiClientContext` for more details.

#### Other Notes:

- Every API variable will be made public and available for remoting.
- Functions, properties and static variables will be ignored.
- You don't have to worry about initialising your API variables - dependency injection will be used.
**/
@:autoBuild(ufront.api.ApiMacros.buildApiContext())
class UFApiContext {
	var injector:Injector;

	/**
	It is recommended to initialise your UFApiContext using dependency injection.
	**/
	public function new() {}

	/**
	Return an Array of APIs that are available in this context.
	**/
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
