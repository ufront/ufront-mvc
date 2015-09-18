package ufront.web.client;

class ClientActionMacros {
	public static function emptyServer() {
		// If we're on the server, empty all the fields.
		return Context.defined("server") ? [] : null;
	}
}
