package ufront.auth;

/**
	An interface describing an authentication handler.

	This lets you write code where the underlying authentication layer could be swapped out.
	For example, you may switch from EasyAuth (db authentication) to LDAP, or to an OAuth provider.

	Using this mechanism would allow your login checks, identity checks, and permission checks to remain the same with a different (or even multiple) login mechanisms.
	
	@author Jason O'Neil
**/
interface IAuthUser
{
	/** 
		Does this user have the specified permission(s)
		You can specify either a single permission or a group or permissions.  
		All permissions must be satisfied for it to return true.
	**/
	function can( ?permission:EnumValue, ?permissions:Iterable<EnumValue> ) : Bool;
}