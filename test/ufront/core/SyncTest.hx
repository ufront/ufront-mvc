package ufront.core;

import utest.Assert;
import ufront.core.Sync;
import tink.CoreApi;

class SyncTest 
{
	public function new() 
	{
		
	}
	
	public function beforeClass():Void {}
	
	public function afterClass():Void {}
	
	public function setup():Void {}
	
	public function teardown():Void {}
	
	public function testSyncOf():Void {
		var f = Sync.of('Hello');
		var val:String;
		f.handle( function(str) val = str );
		Assert.equals( "Hello", val );
	}
	
	public function testSyncSuccess():Void {
		var f = Sync.success();
		var val;
		f.handle( function(v) val = v );
		Assert.isTrue( val.match(Success(Noise)) );
	}
	
	public function testSyncHttpError():Void {
		var f = Sync.httpError( "Message", ["error"] );
		var val;
		f.handle( function(v) val = v );
		switch val {
			case Failure(httpError):
				Assert.equals( '500 Error: Message', httpError.toString() );
				Assert.equals( "error", httpError.data[0] );
			default: Assert.fail('Expected a failure');
		}
	}
}