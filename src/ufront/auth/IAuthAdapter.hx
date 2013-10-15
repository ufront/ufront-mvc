package ufront.auth;

import tink.core.Outcome;

interface IAuthAdapter<T>
{
	public function authenticate() : Outcome<T,PermissionError>;
}