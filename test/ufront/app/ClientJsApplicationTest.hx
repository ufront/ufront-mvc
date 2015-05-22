package ufront.app;

#if client
	import utest.Assert;
	import ufront.app.ClientJsApplication;
#end

class ClientJsApplicationTest {
	public function new() {}

	#if client
		var instance:ClientJsApplication;

		public function beforeClass():Void {}

		public function afterClass():Void {}

		public function setup():Void {}

		public function teardown():Void {}

		// public function testExample():Void {}
	#end
}
