package ufront.core;

import utest.Assert;
import utest.Runner;

class TestAll {
	public static function addTests( runner:Runner ) {
		runner.addCase( new FuturisticTest() );
		runner.addCase( new AcceptEitherTest() );
		runner.addCase( new MultiValueMapTest() );
		runner.addCase( new AsyncToolsTest() );
		runner.addCase( new InjectionToolsTest() );
	}
}
