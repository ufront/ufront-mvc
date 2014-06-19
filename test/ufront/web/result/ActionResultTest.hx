package ufront.web.result;

import utest.Assert;
import ufront.web.result.ActionResult;
import ufront.web.result.*;
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
		Assert.isFalse( ctx1.response._flushed );

		// Check a normal value is converted to a String and wrapped in a ContentResult.
		var ctx2 = "/".mockHttpContext();
		var contentResult = ActionResult.wrap( 123 );
		Assert.is( contentResult, ContentResult );
		contentResult.executeResult( ctx2.actionContext );
		Assert.equals( "123", ctx2.response.getBuffer() );
		Assert.equals( "text/html", ctx2.response.contentType );

		// Check an existing content result is used as is.
		var ctx3 = "/".mockHttpContext();
		var r = new RedirectResult( "/homepage/" );
		var redirectResult = ActionResult.wrap( r );
		Assert.is( redirectResult, RedirectResult );
		Assert.equals( r, redirectResult );
		redirectResult.executeResult( ctx3.actionContext );
		Assert.equals( "/homepage/", ctx3.response.redirectLocation );
	}
}