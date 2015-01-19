package ufront.core;

import tink.CoreApi;

/**
	A `Futuristic` type could be in the future or it could already exist - it's either `T` or `Future<T>`.

	It's purpose is to allow your API can cleanly accept async or sync values.

	Example:

	```
	function setValue( val:Futuristic<String> ) {
	  val.handle( function(str) trace(str) );
	}
	setValue( "Jason" );
	setValue( Future.sync("Jason") );
	setValue( getSomeFuture() );
	```

	Some of the methods of `Future` are mirrored here, inline, for your convenience.  If you need the full Future API you can use `asFuture`, or cast to a `Future<T>`
**/
@:forward( handle, map, flatMap )
abstract Futuristic<T>( Future<T> ) from Future<T> to Future<T> {
	inline function new(f:Future<T>)
		this = f;

	@:from inline static function fromSync<T>( v:T ):Futuristic<T>
		return new Futuristic( Future.sync(v) );

	public inline function asFuture():Future<T>
		return this;
}
