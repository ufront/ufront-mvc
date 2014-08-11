package ufront.core;

import utest.Assert;
import ufront.core.AcceptEither;

class AcceptEitherTest {
	public function new() {}

	public function beforeClass():Void {}

	public function afterClass():Void {}

	public function setup():Void {}

	public function teardown():Void {}

	public function testLeftFromCast():Void {
		var val:AcceptEither<String,Int> = "Hello";
		switch val.type {
			case Left(str): Assert.equals( "Hello", str );
			default: Assert.fail( "Wrong type" );
		}
	}

	public function testRightFromCast():Void {
		var val:AcceptEither<String,Int> = 3;
		switch val.type {
			case Right(int): Assert.equals( 3, int );
			default: Assert.fail( "Wrong type" );
		}
	}

	public function testValue():Void {
		var v1:AcceptEither<String,Int> = 3;
		Assert.equals( 3, v1.value );
		var v1:AcceptEither<String,Int> = "Hello";
		Assert.equals( "Hello", v1.value );
	}
}
