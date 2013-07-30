package ufront.web;

import haxe.web.Dispatch.DispatchConfig;
import massive.munit.util.Timer;
import massive.munit.Assert;
import massive.munit.async.AsyncFactory;
import ufront.web.Dispatch;
import haxe.web.Dispatch.DispatchError;
import haxe.web.Dispatch.Redirect;
import haxe.web.Dispatch.DispatchRule;
import haxe.web.Dispatch.MatchRule;

class DispatchTest 
{
	var instance:Dispatch; 
	
	public function new() 
	{
		
	}
	
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
	}
	
	@After
	public function tearDown():Void
	{
	}
	
	@Test
	public function constructor():Void
	{
		var noParams = new Map<String,String>();
		var params = [ "name"=>"Jason", "age"=>"25" ];

		var d1 = new Dispatch("/", noParams, "post");
		Assert.isNull( d1.controller );
		Assert.isNull( d1.action );
		Assert.isNull( d1.arguments );

		var d2 = new Dispatch("/", noParams, "post");
		Assert.areEqual( 1, d2.parts.length );
		Assert.areEqual( "", d2.parts[0] );
		Assert.areEqual( noParams, d2.params );
		Assert.areEqual( "post", d2.method );

		var d3 = new Dispatch("/some/parts", params, "GET");
		Assert.areEqual( 2, d3.parts.length );
		Assert.areEqual( "some", d3.parts[0] );
		Assert.areEqual( "parts", d3.parts[1] );
		Assert.areEqual( params, d3.params );
		Assert.areEqual( "get", d3.method ); // lowercase
	}

	@Test 
	public function returnDispatch() {
		// Simple test, essentially makeconfig, then runtimeReturnDispatch
		var d1 = new Dispatch( "/user/anna/23/", new Map<String,String>(), "post" );
		Assert.areEqual( "User anna is 23 years old", d1.returnDispatch(getAnonymousController()) );
	}

	@Test 
	public function processDispatchRequest() {

		var anonymousController = getAnonymousController();
		var testController1 = new TestController1();
		var testController2 = new TestController2();
		testController1.tc2 = testController2;

		var noParams = new Map<String,String>();

		var configs = [
			"anonymous" => Dispatch.make( anonymousController ),
			"test1" => Dispatch.make( testController1 ),
			"test2" => Dispatch.make( testController2 ),
		];

		var noParams = new Map<String,String>();
		var params = [ "name"=>"Jason", "age"=>"25" ];
		
		// resolve correct action (normal)
		var d1 = new Dispatch("/test/", noParams, "post");
		d1.processDispatchRequest( configs["anonymous"] );
		Assert.areEqual( anonymousController, d1.controller );
		Assert.areEqual( "doTest", d1.action );
		Assert.areEqual( 0, d1.arguments.length );

		// resolve correct action (default if no name)
		var d2 = new Dispatch("/", noParams, "post");
		d2.processDispatchRequest( configs["anonymous"] );
		Assert.areEqual( anonymousController, d2.controller );
		Assert.areEqual( "doDefault", d2.action );
		Assert.areEqual( 0, d2.arguments.length );

		// resolve correct action (default if name, but no match)
		var d3 = new Dispatch("/other/page/123", noParams, "post");
		d3.processDispatchRequest( configs["test1"] );
		Assert.areEqual( testController1, d3.controller );
		Assert.areEqual( "doDefault", d3.action );
		Assert.areEqual( 1, d3.arguments.length );
		Assert.areEqual( 3, d3.arguments[0].parts.length );
		Assert.areEqual( "other.page.123", d3.arguments[0].parts.join(".") );

		// resolve correct action (case insensitivity)
		var d4 = new Dispatch("/blOGposT/myPOSTisGOOD", noParams, "post");
		d4.processDispatchRequest( configs["test1"] );
		Assert.areEqual( testController1, d4.controller );
		Assert.areEqual( "doBlogPost", d4.action );
		Assert.areEqual( 1, d4.arguments.length );
		Assert.areEqual( "myPOSTisGOOD", d4.arguments[0] );

		// resolve correct action (with method)
		var d5 = new Dispatch("/add/1/2/", noParams, "post");
		var d6 = new Dispatch("/add/1/2/", noParams, "get");
		var d7 = new Dispatch("/add/1/2/", noParams, "other");
		d5.processDispatchRequest( configs["test2"] );
		d6.processDispatchRequest( configs["test2"] );
		d7.processDispatchRequest( configs["test2"] );
		Assert.areEqual( testController2, d5.controller );
		Assert.areEqual( testController2, d6.controller );
		Assert.areEqual( testController2, d7.controller );
		Assert.areEqual( "post_doAdd", d5.action );
		Assert.areEqual( "get_doAdd", d6.action );
		Assert.areEqual( "doAdd", d7.action );
		Assert.areEqual( 1, d5.arguments[0] );
		Assert.areEqual( 1, d6.arguments[0] );
		Assert.areEqual( 1, d7.arguments[0] );
		Assert.areEqual( 2, d5.arguments[1] );
		Assert.areEqual( 2, d6.arguments[1] );
		Assert.areEqual( 2, d7.arguments[1] );

		// throw DENotFound if no default and no match
		var d8 = new Dispatch("/notfound", noParams, "post");
		Assert.areEqual( DENotFound(null), catchProcessingError(d8, configs["test2"]) );
		
		// throw "TooManyValues"
		var d9 = new Dispatch("/page/2/someother/other/", noParams, "post");
		Assert.areEqual( DETooManyValues, catchProcessingError(d9, configs["test1"]) );
		
		// test subdispatch

		var d10 = new Dispatch("/calculator/add/5/7/", params, "post");
		d10.runtimeReturnDispatch( configs["test1"] );
		Assert.areEqual( testController2, d10.controller );
		Assert.areEqual( "post_doAdd", d10.action );
		Assert.areEqual( 2, d10.arguments.length );
		Assert.areEqual( 5, d10.arguments[0] );
		Assert.areEqual( 7, d10.arguments[1] );
		Assert.areEqual( params, d10.params );
		Assert.areEqual( "post", d10.method );
		
		// subdispatch parts
		var d11 = new Dispatch("/calculator/addall/1/2/4/8/16", params, "post");
		d11.runtimeReturnDispatch( configs["test1"] );
		Assert.areEqual( testController2, d11.controller );
		Assert.areEqual( "doAddAll", d11.action );
		Assert.areEqual( 1, d11.arguments.length );
		Assert.areEqual( 5, d11.parts.length );
	}

	@Test 
	public function executeDispatchRequest() {
		
		// Throw DEMissing if controller, action or args is null
		var d1 = new Dispatch("/", new Map<String,String>(), "get");
		d1.controller = getAnonymousController();
		d1.action = "doDefault";
		d1.arguments = null;
		Assert.areEqual( DEMissing, catchExecutionError(d1) );
		
		// Throw DEMissing if controller, action or args is null
		var d2 = new Dispatch("/", new Map<String,String>(), "get");
		d2.controller = getAnonymousController();
		d2.action = null;
		d2.arguments = [];
		Assert.areEqual( DEMissing, catchExecutionError(d2) );
		
		// Throw DEMissing if controller, action or args is null
		var d3 = new Dispatch("/", new Map<String,String>(), "get");
		d3.controller = null;
		d3.action = "doDefault";
		d3.arguments = [];
		Assert.areEqual( DEMissing, catchExecutionError(d3) );

		// call method and return (user, anonymous object, with args)
		var d4 = new Dispatch("/", new Map<String,String>(), "get");
		d4.controller = getAnonymousController();
		d4.action = "doUser";
		d4.arguments = ["Jason",25];
		Assert.areEqual( "User Jason is 25 years old", d4.executeDispatchRequest() );

		// call method and return (custom method, class based object, with args)
		var d5 = new Dispatch("/", new Map<String,String>(), "get");
		d5.controller = new TestController2();
		d5.action = "get_doAdd";
		d5.arguments = [1,1];
		Assert.areEqual( "GET 2", d5.executeDispatchRequest() );

		// catch redirect, do process/execute again
		var d6 = new Dispatch("/", new Map<String,String>(), "get");
		d6.controller = new BaseController();
		d6.action = "doRedirect";
		d6.arguments = [d6];
		try {
			d6.executeDispatchRequest();
			Assert.fail( "Redirect did not throw" );
		} catch ( e:Redirect ) {
			Assert.isTrue( Std.is(e,Redirect) );
		}
	}

	@Test 
	public function runtimeDispatch() {
		// This is just a copy for runtimeReturnDispatch(), so no need for individual tests.
	}

	@Test 
	public function runtimeReturnDispatch() {

		// Simple test, essentially process followed by execute

		var d1 = new Dispatch( "/user/jason/25/", new Map<String,String>(), "post" );
		var c1 = getAnonymousController();
		var dc1 = Dispatch.make( c1 );
		Assert.areEqual( "User jason is 25 years old", d1.runtimeReturnDispatch(dc1) );
		
		// Test redirects

		var d2 = new Dispatch( "/redirect/", new Map<String,String>(), "post" );
		var c2 = new TestController1();
		var dc2 = Dispatch.make( c2 );
		Assert.areEqual( "Show page 5", d2.runtimeReturnDispatch(dc2) );
	}

	@Test 
	public function run() {
		// Simple test: makeconfig, constructor, runtimeReturnDispatch, optional method
		var tc1 = new TestController1();
		var tc2 = new TestController2();
		tc1.tc2 = tc2;

		var params = new Map<String,String>();

		var result1 = Dispatch.run( "/calculator/addall/1/2/3/4", params, "get", tc1 );
		Assert.areEqual( "1 + 2 + 3 + 4 = 10", result1 );

		var result2 = Dispatch.run( "/calculator/add/1/2/", params, "get", tc1 );
		Assert.areEqual( "GET 3", result2 );

		var result3 = Dispatch.run( "/calculator/add/1/2/", params, "post", tc1 );
		Assert.areEqual( "POST 3", result3 );
	}

	@Test 
	public function make() {

		// getAnonymousController()
		var c1 = getAnonymousController();
		var dc1 = Dispatch.make( c1 );
		Assert.areEqual( dc1.obj, c1 );
		Assert.areEqual( 3, Reflect.fields(dc1.rules).length );
		Assert.isTrue( Reflect.hasField(dc1.rules,"doDefault") );
		Assert.isTrue( Reflect.hasField(dc1.rules,"doUser") );
		Assert.isTrue( Reflect.hasField(dc1.rules,"doTest") );
		Assert.areEqual( "DRMult", Type.enumConstructor(dc1.rules.doDefault) );
		switch ( dc1.rules.doDefault ) {
			case DRMult( arr ): Assert.areEqual( 0, arr.length );
			default: Assert.fail( "Incorrect type for dc1.rules.doDefault" );
		}
		switch ( dc1.rules.doTest ) {
			case DRMult( arr ): Assert.areEqual( 0, arr.length );
			default: Assert.fail( "Incorrect type for dc1.rules.doTest" );
		}
		switch ( dc1.rules.doUser ) {
			case DRMult( arr ): 
				Assert.areEqual( 2, arr.length );
				Assert.areEqual( MRString, arr[0] );
				Assert.areEqual( MRInt, arr[1] );
			default: Assert.fail( "Incorrect type for dc1.rules.doUser" );
		}

		// TestController1 (check "extends" works)
		var c2 = new TestController1();
		var dc2 = Dispatch.make( c2 );
		Assert.areEqual( dc2.obj, c2 );
		Assert.areEqual( 5, Reflect.fields(dc2.rules).length );
		Assert.isTrue( Reflect.hasField(dc2.rules,"doDefault") );
		Assert.isTrue( Reflect.hasField(dc2.rules,"doPage") );
		Assert.isTrue( Reflect.hasField(dc2.rules,"doRedirect") );
		Assert.isTrue( Reflect.hasField(dc2.rules,"doBlogPost") );
		Assert.isTrue( Reflect.hasField(dc2.rules,"doCalculator") );
		switch ( dc2.rules.doDefault ) {
			case DRMatch( MRDispatch ): 
			case _: Assert.fail( "Incorrect type for dc2.rules.doDefault" );
		}
		switch ( dc2.rules.doPage ) {
			case DRMatch( MRInt ): 
			case _: Assert.fail( "Incorrect type for dc2.rules.doPage" );
		}
		switch ( dc2.rules.doRedirect ) {
			case DRMatch( MRDispatch ): 
			case _: Assert.fail( "Incorrect type for dc2.rules.doRedirect" );
		}
		switch ( dc2.rules.doCalculator ) {
			case DRMatch( MRDispatch ): 
			case _: Assert.fail( "Incorrect type for dc2.rules.doRedirect" );
		}
		switch ( dc2.rules.doBlogPost ) {
			case DRMatch( MRString ): 
			case _: Assert.fail( "Incorrect type for dc2.rules.doPost" );
		}

		// TestController2 (check methods work)
		var c3 = new TestController2();
		var dc3 = Dispatch.make( c3 );
		Assert.areEqual( dc3.obj, c3 );
		Assert.areEqual( 4, Reflect.fields(dc3.rules).length );
		Assert.isTrue( Reflect.hasField(dc3.rules,"doAdd") );
		Assert.isTrue( Reflect.hasField(dc3.rules,"post_doAdd") );
		Assert.isTrue( Reflect.hasField(dc3.rules,"get_doAdd") );
		Assert.isTrue( Reflect.hasField(dc3.rules,"doAddAll") );
		switch ( dc3.rules.doAdd ) {
			case DRMult( arr ): 
				Assert.areEqual( 2, arr.length );
				Assert.areEqual( MRFloat, arr[0] );
				Assert.areEqual( MRFloat, arr[1] );
			default: Assert.fail( "Incorrect type for dc3.rules.doAdd" );
		}
		switch ( dc3.rules.get_doAdd ) {
			case DRMult( arr ): 
				Assert.areEqual( 2, arr.length );
				Assert.areEqual( MRFloat, arr[0] );
				Assert.areEqual( MRFloat, arr[1] );
			default: Assert.fail( "Incorrect type for dc3.rules.get_doAdd" );
		}
		switch ( dc3.rules.post_doAdd ) {
			case DRMult( arr ): 
				Assert.areEqual( 2, arr.length );
				Assert.areEqual( MRFloat, arr[0] );
				Assert.areEqual( MRFloat, arr[1] );
			default: Assert.fail( "Incorrect type for dc3.rules.post_doAdd" );
		}
		switch ( dc3.rules.doAddAll ) {
			case DRMatch( MRDispatch ): 
			default: Assert.fail( "Incorrect type for dc3.rules.post_doAdd" );
		}

	}

	function getAnonymousController() {
		return { 
			doDefault : function() return "Welcome",
			doTest : function() return "Test",
			doUser : function(username:String, age:Int) return 'User $username is $age years old'
		};
	}

	function catchProcessingError( d:Dispatch, cfg:DispatchConfig, ?pos:haxe.PosInfos ):Dynamic {
		try {
			d.processDispatchRequest( cfg );
			Assert.fail( "Expected dispatch processing to fail, but it did not", pos );
			return null;
		} catch (e:Dynamic) return e;
	}

	function catchExecutionError( d:Dispatch, ?pos:haxe.PosInfos ):Dynamic {
		try {
			d.executeDispatchRequest();
			Assert.fail( "Expected dispatch execution to fail, but it did not", pos );
			return null;
		} catch (e:Dynamic) return e;
	}
}

private class BaseController
{
	public function new() {}
	public function doDefault( d:Dispatch ) return "Default: " + d.parts.join("-");
	public function doPage( num:Int ) return 'Show page $num';
	public function doRedirect( d:Dispatch ) d.redirect("/page/5/");
}

private class TestController1 extends BaseController
{
	public function doBlogPost( name:String ) return 'Show blog post $name';

	public var tc2:TestController2;
	public function doCalculator( d:Dispatch ) {
		return d.returnDispatch( tc2 );
	}

	public function toString() return "TestController1";
}

private class TestController2
{
	public function new() {}
	public function toString() return "TestController2";

	public function doAdd( a:Float, b:Float ) return '$a + $b = ${a+b}';
	public function get_doAdd( a:Float, b:Float ) return 'GET ${a+b}';
	public function post_doAdd( a:Float, b:Float ) return 'POST ${a+b}';
	public function doAddAll( d:Dispatch ) {
		if ( d.parts.length==0 ) 
			return "Nothing to add up.";
		var total:Float = 0;
		for ( p in d.parts ) 
			total += Std.parseFloat(p);
		return '${d.parts.join(" + ")} = $total';
	}
}