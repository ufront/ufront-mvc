package haxe.remoting;

enum RemotingError {
	HttpError( callString:String, responseCode:Int, responseData:String );
	ServerSideException( callString:String, e:Dynamic, stack:String );
	ClientCallbackException( callString:String, e:Dynamic );
	UnserializeFailed( callString:String, troubleLine:String, err:String );
	NoRemotingResult( callString:String, responseData:String );
	UnknownException( e:Dynamic );
}