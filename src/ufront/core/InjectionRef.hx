package ufront.core;

/**
	Sadly the `minject` library only supports injecting dependencies that are a class instance.
	Sometimes we would like to inject integers, booleans, functions, abstracts or more.
	This class provides a simple wrapper object that can be used.
	
	Please note that because minject doesn't pay attention to type parameters, any `InjectionRef` mapping will match any `InjectionRef` injection point.
	Therefore it is recommended you use named injection points whenever using `InjectionRef`.
	
	For example:
	
	```haxe
	var someInt:Int;
	@inject("someInt") public function new( ref:InjectionRef<Int> ) {
		this.someInt = ref.get();
	}
	```

	And then when you map a value:

	```haxe
	injector.mapValue( InjectionRef, "someInt", InjectionRef.of(99) );
	```

	Please note that all `InjectionRef` objects are recycled - after `get()` is called the value is emptied and the object is added to a pool to be used on the next `of()` call.
**/
class InjectionRef<T> {

	static var pool:Array<InjectionRef<Dynamic>> = [];

	/** Return a reference for the current value. **/
	public static function of<T>( v:T ):InjectionRef<T> {
		if ( pool.length>0 ) {
			var r:InjectionRef<T> = cast pool.shift();
			r.value = v;
			return r;
		}
		else return new InjectionRef( v );
	}

	var value:T;
	function new( v:T ) value = v;

	/**
		Return the value behind the current reference.
		Please note that this can only be called once - after that the value is set to null and the object is recycled.
	**/
	public function get():T {
		var v = value;
		value = null;
		pool.push( this );
		return v;
	}
}