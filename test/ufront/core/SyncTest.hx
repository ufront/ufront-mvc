package ufront.core;

import massive.munit.util.Timer;
import massive.munit.Assert;
import massive.munit.async.AsyncFactory;
import ufront.core.Sync;
import tink.CoreApi;

class SyncTest 
{
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
	public function testSyncOf():Void
	{
		var f = Sync.of('Hello');
		var val:String;
		f.handle( function(str) val = str );
		Assert.areEqual( "Hello", val );
	}
	
	@Test
	public function testSyncSuccess():Void
	{
		var f = Sync.success();
		var val;
		f.handle( function(v) val = v );
		Assert.isTrue( val.match(Success(Noise)) );
	}
	
	@Test
	public function testSyncHttpError():Void
	{
		var f = Sync.httpError( "Message", ["error"] );
		var val;
		f.handle( function(v) val = v );
		switch val {
			case Failure(httpError):
				Assert.areEqual( '500 Error: Message', httpError.toString() );
				Assert.areEqual( "error", httpError.data[0] );
			default: Assert.fail('Expected a failure');
		}
	}
}