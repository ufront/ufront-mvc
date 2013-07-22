package ufront.application;

import massive.munit.util.Timer;
import massive.munit.Assert;
import massive.munit.async.AsyncFactory;
import ufront.application.UfrontApplication;
import ufront.web.context.*;
import ufront.web.url.filter.*;
import ufront.module.*;
import ufront.web.Dispatch;
import haxe.web.Dispatch.DispatchConfig;
import ufront.web.UfrontConfiguration;
using ufront.mock.UfrontMocker;
using Lambda;

class UfrontApplicationTest 
{
	var context:HttpContext; 
	var instance:UfrontApplication; 
	var routes:TestController; 
	var configuration:UfrontConfiguration; 
	var dispatchConfig:DispatchConfig; 
	
	public function new() {}
	
	@BeforeClass
	public function beforeClass():Void {}

	@AfterClass
	public function afterClass():Void {}

	@Before
	public function setup():Void {
		routes = new TestController();
		dispatchConfig = Dispatch.make( routes );
		configuration = new UfrontConfiguration();
	}
	
	@After
	public function tearDown():Void {
		context = null;
		instance = null;
	}
	
	@Test
	public function testNewDefaultConfig():Void {

		// Setup UfrontApplication, default config
		context = "/".mockHttpContext();
		instance = new UfrontApplication( dispatchConfig, configuration );

		// Check the modules were initialised: 
		Assert.areEqual( 3, instance.modules.length );
		Assert.isTrue( checkModuleExists(DispatchModule) );
		Assert.isTrue( checkModuleExists(ErrorModule) );
		Assert.isTrue( checkModuleExists(TraceToBrowserModule) );

		// Check the URL filters were initialised:
		Assert.areEqual( 1, getNumUrlFilters() );
		Assert.isTrue( checkUrlFilterExists(PathInfoUrlFilter) );

	}
	
	@Test
	public function testNewBasePath():Void {

		// Setup UfrontApplication, but with custom base path
		context = "/home/".mockHttpContext();
		configuration = new UfrontConfiguration( false, "/home", null, false );
		instance = new UfrontApplication( dispatchConfig, configuration );

		// Check the URL filters were initialised:
		Assert.areEqual( 2, getNumUrlFilters() );
		Assert.isTrue( checkUrlFilterExists(DirectoryUrlFilter) );
		Assert.isTrue( checkUrlFilterExists(PathInfoUrlFilter) );
		
		// Check the BasePath filter is in there...
		Assert.fail( "Not checking base path yet" );

	}
	
	@Test
	public function testNewModRewrite():Void {

		// Setup UfrontApplication, but with mod rewrite enabled
		context = "/".mockHttpContext();
		configuration = new UfrontConfiguration( true, "/", null, false );
		instance = new UfrontApplication( dispatchConfig, configuration );

		// Check the URL filters were initialised:
		Assert.areEqual( 0, getNumUrlFilters() );
		
		// Check the PathInfo filter has been removed...
		Assert.fail( "Not checking base path yet" );

	}
	
	@Test
	public function testNewLogFile():Void {

		// Setup UfrontApplication
		context = "/".mockHttpContext();
		configuration = new UfrontConfiguration( false, "/", "traces.txt", false );
		instance = new UfrontApplication( dispatchConfig, configuration );

		// Check the modules were initialised: 
		Assert.areEqual( 4, instance.modules.length );
		Assert.isTrue( checkModuleExists(DispatchModule) );
		Assert.isTrue( checkModuleExists(ErrorModule) );
		Assert.isTrue( checkModuleExists(TraceToBrowserModule) );
		Assert.isTrue( checkModuleExists(TraceToFileModule) );

		// Check that the module is set up correctly
		Assert.fail("Not checking yet");
	}
	
	@Test
	public function testNewDisableBrowserTrace():Void {
		var oldTraceCalled = false;
		haxe.Log.trace = function (msg:Dynamic,?pos:haxe.PosInfos) oldTraceCalled = true;

		// Setup UfrontApplication
		context = "/".mockHttpContext();
		configuration = new UfrontConfiguration( false, "/", null, true );
		instance = new UfrontApplication( dispatchConfig, configuration );

		// Check the modules were initialised: 
		Assert.areEqual( 2, instance.modules.length );
		Assert.isTrue( checkModuleExists(DispatchModule) );
		Assert.isTrue( checkModuleExists(ErrorModule) );

		// Check that the old trace is restored
		trace ("Old trace works?");
		Assert.fail("Not checking yet");
	}
	
	@Test
	public function testNewDispatchModule():Void {

		// Setup UfrontApplication
		context = "/".mockHttpContext();
		instance = new UfrontApplication( dispatchConfig, configuration );

		// Check the modules were initialised: 
		Assert.areEqual( 4, instance.modules.length );
		Assert.isTrue( checkModuleExists(DispatchModule) );
		Assert.isTrue( checkModuleExists(ErrorModule) );
		Assert.isTrue( checkModuleExists(TraceToBrowserModule) );
		Assert.isTrue( checkModuleExists(TraceToFileModule) );

		// Assert that a result was returned
		Assert.areEqual( 200, context.response.status );
		Assert.areEqual( "Home", context.response.getBuffer() );
	}
	
	@Test
	public function testNewDispatchModuleDifferentUri():Void {

		// Setup UfrontApplication
		context = "/page/".mockHttpContext();
		instance = new UfrontApplication( dispatchConfig, configuration );

		// Assert that a result was returned
		Assert.areEqual( 200, context.response.status );
		Assert.areEqual( "Page", context.response.getBuffer() );
	}
	
	@Test
	public function testNewErrorModule():Void {
		// Use error function instead
		context = "/error/".mockHttpContext();
		instance = new UfrontApplication( dispatchConfig, configuration );
		instance.execute( context );

		Assert.fail("Tests not implemented yet");
	}
	
	@Test
	public function testNewCustomTrace():Void {
		Assert.fail("Tests not implemented yet");
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

	public function doError() {
		throw "Error";
	}
}