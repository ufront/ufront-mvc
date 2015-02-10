package ufront.test;

import ufront.web.context.*;
import ufront.web.session.UFHttpSession;
import ufront.auth.*;
import thx.core.error.*;
import thx.collection.*;
import haxe.PosInfos;
import ufront.web.Controller;
import ufront.app.UfrontApplication;
import ufront.web.UfrontConfiguration;
import ufront.web.result.ActionResult;
import ufront.core.MultiValueMap;
import minject.Injector;
#if utest import utest.Assert; #end
#if mockatoo using mockatoo.Mockatoo; #end
using tink.CoreApi;

/**
	A set of functions to make it easier to mock and test various ufront classes and interfaces.

	Every `mock` function uses `Mockatoo` for mocking, see the [Github Readme](https://github.com/misprintt/mockatoo/) and [Developer Guide](https://github.com/misprintt/mockatoo/wiki/Developer-Guide) for more information.

	Designed for `using ufront.test.TestUtils`.

	It will also work best to add `using mockatoo.Mockatoo` to make the mocking functions easily accessible.

	Please note both `utest` and `mockatoo` libraries must be included for these methods to be available.
**/
class TestUtils
{
	#if (utest && mockatoo)
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
			* The request, response, session and auth return either the supplied value, or are mocked.
			* Session uses `ufront.web.session.VoidSession` as a default mock object, auth uses `ufront.auth.YesBossAuthHandler` by default.
			* `setUrlFilters` and `generateUri` call the real methods.
		**/
		public static function mockHttpContext( uri:String, ?method:String, ?params:MultiValueMap<String>, ?injector:Injector, ?request:HttpRequest, ?response:HttpResponse, ?session:UFHttpSession, ?auth:UFAuthHandler<UFAuthUser> ):HttpContext
		{
			// Check the supplied arguments
			NullArgument.throwIfNull( uri );
			if ( injector==null ) {
				injector = new Injector();
			}
			if ( request==null ) {
				request = HttpRequest.mock();
				request.uri.returns( uri );
				request.scriptDirectory.returns( "./" );
				request.params.returns( (params!=null) ? params : new MultiValueMap() );
				request.httpMethod.returns( (method!=null) ? method.toUpperCase() : "GET" );
				request.clientHeaders.returns( new MultiValueMap() );
			}
			if ( response==null ) {
				response = HttpResponse.spy();
				response.flush().stub();
			}
			if ( session==null ) {
				session = new ufront.web.session.VoidSession();
			}
			if (auth==null) {
				auth = new ufront.auth.YesBossAuthHandler();
			}

			// Build the HttpContext with our mock objects
			return new HttpContext( request, response, injector, session, auth, [] );
		}
		/**
			Test a route in a UfrontApplication or a Controller by executing the request.

			If the app is supplied, the request will be executed with the given context.
			If only the controller is supplied, a UfrontApplication will be instantiated.
			It is recommended that your app have `disableBrowserTrace: true` and `errorHandlers: []` in it's configuration.

			If the route is executed successfully, the UfrontApplication and HttpContext are returned as a Success so that you can analyze it.
			If an error is encountered, the exception is returned as a Failure.
		**/
		public static function testRoute( context:HttpContext, ?app:UfrontApplication, ?controller:Class<Controller> ):RouteTestOutcome {
			if ( app==null ) {
				var ufrontConf:UfrontConfiguration = {
					indexController: controller,
					disableBrowserTrace: true,
					errorHandlers: [],
				}
				app = new UfrontApplication( ufrontConf );
			}
			context.injector.parentInjector = app.injector;
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
		public static function assertFailure( result:RouteTestOutcome, ?code:Null<Int>, ?message:Null<String>, ?innerData:Null<Dynamic>, ?p:PosInfos ):Future<Error> {
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
						if ( message!=null )
							if ( message!=failure.message )
								Assert.fail( 'Failure message [${failure.message}] was not equal to expected failure message [$message]', p );
						if ( innerData!=null )
							Assert.same( innerData, failure.data, true, 'Failure data [${failure.data}] was not equal to expected failure data [$innerData]', p );
						Assert.isTrue(true);
						doneCallback();
					return failure;
				}
			});
			future.handle( function(_) {} );
			return future;
		}

		public static function responseShouldBe( resultFuture:Future<RouteTestResult>, expectedResponse:String, ?p:PosInfos ):Future<RouteTestResult> {
			resultFuture.handle( function(result) {
				Assert.equals( expectedResponse, result.context.response.getBuffer() );
			});
			return resultFuture;
		}

		public static function checkResult<T:ActionResult>( resultFuture:Future<RouteTestResult>, expectedResultType:Class<T>, ?check:T->Void, ?p:PosInfos ):Future<RouteTestResult> {
			resultFuture.handle( function(result) {
				var res = result.context.actionContext.actionResult;
				if ( Std.is(res,expectedResultType)==false ) {
					Assert.fail( 'Expected result to be ${Type.getClassName(expectedResultType)}, but it was ${Type.getClassName(Type.getClass(res))}', p );
				}
				else if ( check!=null ) {
					check( cast res );
				}
			});
			return resultFuture;
		}
	#end
}

typedef RouteTestResult = {
	app: UfrontApplication,
	context: HttpContext
}
typedef RouteTestOutcome = Surprise<RouteTestResult, Error>;
