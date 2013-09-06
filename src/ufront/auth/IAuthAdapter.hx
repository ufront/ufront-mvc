package ufront.auth;

import tink.core.types.Outcome;

interface IAuthAdapter<T>
{
	public function authenticate() : Outcome<T,PermissionError>;
}