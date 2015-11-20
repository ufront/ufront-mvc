package ufront.view;

import haxe.ds.StringMap;
import Map;
using StringTools;

/**
TemplateData is a collection of named data to be used in a template.

It is an `abstract`, allowing implicit casts from:

- {}
- Map<String,Dynamic>
- Iterable<TemplateData>

This means you can use it in a versatile way:

```
var td1:TemplateData = { name: "Jason", location: "Perth" };
var td2:TemplateData = [ name=>"O'Neil", age=>27 ];
var td3:TemplateData = [ td1, td2 ]; // Merge the 2 sets.
```

These methods are provided to access or modify the contents of the template data:

- `this.get()`
- `this.set()`
- `this.setObject()`
- `this.setMap()`

Array access is also provided for getting / setting data:

```
templateData["name"] = "Jason";
trace(templateData["location"]);
```

No string conversion or escaping happens at this level, that is up to the templating engine.
**/
abstract TemplateData({}) to {} {

	/**
	Create a template data object.

	@param obj The object to use.  If null a new TemplateData object with no values will be used.
	**/
	public inline function new( ?obj:{} )
		this = (obj!=null) ? obj : {};

	/**
	Convert into a `Dynamic<Dynamic>` anonymous object.
	Please note this is not an implicit `@:to` cast, because the resulting type would match too many false positives.
	To use this cast call `templateData.toObject()` explicitly.
	**/
	public inline function toObject():Dynamic<Dynamic>
		return this;

	/**
	Convert into a `Map<String,Dynamic>`.
	This is also available as an implicit `@:to` cast.
	**/
	@:to public function toMap():Map<String,Dynamic> {
		var ret = new Map<String,Dynamic>();
		for ( k in Reflect.fields(this) ) ret[k] = Reflect.field( this, k );
		return ret;
	}

	/**
	Convert into a `StringMap<Dynamic>`.
	This is also available as an implicit `@:to` cast.
	**/
	@:to public inline function toStringMap():StringMap<Dynamic> {
		return toMap();
	}

	/**
	Get a value from the template data.

	This is also used for array access: `templateData['name']` is the same as `templateData.get('name')`.

	@param key The name of the value to retrieve.
	@return The value, or null if it was not available.
	**/
	@:arrayAccess public inline function get( key:String ):Null<Dynamic> return Reflect.field( this, key );

	/**
	See if a specific field exists in the template data.
	**/
	public function exists( key:String ):Bool {
		return Reflect.hasField( this, key );
	}

	/**
	Set a value on the template data.

	Please note array setters are also available, but they use the private `array_set` method which returns the value, rather than the TemplateData object.

	@param key The name of the key to set.
	@param val The value to set.
	@return The same TemplateData so that method chaining is enabled.
	**/
	public function set( key:String, val:Dynamic ):TemplateData {
		Reflect.setField( this, key, val );
		return new TemplateData( this );
	}

	/** Array access setter. **/
	@:arrayAccess function array_set<T>( key:String, val:T ):T {
		Reflect.setField( this, key, val );
		return val;
	}

	/**
	Set many values from a `Map<String,Dynamic>`

	`templateData.set(key,map[key])` will be called for each pair in the map.

	@param map The map data to set.
	@return The same TemplateData so that method chaining is enabled.
	**/
	public function setMap<T>( map:Map<String,T> ):TemplateData {
		for ( k in map.keys() ) {
			set( k, map[k] );
		}
		return new TemplateData( this );
	}

	/**
	Set many values from an object.

	`templateData.set(fieldName,fieldValue)` will be called for each field or property on the object.

	The behaviour differ depending on if this is an anonymous object or a class instance:

	- Anonymous objects will find all fields using `Reflect.fields()` and fetch the values using `Reflect.field()`.
	- Class instance objects will find all fields using `Type.getInstanceFields()` and fetch the values using `Reflect.getProperty()`.
	- Other values will be ignored.

	Please note on PHP, objects that are class instances may fail to load fields that are functions.

	@param d The data object to set.
	@return The same TemplateData so that method chaining is enabled.
	**/
	public function setObject( d:{} ):TemplateData {
		switch Type.typeof(d) {
			case TObject:
				for ( k in Reflect.fields(d) ) set( k, Reflect.field(d,k) );
			case TClass(cls):
				#if php
					// PHP can't access properties on class instances using Reflect.getProperty, it throws an error.
					// These checks and fallbacks are not required on JS or neko. It might be good to submit a bug report.
					for ( k in Type.getInstanceFields(cls) ) {
						try set( k, Reflect.getProperty(d,k) )
						catch ( e:Dynamic ) try set( k, Reflect.field(d,k) )
						catch ( e:Dynamic ) {}
					}
				#else
					for ( k in Type.getInstanceFields(cls) ) set( k, Reflect.getProperty(d,k) );
				#end
			case _:
		}
		return new TemplateData( this );
	}

	/** from casts **/

	/**
	Automatically cast from a `Map<String,Dynamic>` into a TemplateData.
	**/
	@:from public static function fromMap<T>( d:Map<String,T> ):TemplateData {
		var m:TemplateData = new TemplateData( {} );
		m.setMap( d );
		return m;
	}

	/**
	Automatically cast from a `StringMap<Dynamic>` into a TemplateData.
	**/
	@:from public static inline function fromStringMap<T>( d:StringMap<T> ):TemplateData {
		return fromMap( d );
	}

	/**
	Automatically cast from a `Iterable<TemplateData>` into a combined `TemplateData.

	Values will be added in order, and later values with the same name as an earlier value will override the earlier value.

	If the iterable is empty, the resulting TemplateData will contain no properties.

	If an individual item is a StringMap, it will be added with `setMap`, otherwise it will be added with `setObject`.

	@param dataSets The collection of TemplateData objects to iterate over.
	@return The same TemplateData so that method chaining is enabled.
	**/
	@:from public static function fromMany( dataSets:Iterable<TemplateData> ):TemplateData {
		var combined:TemplateData = new TemplateData( {} );
		for ( d in dataSets ) {
			if ( d!=null ) {
				if ( Std.is(d,StringMap) ) {
					var map:StringMap<Dynamic> = cast d;
					combined.setMap( (map:StringMap<Dynamic>) );
				}
				else {
					var obj:Dynamic = d;
					combined.setObject( obj );
				}
			}
		}
		return combined;
	}

	/**
	Automatically cast from an object to a TemplateData.

	This results in a new object, the equivalent of calling `new TemplateData().setObject( d )`.

	This cast comes last in the code so it should be used only if none of the other casts were utilised.
	**/
	@:from public static inline function fromObject( d:{} ):TemplateData {
		return new TemplateData( {} ).setObject( d );
	}
}
