package ufront.auth;

import ufront.web.context.HttpContext;


/**
	An AuthHandler which always gives you permission to do anything.

	Useful for command line tools that don't require authentication checks.
	
	@author Jason O'Neil
**/
class YesBossAuthHandler implements UFAuthHandler<UFAuthUser>
{
	public function new() {}

	public function isLoggedIn() return true;

	public function requireLogin() {}
	
	public function isLoggedInAs( user:UFAuthUser ) return true;

	public function requireLoginAs( user:UFAuthUser ) {}

	public function hasPermission( permission:EnumValue ) return true;

	public function hasPermissions( permissions:Iterable<EnumValue> ) return true;

	public function requirePermission( permission:EnumValue ) {}

	public function requirePermissions( permissions:Iterable<EnumValue> ) {}
	
	public function getUserByID( id:String ):Null<UFAuthUser> return new BossUser();

	public var currentUser(get,set):Null<UFAuthUser>;

	function get_currentUser() return new BossUser();
	function set_currentUser( u:Null<UFAuthUser> ) return u;

	static var _factory:YesBossFactory;
	public static function getFactory() {
		if (_factory==null) _factory = new YesBossFactory();
		return _factory;
	}
}

class BossUser implements ufront.auth.UFAuthUser {
	public var userID(get,null):String;
	public function new() {}
	public function can( ?p:EnumValue, ?ps:Iterable<EnumValue> ):Bool return true;
	function get_userID() return "The Boss";
}

class YesBossFactory implements UFAuthFactory {
	public function new() {}

	public function create( context:HttpContext ) {
		return new YesBossAuthHandler();
	}
}