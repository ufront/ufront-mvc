package ufront.web.result;

import utest.Assert;
import ufront.web.result.ContentResult;
import ufront.test.TestUtils.NaturalLanguageTests.*;
using ufront.test.TestUtils;
using tink.CoreApi;

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

		whenIVisit("/")
		.onTheController( ContentResultTestController )
		.itShouldLoad()
		.responseShouldBe( "<html><body>Hello!</body></html>" )
		.finishTest();
	}
}

class ContentResultTestController extends ufront.web.Controller {
	@:route("/")
	function getContent() {
		var futureContent = Future.sync( "<html><body>Hello!</body></html>" );
		return futureContent >> ContentResult.create;
	}
}
