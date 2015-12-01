package ufront.web.client;

#if macro
import haxe.macro.Context;

class ClientActionMacros {
	public static function emptyServer() {
		// If we're on the server, empty all the fields.
		return Context.defined("server") ? [] : null;
	}
}
#end
