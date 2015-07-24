package ufront.log;

import utest.Assert;
import ufront.MVC;
import ufront.test.TestUtils.NaturalLanguageTests.*;
using ufront.test.TestUtils;

class OriginalTraceLoggerTest {

	public function new() {}

	public function testBasic():Void {
		var traceCounter = 0;
		var oldTrace = haxe.Log.trace;
		haxe.Log.trace = function(msg:Dynamic,?pos:haxe.PosInfos) {
			traceCounter++;
		}

		var testApp = new UfrontApplication({
			indexController: OriginalTraceTestController,
			disableBrowserTrace: true,
			disableServerTrace: true,
		});
		testApp.addLogHandler( new OriginalTraceLogger() );

		whenIVisit("/")
		.onTheApp( testApp )
		.itShouldLoad()
		.andThenCheck(function () {
			var expected = #if debug 5 #else 4 #end;
			Assert.equals( expected, traceCounter );

			testApp.dispose().handle(function() {
				haxe.Log.trace = oldTrace;
			});
		});
	}
}

class OriginalTraceTestController extends Controller {
	@:route("/")
	public function testTrace() {
		trace( 1 );
		ufTrace( 2 );
		ufLog( 3 );
		ufWarn( 4 );
		ufError( 5 );
	}
}
