package ufront.web.session;

/**
	A session implementation that doesn't actually save session state.

	In fact, it forgets everything the moment you ask it.  Use this when you do not want a session implementation, but also do not want to get null related errors in your code.  For example, when testing.
**/
class VoidSession implements UFHttpSessionStateSync
{
	public static function create( context:HttpContext ) : UFHttpSessionState {
		return new VoidSession();
	}

	public function new( context:HttpContext ) {}

	public function setExpiry( e:Int ) {}

	public function init():Void {}

	public function commit():Void {}

	public inline function get( name:String ):Dynamic return null;

	public inline function set( name:String, value:Dynamic ):Void {}

	public inline function exists( name:String ):Bool return false;

	public inline function remove(name:String):Void {}

	public inline function clear():Void {}

	public function regenerateID() return "";
	
	public inline function getID() return "";

	public function close():Void {}
}
