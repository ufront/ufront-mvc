package ufront.web.result;

import utest.Assert;
import ufront.web.result.RedirectResult;
using ufront.test.TestUtils;

class RedirectResultTest {
	var instance:RedirectResult;

	public function new() {}

	public function beforeClass():Void {}

	public function afterClass():Void {}

	public function setup():Void {}

	public function teardown():Void {}

	public function testRedirect():Void {

		var done1 = Assert.createAsync();
		var ctx1 = "/".mockHttpContext();
		var r1 = new RedirectResult( "/homepage", false );
		r1.executeResult( ctx1.actionContext ).handle(function(_) {
			Assert.equals( "/homepage", ctx1.response.redirectLocation );
			Assert.isFalse( ctx1.response.isPermanentRedirect() );
			done1();
		});

		var done2 = Assert.createAsync();
		var ctx2 = "/homepage".mockHttpContext();
		var r1 = new RedirectResult( "http://facebook.com/ourpage/", true );
		r1.executeResult( ctx2.actionContext ).handle(function(_) {
			Assert.equals( "http://facebook.com/ourpage/", ctx2.response.redirectLocation );
			Assert.isTrue( ctx2.response.isPermanentRedirect() );
			done2();
		});
	}
}
