ufront-remoting
===============

A ufront module that makes setting up a Haxe remoting API easy. Now you can have type-safe, code-completed access to your server API from the client.

### The concept is this:

 * You set up API classes.  These are just regular classes that
   have a bunch of public methods used to do API calls.

 * You set up an API context class, mine is called "app/Api.hx".  

 * Your Api context class has member variables for each API you
   want to access:

        public var userAPI:users.UserAPI;

 * A build macro does a bunch of work to create the Proxy classes.

 * You can access your Api classes on the server:

        var appApi = new app.Api();
        var user32 = appApi.userAPI.getUser(32);
       
 * You can access your Api classes on the client, using the macro-
   powered Client class (in the same location as your API class, but
   with "Client" on the end of the name):

        var appApiClient = new app.ApiClient();
        appApiClient = appApi.userAPI.getUser(32, function (user32) {
          trace ('User 32 has the username ${user32.username}');
        });
       
### How to get it to work:

1. Make some API classes that do app specific tasks.  Each one should
implement "ufront.api.UFApi" so the build macro takes
effect.

        class UserAPI implements ufront.api.UFApi 
        {
          public function getUser(id:Int):User 
          {
            return User.manager.get(id);
          }
        }

2. Make your API context class.  Each one should implement 
   "ufront.api.UFApiContext" so the build macros take
   effect.

        class API implements ufront.api.UFApiContext
        {
          public var userAPI:UserAPI;
        }

3. On your server, you have to add the RemotingController to your app,
   and let the remoting controller know to use your API class.
  
        // Import the RemotingController
        import ufront.controller.admin.RemotingController;
        
        // Tell it which API to use
        RemotingController.remotingApi = new app.Api();

        // then set up the route so we have a remoting endpoint to target
        routes.addRoute("/remoting/", { controller : "RemotingController", action : "run" } )

4. On your server, you can also access this in any controller etc:
  
        var api = new app.Api();
        var user = api.userAPI.getUser(32);
        trace ('User 32 has the username ${user.username}');

5. On your client, you can now use Haxe remoting to interact with the server:
  
        // Import the API class explicitly, so the build macros fire
        import app.Api;
        
        // Set up the remoting API client.  Just add "Client" to the end of your API class name.
        // Use the same URL that you specified in the server.
        var apiClient = new app.ApiClient("/remoting/", function (e) trace ("ERROR: " + e));

        // Then you can make all the same calls as on the server, but they're async:
        apiClient.userAPI.getUser(32, function (user) {
          trace ('User 32 has the username ${user.username}');
        });

### Other notes

We are using `HttpAsyncConnectionWithTraces` instead of the usual `HttpAsyncConnection`.  This is a basic
extension which, when combined with our `RemotingController`, means any traces you do inside your API will
be executed as traces on the client - so they will show up in your browser console, which is helpful for 
debugging purposes.
