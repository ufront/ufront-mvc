package ufront.handler;

import utest.Assert;
import utest.Runner;

class TestAll
{
	public static function addTests( runner:Runner ) {
		runner.addCase( new ErrorPageHandlerTest() );
		runner.addCase( new RemotingHandlerTest() );
		runner.addCase( new MVCHandlerTest() );
	}
}
