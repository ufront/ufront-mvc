package ufront.auth;

@:keep enum AuthError
{
	/** Thrown if a login is required, but the user was not logged in **/
	NotLoggedIn;

	/** Thrown if Authentication fails **/
	LoginFailed(msg:String);

	/** Thrown if a login is required, but the user was not logged in, or is logged in as someone else **/
	NotLoggedInAs(u:UFAuthUser);

	/** Thrown is a permission is required, but the user is not logged in or does not have the correct permission **/
	NoPermission(p:EnumValue);
}