package ufront.web.context;

import utest.Assert;
import utest.Runner;

class TestAll {
	public static function addTests( runner:Runner ) {
		runner.addCase( new HttpResponseTest() );
		runner.addCase( new ActionContextTest() );
		runner.addCase( new HttpRequestTest() );
		runner.addCase( new HttpContextTest() );
	}
}
