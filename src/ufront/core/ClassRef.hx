package ufront.core;

/**
A reference to a specific class.

ClassRef can take either a `Class<T>` or a `String` containing the name of the class.
The ClassRef then stores the fully qualified class name as a reference that can be used later, serialized, transferred over remoting etc.
**/
abstract ClassRef<T>(String) {
	inline public function new( className:String )
		this = className;

	/**
	Get the class name as a String.
	This is available as a `@:to` cast.
	**/
	@:to public inline function toString():String
		return this;

	/**
	Resolve the class using `Type.resolveClass()`.
	This will throw an error if the type is not found.
	The resolved class will be unsafely cast into the expected class type `T`.
	This is available as a `@:to` cast.
	**/
	@:to public inline function toClass():Class<T>
		return cast Type.resolveClass( this );

	/**
	Get a `ClassRef` from a given `Class`.
	This is available as a `@:from` cast.
	**/
	@:from public static inline function fromClass<T1>( v:Class<Dynamic> ):ClassRef<T1>
		return new ClassRef( Type.getClassName(v) );

	/**
	Get a `ClassRef` from a given `String` with the class name.
	The generated ClassRef will be unsafely cast into the expected ClassRef type `T1`.
	This is available as a `@:from` cast.
	**/
	@:from public static inline function fromClassName<T1>( className:String ):ClassRef<T1>
		return new ClassRef( className );
}
