package ufront.app;

import utest.Assert;
import utest.Runner;

class TestAll
{
	public static function addTests( runner:Runner ) {
		runner.addCase( new UfrontApplicationTest() );
		runner.addCase( new HttpApplicationTest() );
		runner.addCase( new ClientJsApplicationTest() );
		runner.addCase( new DefaultUfrontConfigurationTest() );
		runner.addCase( new UfrontConfigurationTest() );
	}
}
