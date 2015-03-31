package ufront.api;

import ufront.api.UFApi;
import ufront.remoting.RemotingError;
import utest.Assert;
import haxe.rtti.Meta;
import haxe.EnumFlags;
import haxe.macro.MacroType;
using tink.CoreApi;

class ApiMacrosTest {
	public function new() {}

	public function beforeClass():Void {}

	public function afterClass():Void {}

	public function setup():Void {}

	public function teardown():Void {}

	public function testRemoveClientBodies() {
		var api = new ApiTest1();
		var result = api.doSysStuff();
		var myArr = [];
		api.addToArray( myArr );

		#if server
			Assert.notNull( api.doSysStuff() );
			Assert.equals( 1, myArr.length );
			Assert.equals( "New Test", api.name );
		#elseif client
			Assert.isNull( api.doSysStuff() );
			Assert.equals( 0, myArr.length );
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

	var asyncApi1:ApiTest1Async;
	var asyncApi2:ApiTest2Async;
	public function testAsyncClassExists() {
		var api1 = new ApiTest1();
		asyncApi1 = new ApiTest1Async();
		asyncApi2 = new ApiTest2Async();

		// Check classes can be used as values
		Assert.isTrue( Std.is(asyncApi1,ApiTest1Async) );
		Assert.isTrue( Std.is(asyncApi2,ApiTest2Async) );
		// Check interfaces
		Assert.isTrue( Std.is(api1,MyApiInterface) );
		Assert.isTrue( Std.is(asyncApi1,MyApiInterfaceAsync) );

		// Notes:
		// Here I'm not testing much, other than that it compiles.
		// Setting up appropriate testing will require a fair bit of conditional compilation between client and server.
		// It's probably better suited to some BDD style integration tests.
	}
}

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

class ApiTest2 extends UFApi {
	public function returnVoidFn():Void {}
	public function returnStringFn():String return "Hey";
	public function returnOutcomeFn(success:Bool):Outcome<String,Int> return success ? Success("Great Success") : Failure(-1);
	public function returnFutureFn():Future<Int> return new FutureTrigger<Int>().asFuture();
	public function returnSurpriseFn():Surprise<Int,String> return new FutureTrigger<Outcome<Int,String>>().asFuture();
}
class ApiTest2Async extends UFAsyncApi<ApiTest2> {}

interface MyApiInterface {
	function doSysStuff():String;
}
interface MyApiInterfaceAsync {
	function doSysStuff():Surprise<String,RemotingError<Noise>>;
}
