package ufront.web.url.filter;

import utest.Assert;
import utest.Runner;

class TestAll {
	public static function addTests( runner:Runner ) {
		runner.addCase( new DirectoryUrlFilterTest() );
		runner.addCase( new QueryStringUrlFilterTest() );
		runner.addCase( new PathInfoUrlFilterTest() );
	}
}
