package ufront.web.session;

import ufront.web.session.UFHttpSession;
import ufront.web.context.HttpContext;
import ufront.core.Uuid;
import tink.CoreApi;

/**
A session implementation that just uses a map, and is discarded at the end of the request.

This is useful for writing unit tests etc.
**/
class TestSession implements UFHttpSession {
	public var id(get,null):String;
    public var map:Map<String,Dynamic>;

	public function new() {
		map = new Map();
		id = Uuid.create();
	}

	public function setExpiry( e:Int ) {}

	public function init():Surprise<Noise,Error> return Future.sync( Success(Noise) );

	public function commit():Surprise<Noise,Error> return Future.sync( Success(Noise) );

	public function triggerCommit():Void {};

	public function isActive():Bool return true;

	public function isReady():Bool return true;

	public function get( name:String ):Dynamic return map[name];

	public function set( name:String, value:Dynamic ):Void map[name] = value;

	public function exists( name:String ):Bool return map.exists( name );

	public function remove(name:String):Void map.remove( name );

	public function clear():Void for ( key in map.keys() ) map.remove( key );

	public function regenerateID():Void {}

	public function close():Void {}

	function get_id() return id;
}
