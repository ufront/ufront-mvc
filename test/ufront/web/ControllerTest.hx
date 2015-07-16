package ufront.web;

import utest.Assert;
import ufront.web.Controller;
import ufront.web.result.*;
using ufront.test.TestUtils;

class ControllerTest {
	var instance:Controller;

	public function new() {}

	public function beforeClass():Void {}

	public function afterClass():Void {}

	public function setup():Void {}

	public function teardown():Void {}

	public function testInjection():Void {
		var context = '/'.mockHttpContext();
		var controller:Controller = context.injector.instantiate( TopController );
		Assert.equals( context, controller.context );

		'/sub/testpostinject/'.mockHttpContext().testRoute( TopController ).assertSuccess().responseShouldBe( "true" );
	}

	public function testBaseUri():Void {
		'/baseurl/'.mockHttpContext().testRoute( TopController ).assertSuccess().responseShouldBe( "/" );
		'/sub/baseurl/'.mockHttpContext().testRoute( TopController ).assertSuccess().responseShouldBe( "/sub/" );
		'/sub/baseurl'.mockHttpContext().testRoute( TopController ).assertSuccess().responseShouldBe( "/sub/" );
		'/custom/jason/baseurl'.mockHttpContext().testRoute( TopController ).assertSuccess().responseShouldBe( "/custom/jason/" );
		'/custom/ufront/baseurl'.mockHttpContext().testRoute( TopController ).assertSuccess().responseShouldBe( "/custom/ufront/" );
	}
}

class TopController extends Controller {
	@:route('/sub/*') public var subController:SubController;

	@:route('/custom/$name/*') function custom( name:String, rest:Array<String> ) {
		return executeSubController( SubController );
	}

	@:route('/baseurl/') function testBaseUrl() {
		return this.baseUri;
	}
}

class SubController extends Controller {

	var postRanCorrectly = false;

	@post(1) public function runPost() {
		if ( context!=null )
			postRanCorrectly = true;
	}

	@:route('/baseurl/') function testBaseUrl() {
		return this.baseUri;
	}

	@:route('/testpostinject/') function testPostInject() {
		return this.postRanCorrectly;
	}
}
