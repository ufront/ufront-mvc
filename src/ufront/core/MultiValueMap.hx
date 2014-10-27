package ufront.core;

import haxe.ds.StringMap;
using StringTools;

/**
	A custom map structure that represents Http GET/POST parameters.

	It behaves similarly to `Map<String,T>`, except it can contain multiple values for a given parameter name, which is suitable for HTML inputs that return multiple values.

	Notes:

	- For PHP, multiple values are only supported if the parameter name ends with `[]`.
	- Because of the PHP limitation, other platforms (neko etc) ignore a `[]` at the end of a parameter name.
	- Complex lists, such as the following, are not supported: `<input name="person[1][firstName]" />`, only simple "[]" is supported: `<input name="person[]">`
**/
abstract MultiValueMap<T>( StringMap<Array<T>> ) from StringMap<Array<T>> to StringMap<Array<T>> {
	/** Create a new MultiValueMap **/
	public inline function new() this = new StringMap();

	// MEMBER METHODS

	/**
		Return an iterator containing the names of all parameters in this MultiValueMap
	**/
	public inline function keys() return this.keys();

	/**
		Check if a parameter with the given name exists.

		If the `name` is null, the result is unspecified.
	**/
	public inline function exists( name:String ) return this.exists( name );

	/**
		Return an iterator containing the values of each parameter in this MultiValueMap.
		If multiple parameters have the same name, all values will be included.
	**/
	public function iterator() {
		return [ for (arr in this) for (v in arr) v ].iterator();
	}

	/**
		Get the value for a parameter with this name.

		If this name has more than one parameter, the final value (in the order they were set) will be used.
		If there is no parameter with this name, it returns null.
		If `name` is null, the result is unspecified.

		Array access is provided on this method: `trace ( myMultiValueMap['emailAddress'] )`
	**/
	@:arrayAccess public function get( name:String ):Null<T> {
		if ( this.exists(name) ) {
			var arr = this.get( name );
			return arr[ arr.length-1 ];
		}
		else return null;
	}

	/**
		Get an array of values for the given parameter name.

		Multiple values will be returned in the order they were set.
		If there is only a single value, the array will have a length of `1`.
		If there is no parameter with this name, the array will have a length of `0`.
		If `name` is null, the result is unspecified.

		If the field name in your HTML input ended with "[]", you do not need to include that here.
		For example, the values of `<input name='phone[]' /><input name='phone[]' />` could be accessed with `MultiValueMap.get('phone')`.
	**/
	public function getAll( name:String ):Array<T> {
		if ( this.exists(name) ) return this.get( name );
		else return [];
	}

	/**
		Set a value in our MultiValueMap.

		If one or more parameters already existed for this name, they will be replaced.
		If the value is null, this method will have no effect.
		If name is null, the result is unspecified.

		If the name ends with "[]", the "[]" will be stripped from the name before setting the value.
		Names such as this are required for PHP to have multiple values with the same name.

		Array access is provided on this method: `trace ( myMultiValueMap['emailAddress'] = 'jason@ufront.net'; )`
	**/
	@:arrayAccess public function set( name:String, value:T ) {
		if ( value!=null ) {
			name = stripArrayFromName( name );
			this.set( name, [value] );
		}
	}

	/**
		Add a value to our MultiValueMap.

		If the value already exists, this value will be added after it.
		If the value is null, this will have no effect.
		If `name` is null, the result is unspecified.

		If the name ends with "[]", the "[]" will be stripped from the name before setting the value.
		Names such as this are required for PHP to have multiple values with the same name.
	**/
	public function add( name:String, value:T ) {
		if ( value!=null ) {
			name = (name!=null) ? stripArrayFromName( name ) : "";
			if ( this.exists(name) )
				this.get( name ).push( value );
			else
				this.set( name, [value] );
		}
	}

	/**
		Remove all values for a given key

		If the `key` is null, the result is unspecified.
	**/
	public inline function remove( key:String ) return this.remove( key );

	/**
		Create a clone of the current MultiValueMap.

		The clone is a shallow copy - the values point to the same objects in memory as the original map values.

		However the array for storing multiple values is a new array, meaning adding a new value on the cloned array will not cause the new value to appear on the original array.
	**/
	public function clone():MultiValueMap<T> {
		var newMap = new MultiValueMap();
		for ( k in this.keys() ) {
			for (v in this.get(k)) {
				newMap.add( k, v );
			}
		}
		return newMap;
	}

	/**
		Create a string representation of the current map.
	**/
	public function toString():String {
		var sb = new StringBuf();
		sb.add( "[" );
		for ( key in keys() ) {
			sb.add( '\n\t$key = [' );
			sb.add( getAll(key).join(", ") );
			sb.add( "]" );
		}
		if ( sb.length>1 )
			sb.add( "\n" );
		sb.add( "]" );
		return sb.toString();
	}

	inline function stripArrayFromName( name:String ) {
		return name.endsWith("[]") ? name.substr(0,name.length-2) : name;
	}

	// CASTS

	/** Implicit cast to `Map<String,Array<T>>` **/
	@:to public inline function toMapOfArrays<T>():Map<String,Array<T>> {
		return this;
	}

	/** Implicit cast from `Map<String,Array<T>>` **/
	@:from public static inline function fromMapOfArrays<T>( map:Map<String,Array<T>> ):MultiValueMap<T> {
		return map;
	}

	/**
		Convert a `MultiValueMap` into a `StringMap<T>`
	**/
	@:to public function toStringMap():StringMap<T> {
		var sm = new StringMap();
		for ( key in this.keys() ) sm.set( key, get(key) );
		return sm;
	}

	/**
		Convert a `MultiValueMap` into a `Map<String,T>`
	**/
	@:to inline public function toMap():Map<String,T> return toStringMap();

	/**
		Convert a `StringMap<T>` into a `MultiValueMap`

		If `map` is null, this will return an empty `MultiValueMap`.
	**/
	@:from public static function fromStringMap<T>( stringMap:StringMap<T> ):MultiValueMap<T> {
		var qm = new MultiValueMap();
		if ( stringMap!=null ) for ( key in stringMap.keys() ) {
			qm.set( key, stringMap.get(key) );
		}
		return qm;
	}

	/**
		Convert a `Map<String,T>` into a `MultiValueMap`

		If `map` is null, this will return an empty `MultiValueMap`
	**/
	@:from inline public static function fromMap<T>( map:Map<String,T> ):MultiValueMap<T> return fromStringMap( map );

	// STATICS

	/** Combine multiple `MultiValueMap`s into a single map. **/
	public static function combine<T>( maps:Array<MultiValueMap<T>> ):MultiValueMap<T> {
		var qm = new MultiValueMap();
		for ( map in maps ) {
			for ( key in map.keys() ) {
				for( val in map.getAll(key) ) {
					qm.add( key, val );
				}
			}
		}
		return qm;
	}
}
