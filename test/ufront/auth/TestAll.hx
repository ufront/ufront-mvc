package ufront.auth;

import utest.Assert;
import utest.Runner;

class TestAll
{
	public static function addTests( runner:Runner ) {
		runner.addCase( new YesBossAuthHandlerTest() );
		runner.addCase( new NobodyAuthHandlerTest() );
	}
}
