package ufront.cache;

import utest.Assert;
import utest.Runner;

class TestAll {
	public static function addTests( runner:Runner ) {
		runner.addCase( new MemoryCacheTest() );
		runner.addCase( new RequestCacheMiddlewareTest() );
	}
}
