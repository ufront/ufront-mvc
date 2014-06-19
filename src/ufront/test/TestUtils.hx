package ufront.test;

import ufront.web.context.*;
import ufront.web.session.UFHttpSessionState;
import ufront.auth.*;
import thx.error.*;
import thx.collection.*;
import haxe.PosInfos;
import utest.Assert;
import ufront.web.Controller;
import ufront.app.UfrontApplication;
import ufront.web.UfrontConfiguration;
import ufront.core.MultiValueMap;
import minject.Injector;
using mockatoo.Mockatoo;
using tink.CoreApi;

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
	public static function mockHttpContext( uri:String, ?method:String, ?params:MultiValueMap<String>, ?injector:Injector, ?request:HttpRequest, ?response:HttpResponse, ?session:UFHttpSessionState, ?auth:UFAuthHandler<UFAuthUser> )
	{
		// Check the supplied arguments
		NullArgument.throwIfNull( uri );
		if ( injector==null ) {
			injector = new Injector();
		}
		if ( request==null ) {
			request = HttpRequest.mock();
			request.uri.returns( uri );
			request.scriptDirectory.returns( "." );
			request.params.returns( (params!=null) ? params : new MultiValueMap() );
			request.httpMethod.returns( (method!=null) ? method.toUpperCase() : "GET" );
			request.clientHeaders.returns( new MultiValueMap() );
		}
		if ( response==null ) {
			response = HttpResponse.spy();
			response.flush().stub();
		}
		if ( session==null ) {
			session = UFHttpSessionState.mock();
        }
		if (auth==null) auth = UFAuthHandler.mock([UFAuthUser]);

		// Build the HttpContext with our mock objects
		var ctx = new HttpContext( injector, request, response, session, auth, [] );
		ctx.actionContext = new ActionContext( ctx );
		return ctx;
	}
	/**
		Test a route by setting up a UfrontApplication and executing the request.

		If the dispatch is successful, the UfrontApplication is returned as a Success so that you can analyze it.

		If an error is encountered, the exception is returned as a Failure.
	**/
	public static function testRoute( context:HttpContext, controller:Class<IndexController> ):RouteTestOutcome {
		var ufrontConf:UfrontConfiguration = {
			indexController: controller,
			urlRewrite: true,
			basePath: "/",
			logFile: null,
			disableBrowserTrace: true,
			errorHandlers: []
		}
		var app = new UfrontApplication( ufrontConf );
        return app.execute( context ).map( function(outcome) return switch outcome {
            case Success(_): return Success( { app: app, context: context } );
            case Failure(httpError): return Failure( httpError );
        });
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
	public static function assertSuccess( result:RouteTestOutcome, ?controller:Class<Dynamic>, ?action:String, ?args:Array<Dynamic>, ?p:PosInfos ):Future<RouteTestResult> {
		var doneCallback = Assert.createAsync( function() {} );
		var future = result.map(function (outcome) switch outcome {
			case Success( successResult ):
				var ctx = successResult.context.actionContext;
				Assert.notNull( ctx );

				// If a controller type was specified, check it
				if ( controller!=null ) {
					if ( !Std.is(ctx.controller, controller) ) {
						var expectedName = Type.getClassName(controller);
						var actualName = Type.getClassName( Type.getClass(ctx.controller) );
						if ( expectedName!=actualName ) {
							Assert.fail( '[$actualName] was not equal to expected controller type [$expectedName] after dispatching', p );
						}
					}
				}

				// If an action was specified, check it matches.
				if ( action!=null )
					if ( action!=ctx.action )
						Assert.fail( '[${ctx.action}] was not equal to expected action [$action] after dispatching', p );

				// If an args array was specified, check length and args match.
				if ( args!=null ) {
					Assert.equals( args.length, ctx.args.length, 'Expected ${args.length} arguments for MVC action, but only had ${ctx.args.length}' );
					for ( i in 0...args.length ) {
						var expected = args[i];
						var actual = ctx.args[i];
						Assert.same( expected, actual, true, 'Expected MVC action argument ${i+1} to be $expected, but was $actual' );
					}
				}
				doneCallback();
				return successResult;

			case Failure( f ): 
				var exceptionStack = haxe.CallStack.toString(haxe.CallStack.exceptionStack());
				Assert.fail( 'Expected routing to succeed, but it did not (failed with error $f, ${f.data} ${exceptionStack})', p );
				doneCallback();
				return null;
		});
		future.handle( function(_) {} );
		return future;
	}

	/**
		Check that the result of the `testRoute()` call was a failure, and that the parameters supplied matched.

		If the result was not a failure, this will call `Assert.fail()`, giving an error at the position this method was called from.

		If the result failed as expected:
	
		* if `code` is specified, it will be checked against the code of the `tink.core.Error`
		* if the codes do not match, `Assert.fail()` will be called.
		* the caught exception will be returned for inspection.

		This can be chained together with other methods as so:

		```
		var error = "/home/".mockHttpContext().testRoute().assertFailure(404);
		```
	**/
	public static function assertFailure( result:RouteTestOutcome, ?code:Null<Int>, ?p:PosInfos ):Future<Error> {
		var doneCallback = Assert.createAsync(function() {});
		var future = result.map(function processOutcome(outcome) {
			switch outcome {
				case Success( _ ): 
					Assert.fail( 'Expected routing to fail, but it was a success', p );
					doneCallback();
					return null;
				case Failure( failure ): 
					if ( code!=null )
						if ( code!=failure.code )
							Assert.fail( 'Failure code [${failure.code}] was not equal to expected failure code [$code]', p );
					Assert.isTrue(true);
					doneCallback();
				return failure;
			}
		});
		future.handle( function(_) {} );
		return future;
	}
}

typedef RouteTestResult = { 
	app: UfrontApplication, 
	context: HttpContext
}
typedef RouteTestOutcome = Surprise<RouteTestResult, Error>;
