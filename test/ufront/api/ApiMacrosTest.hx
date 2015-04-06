package ufront.api;

import ufront.api.*;
import ufront.remoting.RemotingError;
import utest.Assert;
import haxe.rtti.Meta;
import haxe.EnumFlags;
import haxe.macro.MacroType;
import mockatoo.Mockatoo.*;
using tink.CoreApi;
using mockatoo.Mockatoo;

class ApiMacrosTest {
	public function new() {}

	public function beforeClass():Void {}

	public function afterClass():Void {}

	public function setup():Void {}

	public function teardown():Void {}

	public function testClientTransformation() {
		var api = new ApiTest1();
		var myArr = [];

		#if server
			var result = api.doSysStuff();
			api.addToArray( myArr );
			Assert.notNull( api.doSysStuff() );
			Assert.equals( 1, myArr.length );
			Assert.equals( "New Test", api.name );
		#elseif client
			var mockConnection = mock( haxe.remoting.HttpConnection );
			mockConnection.resolve( cast anyString ).returns( mockConnection );
			api.cnx = mockConnection;
			api.addToArray( myArr );

			mockConnection.resolve( "ufront.api.ApiTest1" ).verify( 1 );
			mockConnection.resolve( "addToArray" ).verify( 1 );
			mockConnection.call(cast any).verify( 1 );

			mockConnection.call(cast any).returns( "fake cwd" );
			var result = api.doSysStuff();
			// TODO: I believe ".verify()" resets the count after it is called.
			// I need to double check this, because .resolve("ufront.api.ApiTest1") is called twice, so if I'm wrong these tests are wrong.
			mockConnection.resolve( "ufront.api.ApiTest1" ).verify( 1 );
			mockConnection.resolve( "doSysStuff" ).verify( 1 );
			Assert.equals( "fake cwd", api.doSysStuff() );

			// Check that a variable was stripped out on the client. Only public API methods should remain.
			Assert.isFalse( Reflect.hasField(api,"name") );
		#end
	}

	public function testAddReturnTypeMetadata() {
		var meta = Meta.getFields( ApiTest2 );
		function hasReturnType( fieldName:String, rt:ApiReturnType ) {
			var field = Reflect.field( meta, fieldName );
			if ( field==null )
				return false;
			var rtMeta:Array<Int> = Reflect.field(field,"returnType");
			var rtInt = rtMeta[0];
			var flags:EnumFlags<ApiReturnType> = EnumFlags.ofInt( rtInt );
			return flags.has( rt );
		}
		Assert.isTrue ( hasReturnType("returnVoidFn",ARTVoid) );
		Assert.isFalse( hasReturnType("returnVoidFn",ARTOutcome) );
		Assert.isFalse( hasReturnType("returnVoidFn",ARTFuture) );

		Assert.isFalse( hasReturnType("returnStringFn",ARTVoid) );
		Assert.isFalse( hasReturnType("returnStringFn",ARTOutcome) );
		Assert.isFalse( hasReturnType("returnStringFn",ARTFuture) );

		Assert.isFalse( hasReturnType("returnOutcomeFn",ARTVoid) );
		Assert.isTrue ( hasReturnType("returnOutcomeFn",ARTOutcome) );
		Assert.isFalse( hasReturnType("returnOutcomeFn",ARTFuture) );

		Assert.isFalse( hasReturnType("returnFutureFn",ARTVoid) );
		Assert.isFalse( hasReturnType("returnFutureFn",ARTOutcome) );
		Assert.isTrue ( hasReturnType("returnFutureFn",ARTFuture) );

		Assert.isFalse( hasReturnType("returnSurpriseFn",ARTVoid) );
		Assert.isTrue ( hasReturnType("returnSurpriseFn",ARTOutcome) );
		Assert.isTrue ( hasReturnType("returnSurpriseFn",ARTFuture) );
	}

	public function testAsyncProxies() {
		var api1 = new ApiTest1();
		var asyncApi1 = new ApiTest1Async();
		var asyncApi2 = new ApiTest2Async();

		// Check classes can be used as values
		Assert.isTrue( Std.is(asyncApi1,ApiTest1Async) );
		Assert.isTrue( Std.is(asyncApi2,ApiTest2Async) );
		// Check interfaces
		Assert.isTrue( Std.is(api1,MyApiInterface) );
		Assert.isTrue( Std.is(asyncApi1,MyApiInterfaceAsync) );
		// Check the `getAsyncApi` functionality.
		var result = UFAsyncApi.getAsyncApi( ApiTest1 );
		Assert.equals( "ufront.api.ApiTest1Async", Type.getClassName(result) );

		// TODO: Create more tests using a mock `haxe.remoting.AsyncConnection`.
	}

	public function testCallbackProxies() {
		var cnx = null;
		var api1 = new ApiTest1();
		var cbApi = new ApiTest1Callback( #if client cnx #end );
		var clientContext = new MyApiClient( "/" );

		// Check classes can be used as values
		Assert.isTrue( Std.is(cbApi,ApiTest1Callback) );
		Assert.isTrue( Std.is(clientContext.test1,ApiTest1Proxy) );
		Assert.isTrue( Std.is(clientContext.test2,ApiTest2Proxy) );
		// Check interfaces
		Assert.isTrue( Std.is(api1,MyApiInterface) );
		Assert.isTrue( Std.is(cbApi,MyApiInterfaceCallback) );
		// Check the `getAsyncApi` functionality.
		var result = UFCallbackApi.getCallbackApi( ApiTest2 );
		Assert.equals( "ufront.api.ApiTest2Proxy", Type.getClassName(result) );

		// TODO: Create more tests using a mock `haxe.remoting.AsyncConnection`.
	}
}

//
// Test API 1
//
class ApiTest1 extends UFApi implements MyApiInterface {
	public var name:String = "Test";
	public function new() {
		super();
		name = "New "+name;
		Sys.getCwd();
	}
	public function doSysStuff():String {
		return Sys.getCwd();
	}
	public function addToArray( arr:Array<Int> ):Void {
		arr.push( 1 );
	}
}
class ApiTest1Async extends UFAsyncApi<ApiTest1> implements MyApiInterfaceAsync {}
class ApiTest1Callback extends UFCallbackApi<ApiTest1> implements MyApiInterfaceCallback {}
interface MyApiInterface {
	function doSysStuff():String;
}
interface MyApiInterfaceAsync {
	function doSysStuff():Surprise<String,RemotingError<Noise>>;
}
interface MyApiInterfaceCallback {
	function doSysStuff( onResult:Callback<String>, ?onError:Callback<RemotingError<Noise>> ):Void;
}

//
// Test API 2
//
class ApiTest2 extends UFApi {
	public function returnVoidFn():Void {}
	public function returnStringFn():String return "Hey";
	public function returnOutcomeFn(success:Bool):Outcome<String,Int> return success ? Success("Great Success") : Failure(-1);
	public function returnFutureFn():Future<Int> return new FutureTrigger<Int>().asFuture();
	public function returnSurpriseFn():Surprise<Int,String> return new FutureTrigger<Outcome<Int,String>>().asFuture();
}
class ApiTest2Async extends UFAsyncApi<ApiTest2> {}

//
// Contexts
//
class MyApi extends UFApiContext {
	var test1:ApiTest1;
	var test2:ApiTest2;
}
class MyApiClient extends UFApiClientContext<MyApi> {}
