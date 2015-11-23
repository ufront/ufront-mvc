package ufront.web.upload;

import utest.Assert;
import utest.Runner;

class TestAll {
	public static function addTests( runner:Runner ) {
		runner.addCase( new BaseUploadTest() );
		runner.addCase( new BrowserFileUploadTest() );
		#if (js && pushstate)
			runner.addCase( new BrowserFileUploadMiddlewareTest() );
		#end
		runner.addCase( new TmpFileUploadTest() );
		runner.addCase( new TmpFileUploadMiddlewareTest() );
	}
}
