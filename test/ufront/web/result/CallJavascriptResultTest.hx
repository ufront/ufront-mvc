package ufront.web.result;

import utest.Assert;
import ufront.web.result.*;
using ufront.test.TestUtils;

class CallJavascriptResultTest {

	public function new() {}

	public function beforeClass():Void {}

	public function afterClass():Void {}

	var contentResult:ContentResult;
	var jsonResult:JsonResult<Dynamic>;
	var callJavascriptResult1:CallJavascriptResult<ContentResult>;
	var callJavascriptResult2:CallJavascriptResult<JsonResult<Dynamic>>;

	public function setup():Void {
		contentResult = new ContentResult( "<html><body><h1>Title</h1><div>Content</div></body></html>", "text/html" );
		callJavascriptResult1 = new CallJavascriptResult( contentResult );

		jsonResult = new JsonResult({ name: "Ufront" });
		callJavascriptResult2 = new CallJavascriptResult( jsonResult );
	}

	public function teardown():Void {}

	public function testBasics():Void {
		Assert.equals( 0, callJavascriptResult1.scripts.length );
		Assert.equals( 0, callJavascriptResult2.scripts.length );
		Assert.equals( contentResult, callJavascriptResult1.originalResult );
		Assert.equals( jsonResult, callJavascriptResult2.originalResult );

		callJavascriptResult1.addInlineJs("alert(123);");
		callJavascriptResult1.addJsScript("456.js");
		callJavascriptResult1.addInlineJs("alert(789);");

		Assert.equals( 3, callJavascriptResult1.scripts.length );
		Assert.equals( '<script type="text/javascript">alert(123);</script>', callJavascriptResult1.scripts[0] );
		Assert.equals( '<script type="text/javascript" src="456.js"></script>', callJavascriptResult1.scripts[1] );
	}

	public function testExecuteResult():Void {
		var context = '/baseurl/'.mockHttpContext();
		callJavascriptResult1.addInlineJs("alert(123);");
		var future = callJavascriptResult1.executeResult( context.actionContext );
		// Note, the future here will execute synchronously, but tink_core will not run the mapping function in `executeResult` unless we handle it.
		// Lazy evaluation or something.
		future.handle( function(_) {} );
		Assert.equals( '<html><body><h1>Title</h1><div>Content</div><script type="text/javascript">alert(123);</script></body></html>', context.response.getBuffer() );
	}
}
