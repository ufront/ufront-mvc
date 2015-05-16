package ufront.core;

import utest.Assert;
import tink.CoreApi;
using ufront.core.AsyncTools;

class AsyncToolsTest {
	public function new() {}

	public function beforeClass():Void {}

	public function afterClass():Void {}

	public function setup():Void {}

	public function teardown():Void {}

	public function testWhen():Void {
		var done1 = Assert.createAsync();
		var done2 = Assert.createAsync();

		var ft1 = Future.trigger();
		var ft2:FutureTrigger<Int> = Future.trigger();
		var f1 = ft1.asFuture();
		var f2 = ft2.asFuture();
		var f3:Surprise<Noise,Error> = SurpriseTools.success();

		ft1.trigger( "Hello" );

		FutureTools.when(f1,f2,f3).handle(function(v1,v2,v3) {
			Assert.equals( "Hello", v1 );
			Assert.equals( 5, v2 );
			Assert.isTrue( v3.match(Success(Noise)) );
			done1();
		});

		var mappedFuture = FutureTools.when(f1,f2,f3).map(function(v1,v2,v3) {
			return '$v1$v2$v3';
		});
		mappedFuture.handle(function(str) {
			Assert.equals( 'Hello5Success(Noise)', str );
			done2();
		});

		ft2.trigger( 5 );
	}
}
