package ufront.core;

import tink.core.Error.Pos;
import ufront.web.HttpError;
using tink.CoreApi;

/**
	Simple shortcuts for creating Future's synchronously

	TODO: Deprecate this before a stable release.
**/
class Sync {

	/**
		Return a Success(Noise) to satisfy Surprise<Noise,T>
	**/
	public static inline function success<F>():Surprise<Noise,F> {
		return SurpriseTools.success();
	}

	/**
		Return a Failure(Error) to satisfy Surprise<T,HttpError>

		Will wrap your error with `HttpError.internalServerError(err)`
	**/
	public static function httpError<S>( ?msg:String, ?err:Dynamic, ?p:Pos ):Surprise<S,Error> {
		return Future.sync( Failure( HttpError.wrap(err,msg,p) ) );
		// return SurpriseTools.asSurpriseError( msg, err, p );
	}

	/**
		Alias for `tink.core.Future.sync(v)`
	**/
	public static inline function of<T>( v:T ):Future<T> {
		return SurpriseTools.asFuture( v );
	}
}
