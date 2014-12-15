package ufront.log;

import utest.Assert;
import utest.Runner;

class TestAll
{
	public static function addTests( runner:Runner ) {
		runner.addCase( new FileLoggerTest() );
		runner.addCase( new MessageListTest() );
		runner.addCase( new RemotingLoggerTest() );
		runner.addCase( new BrowserConsoleLoggerTest() );
		runner.addCase( new ServerConsoleLoggerTest() );
	}
}
