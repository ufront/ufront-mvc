package ufront.web.session;

import ufront.web.session.UFHttpSession;
import ufront.web.context.HttpContext;
import tink.CoreApi;

/**
A session implementation that doesn't actually save session state.

In fact, it forgets everything the moment you ask it.
Use this when you do not want a session implementation, but also do not want to get null related errors in your code.
For example, when unit testing.
**/
class VoidSession implements UFHttpSession
{
	public var id(get,null):String;

	public function new() {}

	public function setExpiry( e:Int ) {}

	public function init():Surprise<Noise,Error> return Future.sync( Success(Noise) );

	public function commit():Surprise<Noise,Error> return Future.sync( Success(Noise) );

	public function triggerCommit():Void {};

	public function isActive():Bool return false;

	public function get( name:String ):Dynamic return null;

	public function set( name:String, value:Dynamic ):Void {}

	public function exists( name:String ):Bool return false;

	public function remove(name:String):Void {}

	public function clear():Void {}

	public function regenerateID():Void {}

	public function close():Void {}

	function get_id() return "";
}
