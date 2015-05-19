package ufront.web.result;

import utest.Assert;
import ufront.web.result.ViewResult;
import ufront.view.TemplateData;
using tink.CoreApi;

class ViewResultTest {
	var instance:ViewResult;

	public function new() {}

	public function beforeClass():Void {}

	public function afterClass():Void {}

	public function setup():Void {}

	public function teardown():Void {}

	public function testViewResult():Void {
	}
	
	public function testViewResultWithFuture():Void {
		// Test that our `ViewResult.create` shortcut works with futures.
		var futureData = Future.sync({ name: "Jason" });
		var viewResultFuture = futureData >> ViewResult.create;
		viewResultFuture.handle(function(vr) {
			Assert.equals( "Jason", vr.data['name'] );
		});
	}
}
