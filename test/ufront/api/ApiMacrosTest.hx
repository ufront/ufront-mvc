package ufront.api;

import ufront.api.UFApi;
import utest.Assert;
import haxe.rtti.Meta;
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
		function hasMeta( fieldName:String, metaName:String ) {
			var field = Reflect.field( meta, fieldName );
			if ( field==null ) 
				return false;
			return Reflect.hasField( field, metaName );
		}
		Assert.isTrue ( hasMeta("returnVoidFn","returnVoid") );
		Assert.isFalse( hasMeta("returnVoidFn","returnOutcome") );
		Assert.isFalse( hasMeta("returnVoidFn","returnFuture") );
		
		Assert.isFalse( hasMeta("returnStringFn","returnVoid") );
		Assert.isFalse( hasMeta("returnStringFn","returnOutcome") );
		Assert.isFalse( hasMeta("returnStringFn","returnFuture") );
		
		Assert.isFalse( hasMeta("returnOutcomeFn","returnVoid") );
		Assert.isTrue ( hasMeta("returnOutcomeFn","returnOutcome") );
		Assert.isFalse( hasMeta("returnOutcomeFn","returnFuture") );
		
		Assert.isFalse( hasMeta("returnFutureFn","returnVoid") );
		Assert.isFalse( hasMeta("returnFutureFn","returnOutcome") );
		Assert.isTrue ( hasMeta("returnFutureFn","returnFuture") );
		
		Assert.isFalse( hasMeta("returnSurpriseFn","returnVoid") );
		Assert.isTrue ( hasMeta("returnSurpriseFn","returnOutcome") );
		Assert.isTrue ( hasMeta("returnSurpriseFn","returnFuture") );
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