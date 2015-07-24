package issues;

import ufront.MVC;
import ufront.test.TestUtils.NaturalLanguageTests.*;
using ufront.test.TestUtils;
using ufront.core.InjectionTools;
import minject.Injector;
using mockatoo.Mockatoo;
using tink.CoreApi;

class Issue20 {
	public function new() {}

	public function beforeClass():Void {}

	public function afterClass():Void {}

	public function setup():Void {}

	public function teardown():Void {}

	public function testViewEngineInjection():Void {
		whenIVisit("/")
		.onTheController( Issue20Controller )
		.itShouldLoad();
	}
}

class Issue20Controller extends Controller {
	@inject public var viewEngine:UFViewEngine;

	@:route("/") function home() {
		return new ViewResult({}).usingTemplateString( "Hello!" );
	}
}
