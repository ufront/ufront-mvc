package ufront.core;

import tink.CoreApi;
/**
	`AcceptEither`, a way to accept either one type or another, without resorting to “Dynamic”, and still have the compiler type-check everything and make sure you correctly handle every situation.

	The abstract has implicit casts for both A and B, so you can easily receive either value.
	You can switch on `acceptEither.type` to extract the value depending on the type.

	Example:

	```
	function divideInHalf( in:AcceptEither<Int,String> ):Float {
		return switch in {
			case Left(i): i / 2;
			case Right(str): Std.parseFloat(str) / 2;
		}
	}
	```
**/
abstract AcceptEither<A,B> (Either<A,B>) {

	inline function new( e:Either<A,B> ) this = e;

	/** Get the value regardless of type. **/
	public var value(get,never):Dynamic;

	/** Return an enum to let you choose either option A or B **/
	public var type(get,never):Either<A,B>;

	inline function get_value() return switch this { case Left(v) | Right(v): v; }
	@:to inline function get_type() return this;
	@:from static function fromA( v:A ):AcceptEither<A,B> return new AcceptEither( Left(v) );
	@:from static function fromB( v:B ):AcceptEither<A,B> return new AcceptEither( Right(v) );
}
