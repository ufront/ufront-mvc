package ufront.auth;

import ufront.web.context.HttpContext;


/**
	An AuthHandler which always gives you permission to do anything.

	Useful for command line tools that don't require authentication checks.
	
	@author Jason O'Neil
**/
class YesBossAuthHandler<T:UFAuthUser> implements UFAuthHandler<T>
{
	public function new() {}

	public function isLoggedIn() return true;

	public function requireLogin() {}
	
	public function isLoggedInAs( user:T ) return true;

	public function requireLoginAs( user:T ) {}

	public function hasPermission( permission:EnumValue ) return true;

	public function hasPermissions( permissions:Iterable<EnumValue> ) return true;

	public function requirePermission( permission:EnumValue ) {}

	public function requirePermissions( permissions:Iterable<EnumValue> ) {}
	
	public function getUserByID( id:String ):Null<T> return null;

	public var currentUser(get,set):Null<T>;

	function get_currentUser() return null;
	function set_currentUser( u:T ) return u;

	static var _factory:YesBossFactory;
	public static function getFactory() {
		if (_factory==null) _factory = new YesBossFactory();
		return _factory;
	}
}

class YesBossFactory implements UFAuthFactory {
	public function new() {}

	public function create( context:HttpContext ) {
		return new YesBossAuthHandler();
	}
}