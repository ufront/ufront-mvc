package ufront.api;

import minject.Injector;

/** RemotingApi is a base class for setting up your Haxe remoting API context.

It uses the `ApiMacros.buildApiContext` macro and `minject` together.

Please only define public variables in the sub class, each one representing an API class
you wish to share with your remoting context.  Eg:
	
	class MainApi extends ufront.api.RemotingApi {
		var clientAPI:app.client.ClientAPI;
		var purchaseAPI:app.purchase.PurchasingAPI;
	}

Please don't use properties.  And don't define any functions, including the constructor.
All of your API objects (that is, all the variables you specify) will be instantiated 
by some of our macro code.

For the server side, this API object can be used in the remoting controller:

	RemotingController.remotingApi = MyApi;

For the client side, another class will be generated in the same location.  So if you have

	my.app.MainApi;

The build macro will generate

	my.app.MainApiClient;

as well as the proxy classes for any APIs that you used:

	my.app.ClientApiProxy;
	my.app.PurchasingApiProxy;

Your ApiClient can be initialised with two constructor arguments: the URL of the remoting end point, and an error handler:

	new my.app.MainApiClient(url, errorHandler);
	new my.app.MainApiClient("http://api.google.com/haxeremoting/", function (e:Dynamic) trace (e));

Please note, you will need to explicitly import the API so that the build macro runs and the proxy is generated.  Otherwise you 
will get a "Class not found : my.app.MainApiClient" error.  So instead, do:

	import my.app.MainApi;
	...
	new my.app.MainApiClient(url, errorHandler);
*/

@:autoBuild(ufront.api.ApiMacros.buildApiContext())
class UFApiContext {
	public function new() {}
	var injector:Injector;
}