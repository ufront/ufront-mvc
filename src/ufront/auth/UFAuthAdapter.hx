package ufront.auth;

import tink.CoreApi;

interface UFAuthAdapter<T>
{
	public function authenticate():Surprise<T,PermissionError>;
}