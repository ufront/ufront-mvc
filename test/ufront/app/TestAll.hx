package ufront.app;

import utest.Assert;
import utest.Runner;

class TestAll
{
	public static function addTests( runner:Runner ) {
		runner.addCase( new UfrontApplicationTest() );
		runner.addCase( new HttpApplicationTest() );
	}
}
