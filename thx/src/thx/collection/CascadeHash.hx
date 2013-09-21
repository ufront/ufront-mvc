/**
 * ...
 * @author Franco Ponticelli
 */

package thx.collection;
import thx.error.Error;
import thx.error.NullArgument;
import Map;

class CascadeHash<T> implements IMap<String,T>
{	
	var _h : List<Map<String, T>>;
	public function new(hashes : Array<Map<String, T>>)
	{
		NullArgument.throwIfNull(hashes);
		_h = new List();
		for(h in hashes)
			_h.add(h);
	}
	
	public function set(key : String, value : T)
	{
		_h.first().set(key, value);
	}
	
	public function remove(key : String)
	{
		for(h in _h)
			if(h.remove(key))
				return true;
		return false;
	}
	
	public function get(key : String)
	{   
		for(h in _h)
			if(h.exists(key))
				return h.get(key);
		return null;
	}
	
	public function exists(key : String)
	{ 
		for(h in _h)
			if(h.exists(key))
				return true;
		return false;
	}
	
	public function iterator():Iterator<T>
	{
		var list = new List();
		for (k in keys())
			list.push(get(k));
		return list.iterator();
	}
	
	public function keys():Iterator<String>
	{
		var s = new Set();
		for(h in _h)
			for(k in h.keys())
				s.add(k);
		return s.iterator();
	}
	
	public function toString()
	{
		var arr = [];
		for (k in keys())
			arr.push(k + ": " + get(k));
		return "{" + arr.join(", ") + "}";
	}

	public function toStringMap():haxe.ds.StringMap<T>
	{
		var sm = new Map<String,T>();
		for(h in _h)
			for(k in h.keys())
				sm[k] = h.get(k);
		return sm;
	}
}