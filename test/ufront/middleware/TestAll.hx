package ufront.middleware;

import utest.Assert;
import utest.Runner;

class TestAll
{
	public static function addTests( runner:Runner ) {
		runner.addCase( new InlineSessionMiddlewareTest() );
		runner.addCase( new RequestCacheMiddlewareTest() );
	}
}
