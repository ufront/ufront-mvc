package ufront.core;

import minject.Injector;
import haxe.macro.Expr;
import minject.InjectorMacro;

/**
Some utilities and shortcuts for working with `minject.Injector`.
**/
class InjectionTools {
	/**
	Get a list of strings describing all the current mappings on this injector and it's parents.

	This is useful for debugging / logging purposes.

	This is only works when compiled with `-debug`, as minject does not include `toString()` functions for results unless compiled in debug mode.

	@param injector The current injector
	@param arr Optional, used for recursively checking parent injectors, should not be set manually.
	@param prefix Optional, used for recursively checking parent injectors, should not be set manually.
	@return An array containing a list of strings describing the current injector.
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
