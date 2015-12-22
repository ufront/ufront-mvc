package ufront.core;

import haxe.ds.StringMap;
using StringTools;

/**
This is almost identical to MultiValueMap, except that it will treat all keys as case insensitive.

Please note none of the usual `@:from` casts are available here: you must create a new Map with `new CaseInsensitiveMultiValueMap()`.
**/
@:forward(keys,iterator,allValues,toString)
abstract CaseInsensitiveMultiValueMap<T>( MultiValueMap<T> ) to MultiValueMap<T> {
	public inline function new() this = new MultiValueMap();
	public inline function exists( name:String ) return this.exists( name.toLowerCase() );
	public inline function getAll( name:String ):Array<T> return this.getAll( name.toLowerCase() );
	@:arrayAccess public inline function get( name:String ):Null<T> return this.get( name.toLowerCase() );
	@:arrayAccess public inline function set( name:String, value:T ) this.set( name.toLowerCase(), value );
	public inline function add( name:String, value:T ) this.add( name.toLowerCase(), value );
	public inline function remove( key:String ) return this.remove( key.toLowerCase() );
	public inline function clone():CaseInsensitiveMultiValueMap<T> return cast this.clone();
}
