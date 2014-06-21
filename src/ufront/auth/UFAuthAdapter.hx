package ufront.auth;

import tink.CoreApi;

interface UFAuthAdapter<T>
{
	public function authenticate():Surprise<T,AuthError>;
}

interface UFAuthAdapterSync<T>
{
	public function authenticateSync():Outcome<T,AuthError>;
}