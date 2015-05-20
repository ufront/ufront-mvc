package ufront.web.upload;

import utest.Assert;
import utest.Runner;

class TestAll
{
	public static function addTests( runner:Runner ) {
		runner.addCase( new TmpFileUploadTest() );
		runner.addCase( new TmpFileUploadMiddlewareTest() );
	}
}
