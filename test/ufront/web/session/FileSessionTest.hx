package ufront.web.session;

import utest.Assert;
import ufront.web.session.FileSession;

class FileSessionTest {

	public function new() {}

	#if (sys || nodejs)
		public function testFileSession():Void {
			GenericSessionTest.testSessionImplementation( FileSession );
		}
	#end
}
