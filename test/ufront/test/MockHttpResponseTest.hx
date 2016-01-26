package ufront.test;

import haxe.PosInfos;
import utest.Assertation;
import utest.Assert;
import ufront.test.MockHttpResponse;

class MockHttpResponseTest {
	public function new() {}

	public function beforeClass():Void {}

	public function afterClass():Void {}

	public function setup():Void {}

	public function teardown():Void {}

	public function testMockHttpResponse():Void {
		var mock1 = new MockHttpResponse();
		mock1.write( "HELLO!" );
		mock1.flush();
		Assert.equals( "HELLO!", mock1.flushedContent );
	}
}
