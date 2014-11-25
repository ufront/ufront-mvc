package haxe.remoting;

enum RemotingError<FailureType> {
	HttpError( remotingCallString:String, responseCode:Int, responseData:String );
	ServerSideException( remotingCallString:String, e:Dynamic, stack:String );
	ClientCallbackException( remotingCallString:String, e:Dynamic );
	UnserializeFailed( remotingCallString:String, troubleLine:String, err:String );
	NoRemotingResult( remotingCallString:String, responseData:String );
	ApiFailure( remotingCallString:String, data:FailureType );
	UnknownException( e:Dynamic );
}