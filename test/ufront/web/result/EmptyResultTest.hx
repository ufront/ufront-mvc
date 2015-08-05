package ufront.web.result;

import utest.Assert;
import ufront.web.result.EmptyResult;
using ufront.test.TestUtils;

class EmptyResultTest {
	var instance:EmptyResult;

	public function new() {}

	public function beforeClass():Void {}

	public function afterClass():Void {}

	public function setup():Void {}

	public function teardown():Void {}

	@:access( ufront.web.context.HttpResponse )
	public function testEmptyResult():Void {
		var ctx = "/".mockHttpContext();

		// Check that by default _flushed is false, meaning we can still write content.
		new EmptyResult().executeResult( ctx.actionContext );
		Assert.isFalse( ctx.response._flushedStatus );
		Assert.isFalse( ctx.response._flushedCookies );
		Assert.isFalse( ctx.response._flushedHeaders );
		Assert.isFalse( ctx.response._flushedContent );

		// Check that preventFlush marks _flushed as true, so no further content is written.
		new EmptyResult(true).executeResult( ctx.actionContext );
		Assert.isTrue( ctx.response._flushedStatus );
		Assert.isTrue( ctx.response._flushedCookies );
		Assert.isTrue( ctx.response._flushedHeaders );
		Assert.isTrue( ctx.response._flushedContent );
	}
}
