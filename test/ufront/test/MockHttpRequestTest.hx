package ufront.test;

import haxe.PosInfos;
import utest.Assertation;
import utest.Assert;
import ufront.test.MockHttpRequest;

class MockHttpRequestTest {
	public function new() {}

	public function beforeClass():Void {}

	public function afterClass():Void {}

	public function setup():Void {}

	public function teardown():Void {}

	public function testMockHttpRequest():Void {
		var mock1 = new MockHttpRequest( "/login/" );
		Assert.equals( "/login/", mock1.uri );
	}
}
