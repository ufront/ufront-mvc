package ufront.web.session;

import utest.Assert;
import utest.Runner;

class TestAll
{
	public static function addTests( runner:Runner ) {
		runner.addCase( new VoidSessionTest() );
		runner.addCase( new CacheSessionTest() );
		runner.addCase( new FileSessionTest() );
		runner.addCase( new InlineSessionMiddlewareTest() );
	}
}
