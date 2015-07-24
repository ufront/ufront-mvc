package ufront.test;

import haxe.PosInfos;
import utest.Assertation;
import utest.Assert;
import ufront.web.context.*;
import ufront.web.session.UFHttpSession;
import ufront.auth.UFAuthHandler;
import minject.Injector;
import tink.CoreApi;
import ufront.core.AsyncTools;
using ufront.test.TestUtils;
using mockatoo.Mockatoo;

class TestUtilsTest {
	public function new() {}

	public function beforeClass():Void {}

	public function afterClass():Void {}

	public function setup():Void {}

	public function teardown():Void {}

	public function testMockHttpContext():Void {
		var mock1 = TestUtils.mockHttpContext( "/test/" );
		Assert.notNull( mock1 );
		Assert.is( mock1.request, HttpRequest );
		Assert.is( mock1.response, HttpResponse );
		Assert.is( mock1.session, UFHttpSession );
		Assert.is( mock1.auth, UFAuthHandler );
		Assert.equals( "/test/", mock1.request.uri );
		Assert.equals( "GET", mock1.request.httpMethod );
		Assert.equals( 0, [ for (k in mock1.request.params.keys()) k ].length );

		var mock2 = "/test/2/".mockHttpContext( "post", ["id"=>"3","page"=>"20"] );
		Assert.equals( "/test/2/", mock2.request.uri );
		Assert.equals( "POST", mock2.request.httpMethod );
		Assert.equals( 2, [ for (k in mock2.request.params.keys()) k ].length );
		Assert.equals( "3", mock2.request.params["id"] );
		Assert.equals( "20", mock2.request.params["page"] );

		var injector = new Injector();
		var request = HttpRequest.mock();
		@:privateAccess request.uri.returns( "/test/3/" );
		var response = new HttpResponse();
		var session = new ufront.web.session.VoidSession();
		var auth = new ufront.auth.YesBossAuthHandler();
		var mock3 = TestUtils.mockHttpContext( "/test/3/", injector, request, response, session, auth );
		Assert.equals( "/test/3/", mock3.request.uri );
		Assert.equals( injector, mock3.injector.parent );
		Assert.equals( request, mock3.request );
		Assert.equals( response, mock3.response );
		Assert.equals( session, mock3.session );
		Assert.equals( auth, mock3.auth );
	}

	public function testTestRoute():Void {
		verifyTestRoute( "/".mockHttpContext().testRoute(TestController), true );
		verifyTestRoute( "/error".mockHttpContext().testRoute(TestController), false );
		verifyTestRoute( "/404".mockHttpContext().testRoute(TestController), false );

	}

	function verifyTestRoute( testContext:RequestTestContext, shouldBeSuccess:Bool, ?p:PosInfos ) {
		testContext.result.handle(function(outcome) switch outcome{
			case Success(Noise):
				Assert.notNull( testContext.app, p );
				Assert.notNull( testContext.context, p );
				Assert.isTrue( shouldBeSuccess, p );
			case Failure(err):
				Assert.notNull( err, p );
				Assert.isFalse( shouldBeSuccess, p );
		});
	}

	function expectFailure( whenDoing:Void->Void ) {
		var resultsbypass = Assert.results;
		Assert.results = new List();

		var results = Assert.results;
		Assert.results = resultsbypass;
		var successes = [],
		    failures = false;
		for ( result in results ) {
			switch result {
				case Failure(_,_): failures=true;
				case Success(p): successes.push( p );
				default: Assert.results.add( result );
			}
		}
		if ( failures==false ) {
			for ( p in successes )
				Assert.fail( 'A failure was expected at one of these positions, but a success occured.', p );
		}
	}

	public function testAssertSuccess():Void {
		// First test some passing cases.
		"/".mockHttpContext().testRoute( TestController ).assertSuccess();
		"/".mockHttpContext().testRoute( TestController ).assertSuccess(TestController,"index",[]);
		"/user/13/".mockHttpContext().testRoute( TestController ).assertSuccess(TestController,"getUser",[13]);
		"/user/13/".mockHttpContext("POST", [ "name" => "Jason" ]).testRoute( TestController ).assertSuccess(TestController,"setUser",[13,{"name":"Jason"}]);

		// And then test some failing cases.
		expectFailure( function() {
			"/".mockHttpContext().testRoute( TestController2 ).assertSuccess();
		});
		expectFailure( function() {
			"/404".mockHttpContext().testRoute( TestController ).assertSuccess(TestController,"index",[]);
		});
		expectFailure( function() {
			"/error".mockHttpContext().testRoute( TestController ).assertSuccess(TestController,"index",[]);
		});
		expectFailure( function() {
			"/failure".mockHttpContext().testRoute( TestController ).assertSuccess(TestController,"index",[]);
		});
		expectFailure( function() {
			"/user/not-an-int".mockHttpContext().testRoute( TestController ).assertSuccess(TestController,"index",[]);
		});
	}

	public function testAssertFailure():Void {
		// First test some cases which fail as intended.
		"/404".mockHttpContext().testRoute( TestController ).assertFailure( 404 );
		"/error".mockHttpContext().testRoute( TestController ).assertFailure( 500 );
		"/failure".mockHttpContext().testRoute( TestController ).assertFailure( 500 );
		"/user/not-an-int".mockHttpContext().testRoute( TestController ).assertFailure( 400 );

		// Then test some cases which accidentally pass.
		expectFailure( function() {
			"/".mockHttpContext().testRoute( TestController ).assertFailure(404);
		});
		expectFailure( function() {
			"/".mockHttpContext().testRoute( TestController ).assertFailure(404);
		});
		expectFailure( function() {
			"/user/13/".mockHttpContext().testRoute( TestController ).assertFailure(404);
		});
		expectFailure( function() {
			"/user/13/".mockHttpContext("POST", [ "name" => "Jason" ]).testRoute( TestController ).assertFailure(404);
		});
	}
}

class TestController extends ufront.web.Controller {
	@:route("/") function index() return "Hello!";
	@:route(GET, "/user/$id/") function getUser( id:Int ) return 'Get $id';
	@:route(POST, "/user/$id/") function setUser( id:Int, args:{ name:String } ) return 'Set $id to ${args.name}';
	@:route("/error") function error() return throw "Ouch!";
	@:route("/failure") function failure() return SurpriseTools.asSurpriseError(null,"Ouch!");
}
class TestController2 extends ufront.web.Controller {
	@:route("/") function index() return "Hello 2!";
}
