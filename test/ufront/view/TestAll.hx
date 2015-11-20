package ufront.view;

import utest.Assert;
import utest.Runner;

class TestAll {
	public static function addTests( runner:Runner ) {
		runner.addCase( new UFViewEngineTest() );
		runner.addCase( new FileViewEngineTest() );
		runner.addCase( new TemplateDataTest() );
		runner.addCase( new TemplateHelperTest() );
		runner.addCase( new TemplatingEnginesTest() );
		runner.addCase( new UFTemplateTest() );
	}
}
