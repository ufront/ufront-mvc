package ufront.remoting;

import utest.Assert;
import utest.Runner;

class TestAll {
	public static function addTests( runner:Runner ) {
		runner.addCase( new RemotingHandlerTest() );
		runner.addCase( new RemotingSerializerTest() );
		runner.addCase( new RemotingUnserializerTest() );
		runner.addCase( new RemotingUtilTest() );
		runner.addCase( new HttpAsyncConnectionTest() );
		runner.addCase( new HttpConnectionTest() );
	}
}
