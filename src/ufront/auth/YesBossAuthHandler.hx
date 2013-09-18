package ufront.auth;

import hxevents.Dispatcher;
import hxevents.Notifier;

/**
	An AuthHandler which always gives you permission to do anything.

	Useful for command line tools that don't require authentication checks.
	
	@author Jason O'Neil
**/
class YesBossAuthHandler<T:IAuthUser> implements IAuthHandler<T>
{
	function isLoggedIn() return true;

	function requireLogin() {}
	
	function isLoggedInAs( user:T ) return true;

	function requireLoginAs( user:T ) {}

	function hasPermission( permission:EnumValue ) return true;

	function hasPermissions( permissions:Iterable<EnumValue> ) return true;

	function requirePermission( permission:EnumValue ) {}

	function requirePermissions( permissions:Iterable<EnumValue> ) {}

	var currentUser(get,null);

	function get_currentUser() return null;
}