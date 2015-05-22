package ufront.core;

import utest.Assert;
import ufront.core.Futuristic;
import tink.CoreApi;
import mockatoo.Mockatoo.*;
using mockatoo.Mockatoo;

class FuturisticTest {
    public var trigger:FutureTrigger<Int>;
    public var future:Future<Int>;

	public function new() {}

	public function beforeClass():Void {}

	public function afterClass():Void {}

	public function setup():Void {
		trigger = Future.trigger();
		future = trigger.asFuture();
	}

	public function teardown():Void {}

	public function testFromFuture():Void {
		var futuroid:Futuristic<Int> = future;
		Assert.equals( future, futuroid );
	}

	public function testFromSync():Void {
		var futuroid:Futuristic<Int> = 10;
		var value:Int;
		futuroid.handle( function(i:Int) {
			value = i;
		});
		Assert.equals( 10, value );
	}

	public function testForwarding():Void {
		var handledValue:Int;
		var mappedValue:String;
		var flatMappedValue:Float;
		var futuroid:Futuristic<Int> = future;
		futuroid.handle( function(i) handledValue = i);
		futuroid.map( function(i) return 'number $i' ).handle( function(i) mappedValue = i);
		futuroid.flatMap( function(i) return Future.sync(i+0.1) ).handle( function(i) flatMappedValue = i);
		trigger.trigger( 10 );
		Assert.equals( 10, handledValue );
		Assert.equals( 'number 10', mappedValue );
		Assert.equals( 10.1, flatMappedValue );
	}
}
