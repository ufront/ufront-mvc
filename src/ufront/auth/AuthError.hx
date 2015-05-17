package ufront.auth;

/** Common authentication errors that may be encountered by a `UFAuthHandler`. **/
enum AuthError {
	/** A login is required, but the user was not logged in. **/
	NotLoggedIn;

	/** Authentication failed. **/
	LoginFailed( msg:String );

	/** A login is required, but the user was not logged in, or is logged in as someone else. **/
	NotLoggedInAs( u:UFAuthUser );

	/** A permission is required, but the user is not logged in or does not have the necessary permission. **/
	NoPermission( p:EnumValue );
}
