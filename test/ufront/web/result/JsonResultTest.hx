package ufront.web.result;

import utest.Assert;
import ufront.web.result.JsonResult;
import ufront.test.TestUtils.NaturalLanguageTests.*;
using tink.CoreApi;
using ufront.test.TestUtils;

class JsonResultTest {
	public function new() {}

	public function beforeClass():Void {}

	public function afterClass():Void {}

	public function setup():Void {}

	public function teardown():Void {}

	public function testObject():Void {
		whenIVisit("/test-object")
		.onTheController( JsonResultTestController )
		.itShouldLoad()
		.itShouldReturn( JsonResult, function(jr) {
			Assert.equals( "Jason", jr.content.name );
			Assert.equals( "Drop bears", jr.content.irrationalFear );
		})
		.andThenCheck(function(testContext) {
			var res = testContext.context.response;
			Assert.equals( 200, res.status );
			Assert.equals( "application/json", res.contentType );
			var jsonObj = haxe.Json.parse( res.getBuffer() );
			Assert.equals( "Jason", jsonObj.name );
			Assert.equals( "Drop bears", jsonObj.irrationalFear );
		})
		.finishTest();
	}

	public function testClassInstance():Void {
		whenIVisit("/test-class/5/21/")
		.onTheController( JsonResultTestController )
		.itShouldLoad()
		.andThenCheck(function(testContext) {
			var res = testContext.context.response;
			var jsonObj = haxe.Json.parse( res.getBuffer() );
			Assert.equals( 5, jsonObj.x );
			Assert.equals( 21, jsonObj.y );
		})
		.finishTest();
	}

	public function testFuture():Void {
		whenIVisit("/test-future/ufront/")
		.onTheController( JsonResultTestController )
		.itShouldLoad()
		.theResponseShouldBe( '"ufront"' )
		.finishTest();
	}
}

class JsonResultTestController extends ufront.web.Controller {
	@:route("/test-object")
	function test1() {
		return new JsonResult({ name:"Jason", irrationalFear:"Drop bears" });
	}

	@:route("/test-class/$x/$y/")
	function test2( x:Int, y:Int ) {
		return new JsonResult( new Point(x,y) );
	}

	@:route("/test-future/$name/")
	function test3( name:String ) {
		var future = Future.sync( name );
		return future >> JsonResult.create;
	}
}

class Point {
	var x:Int;
	var y:Int;
	public function new(x,y) {
		this.x = x;
		this.y = y;
	}
}
