package ufront.application;

import massive.munit.util.Timer;
import massive.munit.Assert;
import massive.munit.async.AsyncFactory;
import ufront.application.UfrontApplication;
import ufront.web.context.*;
import ufront.web.url.filter.*;
import ufront.module.*;
import ufront.log.*;
import ufront.web.result.*;
import ufront.web.Dispatch;
import haxe.web.Dispatch.DispatchConfig;
import ufront.web.UfrontConfiguration;
using ufront.test.TestUtils;
using Lambda;

class UfrontApplicationTest 
{
	var context:HttpContext; 
	var instance:UfrontApplication; 
	var testController:TestController; 
	var configuration:UfrontConfiguration; 
	var dispatchConfig:DispatchConfig; 
	
	public function new() {}
	
	@BeforeClass
	public function beforeClass():Void {}

	@AfterClass
	public function afterClass():Void {}

	@Before
	public function setup():Void {
		testController = new TestController();
		dispatchConfig = Dispatch.make( testController );
	}
	
	@After
	public function tearDown():Void {
		context = null;
		instance = null;
	}
	
	@Test
	public function testNewDefaultConfig():Void {

		// Setup UfrontApplication, default config
		instance = new UfrontApplication({
			dispatchConf: dispatchConfig
		});

		// Check the modules were initialised: 
		Assert.areEqual( 3, instance.modules.length );
		Assert.isTrue( checkModuleExists(DispatchModule) );
		Assert.isTrue( checkModuleExists(ErrorModule) );
		Assert.isTrue( checkModuleExists(BrowserConsoleLogger) );

		// Check the URL filters were initialised:
		Assert.areEqual( 1, getNumUrlFilters() );
		Assert.isTrue( checkUrlFilterExists(PathInfoUrlFilter) );

		context = "/index.n/somepage/".mockHttpContext();
		instance.execute(context);
		
		// Check the BasePath filter is in there...
		Assert.areEqual( "/", context.getRequestUri() );
		Assert.areEqual( "/otherpage.html", context.generateUri("/otherpage.html") );
	}
	
	@Test
	public function testNewBasePath():Void {

		// Setup UfrontApplication, but with custom base path
		context = "/home/todo/index.html".mockHttpContext();
		instance = new UfrontApplication({
			dispatchConf: dispatchConfig,
			basePath: "/home",
			urlRewrite: true
		});
		instance.execute( context );

		// Check the URL filters were initialised:
		Assert.areEqual( 2, getNumUrlFilters() );
		Assert.isTrue( checkUrlFilterExists(DirectoryUrlFilter) );
		Assert.isTrue( checkUrlFilterExists(PathInfoUrlFilter) );
		
		// Check the BasePath filter is in there...
		Assert.areEqual( "/todo/index.html", context.getRequestUri() );
		Assert.areEqual( "/home/index.n/index.html", context.generateUri("/index.html") );
	}
	
	@Test
	public function testNewModRewrite():Void {

		// Setup UfrontApplication, but with mod rewrite enabled
		context = "/somepage/".mockHttpContext();
		instance = new UfrontApplication({
			urlRewrite: false
		});
		instance.execute( context );

		// Check the URL filters were initialised:
		Assert.areEqual( 0, getNumUrlFilters() );
		
		// Check the PathInfo filter has been removed...
		
		// Check the BasePath filter is in there...
		Assert.areEqual( "index.n/somepage/", context.getRequestUri() );
		Assert.areEqual( "index.n/somepage.html", context.generateUri("/somepage.html") );

	}
	
	@Test
	public function testNewLogFile():Void {

		// Setup UfrontApplication
		context = "/".mockHttpContext();
		instance = new UfrontApplication({
			dispatchConf: dispatchConfig,
			urlRewrite: false,
			logFile: "traces.txt",
			basePath: "/"
		});

		// Check the modules were initialised: 
		Assert.areEqual( 5, instance.modules.length );
		Assert.isTrue( checkModuleExists(DispatchModule) );
		Assert.isTrue( checkModuleExists(ErrorModule) );
		Assert.isTrue( checkModuleExists(BrowserConsoleLogger) );
		Assert.isTrue( checkModuleExists(FileLogger) );
	}
	
	@Test
	public function testNewDisableBrowserTrace():Void {
		var oldTraceCalled = false;
		haxe.Log.trace = function (msg:Dynamic,?pos:haxe.PosInfos) oldTraceCalled = true;

		// Setup UfrontApplication
		context = "/empty/".mockHttpContext();
		instance = new UfrontApplication({
			dispatchConf: dispatchConfig, 
			disableBrowserTrace: true,
			urlRewrite: false,
			basePath: "/"
		});

		// Check the modules were initialised: 
		Assert.areEqual( 2, instance.modules.length );
		Assert.isTrue( checkModuleExists(DispatchModule) );
		Assert.isTrue( checkModuleExists(ErrorModule) );

		instance.execute( context );

		// Check that the old trace is restored
		trace ("Old trace works?");
		Assert.isTrue( oldTraceCalled );
	}
	
	@Test
	public function testExecute():Void {

		// Setup UfrontApplication
		instance = new UfrontApplication({
			dispatchConf: dispatchConfig
		});
		instance.initModules();
		instance.onApplicationError.clear();

		// Check the modules were initialised: 
		Assert.areEqual( 3, instance.modules.length );
		Assert.isTrue( checkModuleExists(DispatchModule) );
		Assert.isTrue( checkModuleExists(ErrorModule) );
		Assert.isTrue( checkModuleExists(BrowserConsoleLogger) );

		var context1 = "/".mockHttpContext();
		instance.execute( context1 );

		// Assert that a result was returned
		Assert.areEqual( testController, context1.actionContext.controller );
		Assert.areEqual( "doDefault", context1.actionContext.action );
		Assert.isTrue( Std.is(context1.actionResult,ContentResult) );
		Assert.areEqual( "Home", context1.response.getBuffer() );
		Assert.areEqual( 200, context1.response.status );

		var context2= "/page/".mockHttpContext();
		instance.execute( context2 );

		// Assert that a result was returned
		Assert.areEqual( testController, context2.actionContext.controller );
		Assert.areEqual( "doPage", context2.actionContext.action );
		Assert.isTrue( Std.is(context2.actionResult,ContentResult) );
		Assert.areEqual( "Page", context2.response.getBuffer() );
		Assert.areEqual( 200, context2.response.status );
	}
	
	@Test
	public function testNewErrorModule():Void {
		// Use error function instead
		context = "/error/".mockHttpContext();
		instance = new UfrontApplication({
			dispatchConf: dispatchConfig
		});
		instance.execute( context );

		// Assert that a result was returned
		Assert.areEqual( 500, context.response.status );
		Assert.isTrue( context.response.getBuffer().indexOf("<p>some error...</p>")>-1 );
	}
	
	@Test
	public function testNewCustomTrace():Void {
		// Setup UfrontApplication
		var traces = [];
		instance = new UfrontApplication({
			dispatchConf: dispatchConfig,
			basePath: "/",
			disableBrowserTrace: true,
			urlRewrite: false
		});
		instance.addModule( new CustomTrace( traces ) );

		// Check the modules were initialised: 
		Assert.areEqual( 3, instance.modules.length );
		Assert.isTrue( checkModuleExists(DispatchModule) );
		Assert.isTrue( checkModuleExists(ErrorModule) );
		Assert.isTrue( checkModuleExists(CustomTrace) );

		context = "/traces/".mockHttpContext();
		instance.execute( context );

		// Check the custom trace ran okay...
		Assert.areEqual( "One,Two,Three", traces.join(",") );
	}

	function checkModuleExists( type:Class<IHttpModule> ) {
		return instance.modules.exists( function (module) return Std.is(module,type) );
	}

	function checkUrlFilterExists( type:Class<IUrlFilter> ) {
		return instance.urlFilters.exists( function (filter) return Std.is(filter,type) );
	}

	function getNumUrlFilters() return instance.urlFilters.length;
}

private class TestController
{
	public function new() {}

	public function doDefault() {
		return "Home";
	}

	public function doPage() {
		return "Page";
	}

	public function doEmpty() {
		return "";
	}

	public function doTraces() {
		trace ("One");
		trace ("Two");
		trace ("Three");
		return "";
	}

	public function doError() {
		throw "some error...";
	}
}

private class CustomTrace implements IHttpModule
{
	public var arr:Array<String>;
	public function new( arr:Array<String> ) this.arr = arr;
	public function trace(msg:Dynamic, ?pos:haxe.PosInfos):Void arr.push( Std.string(msg) );
	public function init( application:HttpApplication ):Void {}
	public function dispose():Void {}
}