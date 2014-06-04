package ufront.web.upload;

import utest.Assert;
import utest.Runner;

class TestAll
{
	public static function addTests( runner:Runner ) {
		runner.addCase( new TmpFileUploadSyncTest() );
		runner.addCase( new TmpFileUploadMiddlewareTest() );
	}
}
