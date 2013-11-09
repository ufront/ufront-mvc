package ufront.module;

import massive.munit.Assert;
import ufront.application.HttpApplication;
import ufront.module.DispatchModule;
import ufront.web.result.*;
import ufront.web.Dispatch;
import haxe.web.Dispatch.DispatchConfig;
import ufront.web.context.HttpContext;
using ufront.test.TestUtils;
using mockatoo.Mockatoo;
using Types;

class DispatchModuleTest 
{
	var instance:DispatchModule; 
	var dispatchConfig:DispatchConfig;
	var controller:TestController;
	var httpApp:HttpApplication;
	var httpContext:HttpContext;
	
	public function new() 
	{}
	
	@BeforeClass
	public function beforeClass():Void
	{
	}
	
	@AfterClass
	public function afterClass():Void
	{
	}
	
	@Before
	public function setup():Void
	{
		var testController = new TestController();
		dispatchConfig = Dispatch.make( testController );
		instance = new DispatchModule( dispatchConfig );
		httpApp = new HttpApplication();
		httpContext = "/".mockHttpContext();
	}
	
	@After
	public function tearDown():Void
	{
	}
	
	@Test
	public function testNew():Void
	{
		Assert.areEqual( dispatchConfig, instance.dispatchConfig );
	}
	
	@Test 
	public function testInit():Void
	{
		Assert.isFalse( httpApp.onDispatch.has() );
		Assert.isFalse( httpApp.onActionExecute.has() );
		Assert.isFalse( httpApp.onActionExecute.has() );

		instance.init( httpApp );

		Assert.isTrue( httpApp.onDispatch.has() );
		Assert.isTrue( httpApp.onActionExecute.has() );
		Assert.isTrue( httpApp.onActionExecute.has() );
	}
	
	@Test
	public function testExecuteDispatchHandler():Void
	{
		instance.init( httpApp );

		// test URI/Parts, Params, Method on Dispatch object
		Assert.fail("Tests that params passed correctly to dispatch not implemented yet");

		// check action context (httpContext, controller, action, args) is correct
		// context.actionContext is set
		Assert.fail("Tests that dispatch sets controller, action, args, and actionContext correctly not implemented yet");
		
		// DENotFound
		// DEInvalidValue
		// DEMissing
		// DEMissingParam
		// DETooManyValues
		Assert.fail("Tests for Dispatch errors not implemented yet");
	}
	
	@Test
	public function testExecuteActionHandler():Void
	{
		// Mock actionContext (controller, action, args)
		// Test BadRequestError (if executeDispatchHandler not run...)
		// Test ActionResult is set
		// Test catch Redirect, re-fire events
		Assert.fail("Tests not implemented yet");
	}
	
	@Test
	public function testExecuteResultHandler():Void
	{
		// Mock an ActionResult, test it is executed correctly
		Assert.fail("Tests not implemented yet");
	}
	
	@Test
	public function createActionResultTest():Void
	{
		var r1 = DispatchModule.createActionResult(null);
		Assert.areEqual( EmptyResult, Type.getClass(r1) );
		
		var r2 = DispatchModule.createActionResult( "SomeString" );
		Assert.areEqual( ContentResult, Type.getClass(r2) );
		Assert.areEqual( "SomeString", r2.as(ContentResult).content );

		var r3 = DispatchModule.createActionResult( 34.5 );
		Assert.areEqual( ContentResult, Type.getClass(r3) );
		Assert.areEqual( "34.5", r3.as(ContentResult).content );

		var fileResult = new FilePathResult("funnycatpic.gif", "image/gif");
		var r3 = DispatchModule.createActionResult( fileResult );
		Assert.areEqual( FilePathResult, Type.getClass(r3) );
		Assert.areEqual( fileResult, r3 );
		Assert.areEqual( "image/gif", r3.as(FileResult).contentType );
	}
}

private class TestController
{
	public function new() {}
	public function doDefault() return "Default";
	public function doPage(name:String) return 'Page $name';
	public function doComment(name:String, commentID:Int) return 'Comment $commentID on page $name';
}