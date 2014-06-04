package ufront.web.session;

import utest.Assert;
import utest.Runner;

class TestAll
{
	public static function addTests( runner:Runner ) {
		runner.addCase( new InlineSessionMiddlewareTest() );
		runner.addCase( new VoidSessionTest() );
		runner.addCase( new FileSessionTest() );
	}
}
