package haxe.remoting;

import utest.Assert;
import utest.Runner;

class TestAll
{
	public static function addTests( runner:Runner ) {
		runner.addCase( new RemotingUtilTest() );
		runner.addCase( new HttpAsyncConnectionWithTracesTest() );
		runner.addCase( new HttpConnectionWithTracesTest() );
	}
}
