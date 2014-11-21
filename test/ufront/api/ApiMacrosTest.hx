package ufront.api;

import ufront.api.UFApi;
import utest.Assert;
import haxe.rtti.Meta;
import haxe.EnumFlags;
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
}

class ApiTest1 extends UFApi {
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

class ApiTest2 extends UFApi {
	public function returnVoidFn():Void {}
	public function returnStringFn():String return "Hey";
	public function returnOutcomeFn(success:Bool):Outcome<String,Int> return success ? Success("Great Success") : Failure(-1);
	public function returnFutureFn():Future<Int> return new FutureTrigger<Int>().asFuture();
	public function returnSurpriseFn():Surprise<Int,String> return new FutureTrigger<Outcome<Int,String>>().asFuture();
}