package ufront.core;

/**
Interal utilities.
**/
@:allow(ufront) class Utils {
	macro static function rethrow(e) {
		return if (haxe.macro.Context.defined("neko"))
			macro neko.Lib.rethrow(e);
		else
			macro throw e;
	}
}