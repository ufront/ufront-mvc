package ufront.test;

import ufront.web.context.*;
import ufront.web.error.HttpError;
import ufront.web.session.IHttpSessionState;
import ufront.auth.*;
import thx.error.*;
import thx.collection.*;
import haxe.PosInfos;
import massive.munit.Assert;
import ufront.web.Dispatch;
import haxe.web.Dispatch.DispatchConfig;
import ufront.application.UfrontApplication;
import ufront.web.UfrontConfiguration;
using mockatoo.Mockatoo;
using tink.core.Outcome;

/**
	A set of functions to make it easier to mock and test various ufront classes and interfaces.

	Every `mock` function uses `Mockatoo` for mocking, see the [Github Readme](https://github.com/misprintt/mockatoo/) and [Developer Guide](https://github.com/misprintt/mockatoo/wiki/Developer-Guide) for more information.

	Designed for `using ufront.test.TestUtils`.  

	It will also work best to add `using mockatoo.Mockatoo` to make the mocking functions easily accessible.
**/
class TestUtils
{
	/**
		Mock a HttpContext.

		Usage:

		```
		'/home'.mockHttpContext();
		'/home'.mockHttpContext( request, response, session, auth );
		UFMocker.mockHttpContext( '/home' );
		UFMocker.mockHttpContext( '/home', request, response, session, auth );
		```

		The URI provided is the raw `REQUEST_URI` and so can include a query string etc.
		
		The mocking is as follows:

		* The uri is used for `request.uri` if the request is being mocked.  (If the request object is given, not mocked, the supplied Uri is ignored)
		* `getRequestUri` calls the real method, so will process filters on `request.uri`
		* The request, response, session and auth return either the supplied value, or are mocked
		* `setUrlFilters` and `generateUri` call the real methods.
	**/
	public static function mockHttpContext( uri:String, ?method:String, ?request:HttpRequest, ?response:HttpResponse, ?session:IHttpSessionState, ?auth:IAuthHandler<IAuthUser> )
	{
		// Check the supplied arguments
		NullArgument.throwIfNull( uri );
		if ( request==null ) {
			request = HttpRequest.mock();
			request.uri.returns( uri );
			request.params.returns( new CascadeHash([]) );
			request.httpMethod.returns( (method!=null) ? method.toUpperCase() : "GET" );
		}
		if ( response==null ) {
			response = HttpResponse.spy();
			response.flush().stub();
		}
		if (session==null) session = IHttpSessionState.mock();
		if (auth==null) auth = IAuthHandler.mock([IAuthUser]);

		// Build the HttpContext with our mock objects
		var ctx = new HttpContext( request, response, session, auth, [] );
		return ctx;
	}
	/**
		Test a route by setting up a UfrontApplication and executing the request.

		If the dispatch is successful, the UfrontApplication is returned as a Success so that you can analyze it.

		If an error is encountered, the exception is returned as a Failure.
	**/
	public static function testRoute( context:HttpContext, dispatchCfg:DispatchConfig ):Outcome<RouteTestResult,HttpError> {
		var ufrontConf:UfrontConfiguration = {
			dispatchConfig: dispatchCfg,
			urlRewrite: true,
			basePath: "/",
			logFile: null,
			disableBrowserTrace: true
		}
		var app = new UfrontApplication( ufrontConf );
		app.errorModule.catchErrors = false;
		var result = try {
			app.execute( context );
			Success( { app: app, context: context, d:app.dispatchModule.dispatch } );
		}
		catch (e:HttpError) {
			Failure(e);
		}
		return result;
	}

	/**
		Check that the result of the `testRoute()` call was a success, and that the parameters supplied matched.

		If the result was not a success, this will fail.

		If the result was a success, but the dispatch didn't match the given controller, action or args, it will fail.

		For matching, the following rules apply:

		* Controllers are matched using their Type.getClassName()
		* Action is matched using string equality, for the same method name on the controller.
		* Args are checked for the same length first
		* If they have the same length, the arguments are checked using exact equality.
		* If `controller`, `action` or `args` is not supplied, it is not checked.

		If a failure occurs, `Assert.fail` will be called, giving an error message at the location this method was called from.

		This returns the UfrontApplication, so you can run further checks if desired.

		This can be chained together with other methods as so:

		```
		var app = "/home/".mockHttpContext().testRoute().assertSuccess(HomeController, "doDefault", []);
		```
	**/
	public static function assertSuccess( result:Outcome<RouteTestResult,HttpError>, ?controller:Class<Dynamic>, ?action:String, ?args:Array<Dynamic>, ?p:PosInfos ):RouteTestResult {
		switch ( result ) {
			case Success( successResults ): 
				var d = successResults.d;

				// If a controller type was specified, check it
				if ( controller!=null ) {
					if ( !Std.is(d.controller, controller) ) {
						var expectedName = Type.getClassName(controller);
						var actualName = Type.getClassName( Type.getClass(d.controller) );
						if ( expectedName!=actualName ) {
							Assert.fail( '[$actualName] was not equal to expected controller type [$expectedName] after dispatching', p );
						}
					}
				}

				// If an action was specified, check it
				if ( action!=null )
					if ( action!=d.action )
						Assert.fail( '[${d.action}] was not equal to expected action [$action] after dispatching', p );

				// If an args array was specified, check length and args
				if ( args!=null ) {
					var sameLength = ( d.arguments.length==args.length );

					var sameArgs = true;
					if ( sameLength ) 
						for ( i in 0...args.length ) 
							if ( args[i] != d.arguments[i] )
								sameArgs = false;
					
					if ( !sameLength || !sameArgs ) 
						Assert.fail( '[${d.arguments.length}] argument(s) [${d.arguments.join(",")}] was not equal to expected [${args.length}] argument(s) [${args.join(",")}]', p );
				}

				return successResults;

			case Failure( f ): 
				Assert.fail( 'Expected routing to succeed, but it did not (failed with error $f)', p );
				return null;
		}
	}

	/**
		Check that the result of the `testRoute()` call was a failure, and that the parameters supplied matched.

		If the result was not a failure, this will call `Assert.fail()`, giving an error at the position this method was called from.

		If the result failed as expected:
	
		* if `code` is specified, it will be checked against the code of the `ufront.web.error.HttpError`
		* if the codes do not match, `Assert.fail()` will be called.
		* the caught exception will be returned for inspection.

		This can be chained together with other methods as so:

		```
		var error = "/home/".mockHttpContext().testRoute().assertFailure(404);
		```
	**/
	public static function assertFailure( result:Outcome<RouteTestResult,HttpError>, ?code:Null<Int>, ?p:PosInfos ):Dynamic {
		switch ( result ) {
			case Success( _ ): 
				Assert.fail( 'Expected routing to fail, but it was a success', p );
				return null;
			case Failure( failure ): 
				if ( code!=null )
					if ( code!=failure.code )
						Assert.fail( 'Failure code [${failure.code}] was not equal to expected failure code [$code]', p );
				return failure;
		}
	}
}

typedef RouteTestResult = { 
	app: UfrontApplication, 
	context: HttpContext,
	d: Dispatch
}