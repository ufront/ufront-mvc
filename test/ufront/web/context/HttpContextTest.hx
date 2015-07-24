package ufront.web.context;

import utest.Assert;
import ufront.MVC;
using ufront.test.TestUtils;

class HttpContextTest {
	var instance:HttpContext;

	public function new() {}

	public function beforeClass():Void {}

	public function afterClass():Void {}

	public function setup():Void {}

	public function teardown():Void {}

	public function testSingletonInjection():Void {
		// We want to make sure that each HttpContext has a different auth and session, but that those are used as singletons within that request.
		// We'll also test that the implementation is injected.

		var appInjector = new minject.Injector();
		appInjector.map( UFHttpSession ).toClass( TestSession );
		appInjector.map( UFAuthHandler ).toClass( NobodyAuthHandler );

		var context1 = '/sameSession/'.mockHttpContext( appInjector );
		var context2 = '/sameSession/'.mockHttpContext( appInjector );
		Assert.notEquals( context1.session, context2.session );
		Assert.notEquals( context1.session.id, context2.session.id );
		context1.testRoute( SingletonInjectionController ).assertSuccess().responseShouldBe( "true" ).finishTest();
		context2.testRoute( SingletonInjectionController ).assertSuccess().responseShouldBe( "true" ).finishTest();


		var context3 = '/sameAuth/'.mockHttpContext( appInjector );
		var context4 = '/sameAuth/'.mockHttpContext( appInjector );
		Assert.notEquals( context3.auth, context4.auth );
		context3.testRoute( SingletonInjectionController ).assertSuccess().responseShouldBe( "true" ).finishTest();
		context4.testRoute( SingletonInjectionController ).assertSuccess().responseShouldBe( "true" ).finishTest();
	}
}

class SingletonInjectionController extends Controller {
	@inject public var session:UFHttpSession;
	@inject public var testSession:TestSession;
	@inject public var auth:UFAuthHandler;
	@inject public var nobodyAuth:NobodyAuthHandler;

	@:route("/sameSession")
	public function sameSession() {
		return
			session == testSession
			&& session == context.session
			&& Std.is( context.injector.findMappingForType("ufront.web.session.UFHttpSession",null).provider, minject.provider.ValueProvider )
			;
	}

	@:route("/sameAuth")
	public function sameAuth() {
		return
			auth == context.auth
			&& auth == nobodyAuth
			&& Std.is( context.injector.findMappingForType("ufront.auth.UFAuthHandler",null).provider, minject.provider.ValueProvider )
			;
	}
}
