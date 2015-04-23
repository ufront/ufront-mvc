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
**/
class InjectionRef<T> {

	/** Return a reference for the current value. **/
	public static inline function of<T>( v:T ):InjectionRef<T> {
		return new InjectionRef( v );
	}

	var value:T;
	function new( v:T ) value = v;

	/**
		Return the value behind the current reference.
		Please note that this can only be called once - after that the value is set to null and the object is recycled.
	**/
	public inline function get():T {
		return value;
	}
}
