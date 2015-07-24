package ufront.web.result;

import utest.Assert;
import ufront.web.result.RedirectResult;
import ufront.test.TestUtils.NaturalLanguageTests.*;
using ufront.test.TestUtils;
using tink.CoreApi;

class RedirectResultTest {
	var instance:RedirectResult;

	public function new() {}

	public function beforeClass():Void {}

	public function afterClass():Void {}

	public function setup():Void {}

	public function teardown():Void {}

	public function testRedirect():Void {
		// Test temporary redirect, to a relative URL.
		var done1 = Assert.createAsync();
		var ctx1 = "/".mockHttpContext();
		var r1 = new RedirectResult( "/homepage", false );
		r1.executeResult( ctx1.actionContext ).handle(function(_) {
			Assert.equals( "/homepage", ctx1.response.redirectLocation );
			Assert.isFalse( ctx1.response.isPermanentRedirect() );
			done1();
		});

		// Test permanent redirect, to an absolute URL.
		var done2 = Assert.createAsync();
		var ctx2 = "/homepage".mockHttpContext();
		var r1 = new RedirectResult( "http://facebook.com/ourpage/", true );
		r1.executeResult( ctx2.actionContext ).handle(function(_) {
			Assert.equals( "http://facebook.com/ourpage/", ctx2.response.redirectLocation );
			Assert.isTrue( ctx2.response.isPermanentRedirect() );
			done2();
		});

		// Test calling this from the `create()` method.
		whenIVisit( "/" ).onTheController( FutureRedirectTestController ).itShouldReturn( RedirectResult, function(r) {
			Assert.equals( "/2999-12-31/", r.url );
			Assert.isFalse( r.permanentRedirect );
		})
		.finishTest();

		// Test calling this from the `create()` method.
		whenIVisit( "/permanent" ).onTheController( FutureRedirectTestController ).itShouldReturn( RedirectResult, function(r) {
			Assert.equals( "/tomorrow/", r.url );
			Assert.isTrue( r.permanentRedirect );
		})
		.finishTest();
	}
}

class FutureRedirectTestController extends ufront.web.Controller {
	@:route("/")
	function doRedirect() {
		var futureURL = Future.sync('/2999-12-31/');
		return futureURL >> RedirectResult.create;
	}
	@:route("/permanent")
	function doPermanentRedirect() {
		var futureURL = Future.sync('/tomorrow/');
		return futureURL >> RedirectResult.createPermanent;
	}


}
