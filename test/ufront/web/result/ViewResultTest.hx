package ufront.web.result;

import utest.Assert;
import ufront.web.result.ViewResult;
import ufront.view.*;
using tink.CoreApi;

class ViewResultTest {
	var instance:ViewResult;

	public function new() {}

	public function beforeClass():Void {}

	public function afterClass():Void {}

	public function setup():Void {}

	public function teardown():Void {}

	// public function testViewResult():Void {}

	public function testViewResultWithFuture():Void {
		// Test that our `ViewResult.create` shortcut works with futures.
		var futureData = Future.sync({ name: "Jason" });
		var viewResultFuture = futureData >> ViewResult.create;
		viewResultFuture.handle(function(vr) {
			Assert.equals( "Jason", vr.data['name'] );
		});
	}

	public function testRenderWithPartials():Void {
		var layout = "<html><head><title>::name::</title></head><body>::viewContent::</body></html>";
		var view = "<h1>$$upper(::name::)</h1><div>$$list(::pets::)</div>";
		var upperHelper = function(str:String) return str.toUpperCase();
		var listPartial = "<ul>@for(item in __current__){<li>@upper(item)</li>}</ul>";
		var vr = new ViewResult({ name:"Jason", age:28, pets:["dog","cat","fish"] });
		vr.usingTemplateString( view, layout, TemplatingEngines.haxe );
		vr.addHelper( "upper", upperHelper );
		vr.addPartialString( "list", listPartial, TemplatingEngines.erazor );
		var viewEngine = null;
		vr.renderResult( viewEngine ).handle(function(outcome) {
			switch outcome {
				case Success(str):
					var expected = "<html><head><title>Jason</title></head><body><h1>JASON</h1><div><ul><li>DOG</li><li>CAT</li><li>FISH</li></ul></div></body></html>";
					Assert.equals( expected, str );
				case Failure(err):
					Assert.fail( 'Failed to render ViewResult with partials: $err' );
			}
		});
	}
}
