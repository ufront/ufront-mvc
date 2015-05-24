package;

import utest.Assert;
import utest.Runner;
import utest.ui.Report;

class TestAll {
	static function main(){
		var runner = new Runner();
		addTests( runner );
		Report.create(runner);
		runner.run();
	}

	public static function addTests( runner:Runner ) {
		ufront.TestAll.addTests( runner );
		issues.TestAll.addTests( runner );
	}
}
