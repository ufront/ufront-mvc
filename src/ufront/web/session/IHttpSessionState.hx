package ufront.web.session;

/**
	An interface describing an open HTTP session.

	The methods are similar to Map(), with `get`, `set`, `exists`, `remove` and `clear`.

	There are also some methods to do with the actual session, not the data inside it: `dispose`, `id` and `setLifeTime`.
	
	@author Franco Ponticelli
**/
interface IHttpSessionState
{
	public function dispose() : Void;
	public function clear() : Void;
	public function get(name : String) : Dynamic;
	public function set(name : String, value : Dynamic) : Void;
	public function exists(name : String) : Bool;
	public function remove(name : String) : Void;
	public function id() : String;
	public function setLifeTime(lifetime:Int):Void;
}