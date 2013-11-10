package ufront.view;

import haxe.ds.StringMap;
import Map;
using StringTools;

/**
	A trampoline type for TemplateData, accepting, in order:

	- {}
	- Map<String,Dynamic>
	- Iterable<TemplateData>
	
	No string conversion or escaping happens at this level, that is up to the templating engine.
**/
abstract TemplateData({}) {
	
	inline function new( obj:{} ) 
		this = obj;

	/** Convert into a `Dynamic<String>` anonymous object **/
	@:to public function toObject():{}
		return this;

	/** Convert into a regular map **/
	@:to public inline function toMap():Map<String,Dynamic> {
		var ret = new Map<String,Dynamic>();
		for ( k in Reflect.fields(this) ) ret[k] = Reflect.field( this, k );
		return ret;
	}

	/** Get a value from the template data.  This is also used for array access. **/
	@:arrayAccess public inline function get( key:String ) return Reflect.field( this, key );
	
	/** Set a value on the template data.  The value will be run through `StringTools.htmlEscape`.  This is also used for array access setting of values. **/
	@:arrayAccess public inline function set( key:String, val:Dynamic ):TemplateData {
		Reflect.setField( this, key, val );
		return new TemplateData(this);
	}

	/** Set many unescaped values from a StringMap **/
	public function setMap( d:Map<String,Dynamic> ):TemplateData {
		for ( k in d.keys() ) set( k, d.get(k) );
		return new TemplateData(this);
	}

	/** Set many unescaped values from an anonymous object **/
	public function setObject( d:{} ):TemplateData {
		for ( k in Reflect.fields(d) ) set( k, Reflect.field(d,k) );
		return new TemplateData(this);
	}

	/** from casts **/

	@:from public static function fromObject( d:{} ):TemplateData {
		return new TemplateData( d );
	}

	@:from public static function fromMap( d:Map<String,Dynamic> ):TemplateData {
		var m:TemplateData = new TemplateData( {} );
		m.setMap( d );
		return m;
	}

	@:from public static function fromMany( datas:Iterable<TemplateData> ):TemplateData {
		var m:TemplateData = new TemplateData( {} );
		for ( d in datas ) {
			m.setObject( d.toObject() );
		}
		return m;
	}
}