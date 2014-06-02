package ufront.core;

import massive.munit.util.Timer;
import massive.munit.Assert;
import massive.munit.async.AsyncFactory;
import ufront.core.Futuroid;
import tink.CoreApi;
import mockatoo.Mockatoo.*;
using mockatoo.Mockatoo;

class FuturoidTest 
{
    public var trigger:FutureTrigger<Int>;
    public var future:Future<Int>;
    
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
		trigger = Future.trigger();
		future = trigger.asFuture();
	}
	
	@After
	public function tearDown():Void
	{
	}
	
	@Test
	public function testFromFuture():Void
	{
		var futuroid:Futuroid<Int> = future;
		Assert.areEqual( future, futuroid );
	}
	
	@Test
	public function testFromSync():Void
	{
		var futuroid:Futuroid<Int> = 10;
		var value:Int;
		futuroid.handle( function(i:Int) {
			value = i;
		});
		Assert.areEqual( 10, value );
	}
	
	@Test
	public function testForwarding():Void
	{
		var handledValue:Int;
		var mappedValue:String;
		var flatMappedValue:Float;
		var futuroid:Futuroid<Int> = future;
		futuroid.handle( function(i) handledValue = i);
		futuroid.map( function(i) return 'number $i' ).handle( function(i) mappedValue = i);
		futuroid.flatMap( function(i) return Future.sync(i+0.1) ).handle( function(i) flatMappedValue = i);
		trigger.trigger( 10 );
		Assert.areEqual( 10, handledValue );
		Assert.areEqual( 'number 10', mappedValue );
		Assert.areEqual( 10.1, flatMappedValue );
	}
}