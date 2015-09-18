package ufront.web.result;

import utest.Assert;
import ufront.web.result.ActionResult;
import ufront.web.result.*;
import ufront.web.url.filter.*;
using ufront.test.TestUtils;

class ActionResultTest {

	public function new() {}

	public function beforeClass():Void {}

	public function afterClass():Void {}

	public function setup():Void {}

	public function teardown():Void {}

	@:access( ufront.web.context.HttpResponse )
	public function testWrap():Void {

		// Check `null` is wrapped into an EmptyResult that does not prevent flushing.
		var ctx1 = "/".mockHttpContext();
		var nullResult = ActionResult.wrap( null );
		Assert.is( nullResult, EmptyResult );
		nullResult.executeResult( ctx1.actionContext );
		Assert.equals( "", ctx1.response.getBuffer() );
		Assert.isFalse( ctx1.response._flushedStatus );
		Assert.isFalse( ctx1.response._flushedCookies );
		Assert.isFalse( ctx1.response._flushedHeaders );
		Assert.isFalse( ctx1.response._flushedContent );

		// Check a normal value is converted to a String and wrapped in a ContentResult.
		var done1 = Assert.createAsync();
		var ctx2 = "/".mockHttpContext();
		var contentResult = ActionResult.wrap( 123 );
		Assert.is( contentResult, ContentResult );
		contentResult.executeResult( ctx2.actionContext ).handle(function(_) {
			Assert.equals( "123", ctx2.response.getBuffer() );
			Assert.equals( "text/html", ctx2.response.contentType );
			done1();
		});

		// Check an existing content result is used as is.
		var done2 = Assert.createAsync();
		var ctx3 = "/".mockHttpContext();
		var r = new RedirectResult( "/homepage/" );
		var redirectResult = ActionResult.wrap( r );
		Assert.is( redirectResult, RedirectResult );
		Assert.equals( r, redirectResult );
		redirectResult.executeResult( ctx3.actionContext ).handle(function(_) {
			Assert.equals( "/homepage/", ctx3.response.redirectLocation );
			done2();
		});
	}

	public function testTransformUri() {
		var uri1 = "/";
		var uri2 = "~/";
		var uri3 = "/home/index.html";
		var uri4 = "~/home/index.html";
		var uri5 = "http://some/~/home/index.html";

		var contextSimple = "/".mockHttpContext();
		var contextDirFilter = "/".mockHttpContext();
		contextDirFilter.setUrlFilters([ new DirectoryUrlFilter("/path/to/app/") ]);
		var contextPathInfoFilter = "/".mockHttpContext();
		contextPathInfoFilter.setUrlFilters([ new PathInfoUrlFilter("index.php",false) ]);
		var contextQueryStringFilter = "/".mockHttpContext();
		contextQueryStringFilter.setUrlFilters([ new QueryStringUrlFilter("page","index.php",true) ]);

		// No URL filters
		Assert.equals( "/", ActionResult.transformUri(contextSimple.actionContext,uri1) );
		Assert.equals( "/", ActionResult.transformUri(contextSimple.actionContext,uri2) );
		Assert.equals( "/home/index.html", ActionResult.transformUri(contextSimple.actionContext,uri3) );
		Assert.equals( "/home/index.html", ActionResult.transformUri(contextSimple.actionContext,uri4) );
		Assert.equals( "http://some/~/home/index.html", ActionResult.transformUri(contextSimple.actionContext,uri5) );

		// Directory URL filter
		Assert.equals( "/", ActionResult.transformUri(contextDirFilter.actionContext,uri1) );
		Assert.equals( "/path/to/app", ActionResult.transformUri(contextDirFilter.actionContext,uri2) );
		Assert.equals( "/home/index.html", ActionResult.transformUri(contextDirFilter.actionContext,uri3) );
		Assert.equals( "/path/to/app/home/index.html", ActionResult.transformUri(contextDirFilter.actionContext,uri4) );
		Assert.equals( "http://some/~/home/index.html", ActionResult.transformUri(contextDirFilter.actionContext,uri5) );

		// Path info URL filter
		Assert.equals( "/", ActionResult.transformUri(contextPathInfoFilter.actionContext,uri1) );
		Assert.equals( "/index.php", ActionResult.transformUri(contextPathInfoFilter.actionContext,uri2) );
		Assert.equals( "/home/index.html", ActionResult.transformUri(contextPathInfoFilter.actionContext,uri3) );
		Assert.equals( "/index.php/home/index.html", ActionResult.transformUri(contextPathInfoFilter.actionContext,uri4) );
		Assert.equals( "http://some/~/home/index.html", ActionResult.transformUri(contextPathInfoFilter.actionContext,uri5) );

		// Query String URL filter
		Assert.equals( "/", ActionResult.transformUri(contextQueryStringFilter.actionContext,uri1) );
		Assert.equals( "/", ActionResult.transformUri(contextQueryStringFilter.actionContext,uri2) );
		Assert.equals( "/home/index.html", ActionResult.transformUri(contextQueryStringFilter.actionContext,uri3) );
		Assert.equals( "/index.php?page=/home/index.html", ActionResult.transformUri(contextQueryStringFilter.actionContext,uri4) );
		Assert.equals( "http://some/~/home/index.html", ActionResult.transformUri(contextQueryStringFilter.actionContext,uri5) );
	}
}
