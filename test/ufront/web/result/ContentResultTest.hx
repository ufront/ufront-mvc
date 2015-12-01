package ufront.web.result;

import utest.Assert;
import ufront.web.result.ContentResult;
import ufront.test.TestUtils.NaturalLanguageTests.*;
import ufront.web.url.filter.*;
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
		.responseShouldBe( "<html><body>Hello!</body></html>" );
	}

	public function testReplaceRelativeLinks() {
		var html = '<html>
		<a href="/">Absolute</a>
		<a href="~/">Relative</a>
		<img src=\'/absolute.jpg\' />
		<img src=\'~/relative.png\' />
		<a href="/absolute/">Link</a>
		<a href="~/relative/">Link</a>
		<script src=\'/absolute.js\' />
		<script src=\'~/relative.js\' />
		"~/relative/"
		\'~/relative/\'
		~/relative/
		Done!';
		var expected = '<html>
		<a href="/">Absolute</a>
		<a href="/path/to/app/index.php?q=/">Relative</a>
		<img src=\'/absolute.jpg\' />
		<img src=\'/path/to/app/index.php?q=/relative.png\' />
		<a href="/absolute/">Link</a>
		<a href="/path/to/app/index.php?q=/relative/">Link</a>
		<script src=\'/absolute.js\' />
		<script src=\'/path/to/app/index.php?q=/relative.js\' />
		"/path/to/app/index.php?q=/relative/"
		\'/path/to/app/index.php?q=/relative/\'
		~/relative/
		Done!';

		var context = "/".mockHttpContext();
		context.setUrlFilters([
			new DirectoryUrlFilter( "/path/to/app" ),
			new QueryStringUrlFilter( "q", "index.php", false )
		]);
		var actual = ContentResult.replaceVirtualLinks( context.actionContext, html );
		Assert.equals( expected, actual );
	}
}

class ContentResultTestController extends ufront.web.Controller {
	@:route("/")
	function getContent() {
		var futureContent = Future.sync( "<html><body>Hello!</body></html>" );
		return futureContent >> ContentResult.create;
	}
}
