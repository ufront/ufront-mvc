package ufront.core;

import tink.CoreApi;

/**
	A type that can accept either `T` or `Future<T>`, so your API can cleanly accept async or sync values.

	Example:

	```
	function setValue( val:Futuroid<String> ) {
	  val.handle( function(str) trace(str) );
	}
	setValue( "Jason" );
	setValue( Future.sync("Jason") );
	setValue( getSomeFuture() );
	```

	Some of the methods of `Future` are mirrored here, inline, for your convenience.  If you need the full Future API you can use `asFuture`, or auto-cast to a `Future<T>`
**/
abstract Futuroid<T>( Future<T> ) from Future<T> to Future<T> {
	inline function new(f:Future<T>)
		this = f;

	@:from inline static function fromSync( v:T )
		return new Futuroid( Future.sync(v) );

	public inline function asFuture():Future<T>
		return this;

	public inline function handle(cb)
		return this.handle( cb );

	public inline function map(cb)
		return this.map( cb );

	public inline function flatMap(cb)
		return this.flatMap( cb );
}
