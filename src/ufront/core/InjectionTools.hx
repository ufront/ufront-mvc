package ufront.core;

import minject.Injector;

/**
	Some utilities for working with `minject.Injector`.
**/
class InjectionTools {
	/**
		Shortcut to map a class into `injector`.  
		
		The rules are as follows:

		> - If `cl` is null, this method has no effect.
		> - If `val` is supplied, `injector.mapValue( cl, val, ?named )` will be used.
		> 	- If the type of val is not exactly `cl`, then `injector.mapValue( Type.getClass(cl), val, ?named )` will also be called so that the implementation class is available.
		> - Otherwise, if `singleton` is true:
		> 	- And `cl2` is supplied, `injector.mapSingletonOf( cl, cl2, ?named )` is used.
		> 	- And `cl2` is not supplied, `injector.mapSingleton( cl, ?named )` is used.
		> - Otherwise, if `singleton` is false:
		> 	- And `cl2` is supplied, `injector.mapClass( cl, cl2, ?named )` is used.
		> 	- And `cl2` is not supplied, `injector.mapClass( cl, cl, ?named )` is used.

		If a mapping for this class & name already exists, it will be replaced.
		If a mapping for this class & name already exists on a parent injector, it will be left in place, but the rule on the current (child) injector will take precedence.

		@param injector (required) The injector to inject into.
		@param cl (required) The `whenAskedFor` class or interface. If `cl2` is not supplied this is also used as the implementation.
		@param val (optional) The value to supply.
		@param cl2 (optional) An implementation class to use when `cl` is asked for. If not supplied, `cl` will be used.
		@param singleton (default=false) Should this class produce always produce a singleton?
		@param named (optional) A specific name that this injection mapping should apply to.
		@return The original injector.
	**/
	public static function inject<T>( injector:Injector, cl:Class<T>, ?val:T, ?cl2:Class<T>, ?singleton:Bool=false, ?named:String ):Injector {
		if ( cl!=null ) {
			// Unmap any existing rules.
			// Please note we cannot use `injector.unmap` because that may modify a parent injector, which we want to leave untouched.
			var existingMapping = injector.getMapping( cl, named );
			if ( existingMapping!=null ) {
				existingMapping.setResult(null);
			}
			if ( val!=null ) {
				injector.mapValue( cl, val, named );
				// Inject the concrete implementation too, in case somebody wants access to it.
				var implementationClass = Type.getClass( val );
				if ( implementationClass!=cl ) {
					var existingMapping = injector.getMapping( implementationClass, named );
					if ( existingMapping!=null ) {
						existingMapping.setResult(null);
					}
					injector.mapValue( implementationClass, val, named );
				}
			}
			else {
				if ( singleton && cl2!=null ) injector.mapSingletonOf( cl, cl2, named );
				else if ( singleton && cl2==null ) injector.mapSingleton( cl, named );
				else if ( cl2!=null ) injector.mapClass( cl, cl2, named );
				else injector.mapClass( cl, cl, named );
			}
		}
		return injector;
	}
}