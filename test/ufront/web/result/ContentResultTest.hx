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

	public function testContentResult():Void {
		var ctx = "/".mockHttpContext();
		var defaultContentType = ctx.response.contentType;
		new ContentResult().executeResult( ctx.actionContext );
		Assert.equals( "", ctx.response.getBuffer() );
		Assert.equals( defaultContentType, ctx.response.contentType );

		// Now with some actual content...

		var ctx = "/".mockHttpContext();
		new ContentResult( "Hello!", "text/plain" ).executeResult( ctx.actionContext );
		Assert.equals( "Hello!", ctx.response.getBuffer() );
		Assert.equals( "text/plain", ctx.response.contentType );
	}
}
