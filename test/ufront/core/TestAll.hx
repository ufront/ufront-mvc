package ufront.core;

import utest.Assert;
import utest.Runner;

class TestAll
{
	public static function addTests( runner:Runner ) {
		runner.addCase( new FuturoidTest() );
		runner.addCase( new AcceptEitherTest() );
		runner.addCase( new MultiValueMapTest() );
		runner.addCase( new SyncTest() );
		runner.addCase( new SurpriseToolsTest() );
		runner.addCase( new InjectionRefTest() );
		runner.addCase( new InjectionToolsTest() );
	}
}
