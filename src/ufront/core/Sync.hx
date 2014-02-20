package ufront.core;

import tink.core.Error.Pos;
import ufront.web.HttpError;
using tink.CoreApi;

/**
	Simple shortcuts for creating Future's synchronously
**/
class Sync {

	/**
		Return a Success(Noise) to satisfy Surprise<Noise,T>
	**/
	public static function success<F>():Surprise<Noise,F> {
		if ( s==null ) s = Future.sync( Success(Noise) );
		return cast s;
	}
	static var s:Surprise<Noise,Dynamic>;

	/**
		Return a Failure(HttpError) to satisfy Surprise<T,HttpError>

		Will wrap your error with `HttpError.internalServerError(err)`
	**/
	public static function httpError<S>( ?msg:String, ?err:Dynamic, ?p:Pos ):Surprise<S,HttpError> {
		return Future.sync( Failure( HttpError.wrap(err,msg,p) ) );
	}

	/**
		Alias for `tink.core.Future.sync(v)`
	**/
	public static function of<T>( v:T ) {
		return Future.sync( v );
	}
}