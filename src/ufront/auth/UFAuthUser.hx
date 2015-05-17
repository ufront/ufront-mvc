package ufront.auth;

/**
An interface describing a logged in user.

This is extremely basic, providing the bare minimum to test permissions, log events and work with `UFAuthHandler` classes.

@author Jason O'Neil
**/
interface UFAuthUser {
	/**
	Does this user have the specified permission(s)
	You can specify either a single permission or a group or permissions.
	All permissions must be satisfied for it to return true.
	**/
	function can( ?permission:EnumValue, ?permissions:Iterable<EnumValue> ) : Bool;

	/**
	A string representing a unique identifier for this user.

	This could be a database ID, a username, email, URL, or anything - the important thing is it is unique for this type of AuthHandler.
	**/
	var userID(get,null) : String;
}
