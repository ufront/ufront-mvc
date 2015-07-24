package ufront.web.session;

import utest.Assert;
import ufront.MVC;

class CacheSessionTest {

	public function new() {}

	public function testCacheSession():Void {
		GenericSessionTest.testSessionImplementation( CacheSession, function(injector) {
			var cache = new MemoryCacheConnection();
			injector.map( UFCacheConnection ).toValue( cache );
		});
	}
}
