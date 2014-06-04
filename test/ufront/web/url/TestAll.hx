package ufront.web.url;

import utest.Assert;
import utest.Runner;

class TestAll
{
	public static function addTests( runner:Runner ) {
		ufront.web.url.filter.TestAll.addTests( runner );
		runner.addCase( new ufront.web.url.PartialUrlTest() );
		runner.addCase( new ufront.web.url.VirtualUrlTest() );
	}
}
