package ufront.api;

import haxe.remoting.AsyncConnection;
import ufront.remoting.*;

/**
UFApiClientContext is a macro-powered class that will generate callback style proxies for your `UFApiContext`.

Rather than creating each proxy class manually, like this:

```haxe
class UserAPIProxy = UFCallbackApi<UserApi>;
```

You can create proxies for the entire context all at once:

```haxe
class MainApiClient extends UFApiClientContext<MainApi> {}
```

This will:

- Create a proxy for each API in the given `UFApiContext`.
- They will be created in the same package as the original API, but with the word "Proxy" appended to the name, so `app.api.LoginApi` will create `app.api.LoginApiProxy`.
- They will be included as a variable in the client context.
- They will be initiated in the client context's constructor.

**Usage:**

```haxe
class MainApi extends UFApiContext {
  var loginApi:LoginApi;
  var purchaseApi:PurchaseApi;
}
class MainApiClient extends UFApiClientContext<MainApi>;

// Then later:
var apiClient = new MainApiClient( "/remoting-url/", errorHandler );
apiClient.loginApi.attemptLogin( username, password, function(u:User) {
  trace( 'Logged in as $user!' );
}, function (err:RemotingError<Dynamic>) {
  trace( 'Failed to log in: $err' );
});
```
**/
#if !macro
@:autoBuild( ufront.api.ApiMacros.buildClientApiContext() )
#end
class UFApiClientContext<ServerContext:UFApiContext> {

	public var cnx:AsyncConnection;

	public function new( url:String, ?errorHandler:RemotingError<Dynamic>->Void ) {
		this.cnx = HttpAsyncConnection.urlConnect( url, errorHandler );
	}
}
