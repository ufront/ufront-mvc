package ufront.api;

import utest.Assert;
import utest.Runner;

class TestAll {
	public static function addTests( runner:Runner ) {
		runner.addCase( new ApiMacrosTest() );
		runner.addCase( new UFApiTest() );
		runner.addCase( new UFApiContextTest() );
	}
}
