package ufront.core;

import minject.Injector;
import haxe.macro.Expr;
import minject.InjectorMacro;

/**
Some utilities and shortcuts for working with `minject.Injector`.
**/
class InjectionTools {
	/**
	A shortcut macro to call `Injector.mapValue`, with some extra helpers.

	- This will create a new rule in the current injector.
	- It will ensure the `whenAskedFor` class is marked with `@:keep`, to protect it from Dead Code Elimination.
	- The new rule will replace any identical rules in the current injector, without affecting parent injectors.
	- If the value is a class instance, and the implementation class used is different to `whenAskedFor`, an extra rule will be mapped for the implementation type.

	@param injector The injector to record the value mapping into.
	@param whenAskedFor The class or interface to map the value to.
	@param val The value to supply.
	@return The original injector.
	**/
	#if !macro macro #end public static function injectValue<T>( injector:ExprOf<Injector>, whenAskedFor:Expr, val:Expr, ?named:ExprOf<String> ):ExprOf<Injector> {
		InjectorMacro.keep( whenAskedFor );
		var className = InjectorMacro.getType( whenAskedFor );
		return macro @:privateAccess ufront.core.InjectionTools._injectValue( $injector, $className, $val, $named );
	}

	/**
	A shortcut macro to call `Injector.mapClass`, `Injector.mapSingleton` or `Injector.mapSingletonOf`, with some extra helpers.

	- This will create a new rule in the current injector.
	- If `singleton` is true and `class2` is supplied, `injector.mapSingletonOf( cl, class2, ?named )` is used.
	- If `singleton` is true and `class2` is not supplied, `injector.mapSingleton( cl, ?named )` is used.
	- If `singleton` is false and `class2` is supplied, `injector.mapClass( cl, class2, ?named )` is used.
	- If `singleton` is false and `class2` is not supplied, `injector.mapClass( cl, cl, ?named )` is used.
	- It will ensure that both `class1` and `class2` are marked with `@:keep`, to protect them from Dead Code Elimination.
	- The new rule will replace any identical rules in the current injector, without affecting parent injectors.

	@param injector The injector to inject into.
	@param class1 The `whenAskedFor` class or interface. If `class2` is not supplied this is also used as the implementation.
	@param class2 (optional) An implementation class to use when `cl` is asked for. If not supplied, `class1` will be used.
	@param singleton (default=false) Should this class produce always produce a singleton?
	@param named (optional) A specific name that this injection mapping should apply to.
	@return The original injector.
	**/
	#if !macro macro #end public static function injectClass<T>( injector:ExprOf<Injector>, class1:Expr, ?class2:Null<Expr>, ?singleton:ExprOf<Bool>, ?named:ExprOf<String> ):ExprOf<Injector> {
		InjectorMacro.keep( class1 );
		if ( class2!=null )
			InjectorMacro.keep( class2 );
		return macro @:privateAccess ufront.core.InjectionTools._injectClass( $injector, $class1, $class2, $singleton, $named );
	}

	static function _removeExistingRule( injector:Injector, className:String, named:String ) {
		// Please note we cannot use `injector.unmap` because that may modify a parent injector, which we want to leave untouched.
		var existingRule = injector.getTypeRule( className, named );
		if ( existingRule.hasOwnResponse() ) {
			existingRule.setResult(null);
		}
	}

	static function _injectValue<T>( injector:Injector, className:String, val:T, ?named:String ):Injector {
		if ( className!=null ) {
			_removeExistingRule( injector, className, named );
			if ( val!=null ) {
				injector.mapTypeValue( className, val, named );
				// If it is a class, map the concrete implementation so that's available to anyone looking for it.
				switch Type.typeof( val ) {
					case TClass( implementationClass ):
						var implClassName = Type.getClassName( implementationClass );
						if ( implClassName!=className ) {
							_removeExistingRule( injector, implClassName, named );
							injector.mapTypeValue( implClassName, val, named );
						}
					case _:
				}
			}
		}
		return injector;
	}

	static function _injectClass<T>( injector:Injector, class1:Class<T>, class2:Null<Class<T>>, singleton:Bool, ?named:String ):Injector {
		if ( class1!=null ) {
			if ( class2==null )
				class2 = class1;
			var class1Name = Type.getClassName( class1 );
			var class2Name = Type.getClassName( class2 );
			_removeExistingRule( injector, class1Name, named );
			if ( singleton )
				injector._mapSingletonOf( class1, class2, named );
			else
				injector._mapClass( class1, class2, named );
		}
		return injector;
	}

	/**
		Get a list of strings describing all the current mappings on this injector and it's parents.

		This is useful for debugging / logging purposes.

		This is only works when compiled with `-debug`, as minject does not include `toString()` functions for results unless compiled in debug mode.

		@param injector The current injector
		@param arr Optional, used for recursively checking parent injectors, should not be set manually.
		@param prefix Optional, used for recursively checking parent injectors, should not be set manually.
		@return An array containing a list of strings describing the current injecctor.
	**/
	public static function listMappings( injector:Injector, ?arr:Array<String>, ?prefix="" ):Array<String> {
		#if debug
			if ( arr==null ) arr = [];
			if ( injector.parent!=null )
				listMappings( injector.parent, arr, "(parent)"+prefix );
			for ( r in @:privateAccess injector.rules ) {
				arr.push( prefix+r.toString() );
			}
			return arr;
		#else
			return ["Injector mappings not available unless compiled with -debug."];
		#end
	}
}
