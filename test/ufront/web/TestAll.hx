package ufront.web;

import utest.Assert;
import utest.Runner;

class TestAll
{
	public static function addTests( runner:Runner ) {
		ufront.web.context.TestAll.addTests( runner );
		ufront.web.session.TestAll.addTests( runner );
		ufront.web.result.TestAll.addTests( runner );
		ufront.web.url.TestAll.addTests( runner );
		ufront.web.upload.TestAll.addTests( runner );
		runner.addCase( new HttpErrorTest() );
		runner.addCase( new HttpCookieTest() );
		runner.addCase( new ControllerMacrosTest() );
		runner.addCase( new UserAgentTest() );
		runner.addCase( new ControllerTest() );
	}
}
