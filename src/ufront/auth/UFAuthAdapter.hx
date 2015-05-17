package ufront.auth;

import tink.CoreApi;

/**
An interface describing a mechanism for authenticating a user.

It is important to note that this does not specify how the user is authenticated - either in terms of technology or user experience.
For example, a username and password may be required, or you may use another method involving social logons, certificates, cookies or something else entirely.

However the adapter instance is set up, when `this.authenticate()` is called, it should check the authentication and return either a valid user, or an auth error.
**/
interface UFAuthAdapter<T:UFAuthUser> {
	public function authenticate():Surprise<T,AuthError>;
}

/**
An interface describing a mechanism for authenticating a user synchronously.

This is similar to `UFAuthAdapter`, except `this.authenticateSync()` returns an `Outcome` rather than a `Surprise`, and so must run synchronously.
**/
interface UFAuthAdapterSync<T:UFAuthUser> {
	public function authenticateSync():Outcome<T,AuthError>;
}
