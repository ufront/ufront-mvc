package ufront;

import utest.Assert;
import utest.Runner;

class TestAll {
	public static function addTests( runner:Runner ) {
		ufront.core.TestAll.addTests( runner );
		ufront.app.TestAll.addTests( runner );
		ufront.handler.TestAll.addTests( runner );
		ufront.log.TestAll.addTests( runner );
		ufront.web.TestAll.addTests( runner );
		ufront.view.TestAll.addTests( runner );
		ufront.api.TestAll.addTests( runner );
		ufront.cache.TestAll.addTests( runner );
		ufront.test.TestAll.addTests( runner );
		ufront.auth.TestAll.addTests( runner );
		ufront.remoting.TestAll.addTests( runner );
	}
}
