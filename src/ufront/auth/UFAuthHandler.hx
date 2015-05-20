package ufront.auth;

import ufront.auth.UFAuthUser;

/**
An authentication handler that can be used with Ufront applications.

By using this `UFAuthHandler` interface, you are able to write code where the underlying authentication layer could be changed.
For example, you may switch from EasyAuth (a mysql DB form of authentication) to a solution using social logins, an OAuth provider or LDAP.
Or you may use a combination of these.

Writing your code against the `UFAuthHandler` interface, rather than a specific implementation, allows you to write your login checks, identity checks, and permission checks in a way that is usable with different (or even multiple) login mechanisms.

@author Jason O'Neil
**/
interface UFAuthHandler<T:UFAuthUser>
{
	/**
	Is a session currently open and authenticated - is the user logged in?
	**/
	function isLoggedIn():Bool;

	/**
	Require the user to be logged in.
	Otherwise throw `AuthError.NotLoggedIn`
	**/
	function requireLogin():Void;

	/**
	Is this particular user currently logged in?
	Will return false if a different user is logged in.
	**/
	function isLoggedInAs( user:UFAuthUser ):Bool;

	/**
	Require this user to be the one currently logged in.
	Otherwise will throw `AuthError.NotLoggedInAs( user )`
	**/
	function requireLoginAs( user:UFAuthUser ):Void;

	/**
	Does the given user have the specified permission?
	Will return false if the user is not logged in, or if the user does not have permission.
	**/
	function hasPermission( permission:EnumValue ):Bool;

	/**
	Does the given user have the specified permissions?
	Will return false if the user is not logged in, or if the user does not have all of the specified permissions.
	**/
	function hasPermissions( permissions:Iterable<EnumValue> ):Bool;

	/**
	Require the given user to have the specified permission.
	If not, throw `AuthError.NoPermission(permission)`.
	**/
	function requirePermission( permission:EnumValue ):Void;

	/**
	Require the given user to have the specified permissions.
	If not, throw `AuthError.NoPermission(permission)`.
	**/
	function requirePermissions( permissions:Iterable<EnumValue> ):Void;

	/** A String representation, usually just the name of the AuthHandler class, and possibly the current user. **/
	function toString():String;

	/** Type this handler as `UFAuthHandler<UFAuthUser>` to avoid variance issues. **/
	function asAuthHandler():UFAuthHandler<UFAuthUser>;

	/**
	The currently logged in user.  Will be null if no user is logged in.
	**/
	var currentUser(get,never):Null<T>;
}
