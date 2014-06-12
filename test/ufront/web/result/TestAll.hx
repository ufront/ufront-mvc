package ufront.web.result;

import utest.Assert;
import utest.Runner;

class TestAll
{
	public static function addTests( runner:Runner ) {
		runner.addCase( new DetoxResultTest() );
		runner.addCase( new ViewResultTest() );
		runner.addCase( new ContentResultTest() );
		runner.addCase( new RedirectResultTest() );
		runner.addCase( new FileResultTest() );
		runner.addCase( new JsonResultTest() );
		runner.addCase( new BytesResultTest() );
		runner.addCase( new EmptyResultTest() );
		runner.addCase( new DirectFilePathResultTest() );
		runner.addCase( new FilePathResultTest() );
		runner.addCase( new ActionResultTest() );
	}
}
