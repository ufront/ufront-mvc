package neko.ufront.web.session;

/**
 * ...
 * @author Andreas Söderlund
 */

import ufront.web.session.IHttpSessionState;
import neko.ufront.web.session.NekoSession;
import thx.sys.Lib;

using StringTools;

class FileSession implements IHttpSessionState
{
    public inline function setLifeTime(lifetime:Int){
    	if(lifetime!=0)
    		NekoSession.setCookieParams(lifetime);
    }
    
	public function new(savePath:String, ?expire:Int = 0) {
		savePath = savePath.replace("\\", "/");
		if (!savePath.endsWith("/"))
			savePath += "/";
		setLifeTime(expire);
		NekoSession.set_savePath(savePath);
	}

	public function dispose():Void {
		if (!NekoSession.started)
			return;
		NekoSession.close();
	}

	public inline function clear():Void {
		NekoSession.clear();
	}

	public inline function get(name:String):Dynamic {
		return NekoSession.get(name);
	}

	public inline function set(name:String, value:Dynamic):Void {
		NekoSession.set(name, value);
	}

	public inline function exists(name:String):Bool {
		return NekoSession.exists(name);
	}

	public inline function remove(name:String):Void {
		NekoSession.remove(name);
	}
	
	public inline function id():String {
		return NekoSession.id;
	}
}