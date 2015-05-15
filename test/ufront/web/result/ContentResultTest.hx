package ufront.web.result;

import utest.Assert;
import ufront.web.result.ContentResult;
using ufront.test.TestUtils;

class ContentResultTest {
	public function new() {}

	public function beforeClass():Void {}

	public function afterClass():Void {}

	public function setup():Void {}

	public function teardown():Void {}

	public function testContentType():Void {
		var done1 = Assert.createAsync();
		var ctx = "/".mockHttpContext();
		var defaultContentType = ctx.response.contentType;
		new ContentResult().executeResult( ctx.actionContext ).handle(function(result) {
			Assert.equals( "", ctx.response.getBuffer() );
			Assert.equals( defaultContentType, ctx.response.contentType );
			done1();
		});

		var done2 = Assert.createAsync();
		var ctx = "/".mockHttpContext();
		new ContentResult( "Hello!", "text/plain" ).executeResult( ctx.actionContext ).handle(function() {
			Assert.equals( "Hello!", ctx.response.getBuffer() );
			Assert.equals( "text/plain", ctx.response.contentType );
			done2();
		});
	}
}
