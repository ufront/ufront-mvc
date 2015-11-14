package ufront.web.upload;

import utest.Assert;
import utest.Runner;

class TestAll {
	public static function addTests( runner:Runner ) {
		#if js
			runner.addCase( new BrowserFileUploadTest() );
		#end
		runner.addCase( new TmpFileUploadTest() );
		runner.addCase( new TmpFileUploadMiddlewareTest() );
	}
}
