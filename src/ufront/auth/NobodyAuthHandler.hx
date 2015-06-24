package ufront.auth;

import ufront.auth.AuthError;

/**
An AuthHandler which always gives no permissions.

This is used when another auth handler isn't available, and will return false (or throw errors) for all permission checks.

Who would trust you anyway? *You're a nobody.* ;)

@author Jason O'Neil
**/
class NobodyAuthHandler implements UFAuthHandler {
	public function new() {}

	public function isLoggedIn() return false;

	public function requireLogin() throw NotLoggedIn;

	public function isLoggedInAs( user:UFAuthUser ) return false;

	public function requireLoginAs( user:UFAuthUser ) throw NotLoggedInAs( user );

	public function hasPermission( permission:EnumValue ) return false;

	public function hasPermissions( permissions:Iterable<EnumValue> ) return false;

	public function requirePermission( permission:EnumValue ) throw NoPermission( permission );

	public function requirePermissions( permissions:Iterable<EnumValue> ) for (p in permissions) throw NoPermission( p );

	public function toString() return "NobodyAuthHandler";

	public var currentUser(get,never):Null<UFAuthUser>;
	function get_currentUser() return null;
}
