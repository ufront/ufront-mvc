package ufront.web.client;

import utest.Assert;
import utest.Runner;

class TestAll {
	public static function addTests( runner:Runner ) {
		#if js
			runner.addCase( new UFClientActionTest() );
		#end
	}
}
