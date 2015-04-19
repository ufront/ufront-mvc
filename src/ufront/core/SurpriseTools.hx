package ufront.core;

import haxe.PosInfos;
import tink.core.Error;
import ufront.web.HttpError;
using tink.CoreApi;

/**
Tools to help transform
**/
class SurpriseTools {
	/** Return a `Surprise<Noise,T>` success. **/
	public static function success<F>():Surprise<Noise,F> {
		if ( s==null ) s = Future.sync( Success(Noise) );
		return cast s;
	}
	static var s:Surprise<Noise,Dynamic>;

	/** Wrap a value in `Future.sync(data)` **/
	public static function asFuture<T>( data:T ):Future<T>
		return Future.sync( data );

	/** Wrap an `Outcome` in `Future.sync(outcome)` **/
	public static function asSurprise<D,F>( outcome:Outcome<D,F> ):Surprise<D,F>
		return Future.sync( outcome );

	/** Wrap a value in `Future.sync(Success(data))` **/
	public static function asGoodSurprise<D,F>( data:D ):Surprise<D,F>
		return Future.sync( Success(data) );

	/** Wrap a value in `Future.sync(Failure(err))` **/
	public static function asBadSurprise<D,F>( err:F ):Surprise<D,F>
		return Future.sync( Failure(err) );

	/** Wrap a value in `Future.sync(Failure(err))` **/
	public static function asSurpriseError<D,F>( err:F, ?msg:String, ?p:Pos ):Surprise<D,Error> {
		if ( msg==null )
			msg = 'Failure: $err';
		return Future.sync( Failure(HttpError.wrap(err,msg,p)) );
	}

	/** Wrap a value in `Future.sync(Failure(err))` **/
	public static function asSurpriseTypedError<D,F>( err:F, ?msg:String, ?p:Pos ):Surprise<D,TypedError<F>> {
		if ( msg==null )
			msg = 'Failure: $err';
		return Future.sync( Failure(cast HttpError.wrap(err,msg,p)) );
	}

	/** If a surprise returns a Success, transform the Success data to _____. **/
	public static function changeSuccessTo<D1,D2,F>( s:Surprise<D1,F>, newSuccessData:D2 ):Surprise<D2,F> {
		return s.map(function(outcome) return switch outcome {
			case Success(_): Success(newSuccessData);
			case Failure(e): Failure(e);
		});
	}

	/** If a surprise returns a Success, transform the Success data to _____. **/
	public static inline function changeSuccessToNoise<D,F>( s:Surprise<D,F> ):Surprise<Noise,F>
		return changeSuccessTo( s, Noise );

	/** If a surprise returns a Failure, transform the Failure data to _____. **/
	public static function changeFailureTo<D,F1,F2>( s:Surprise<D,F1>, newFailureData:F2 ):Surprise<D,F2> {
		return s.map(function(outcome) return switch outcome {
			case Success(d): Success(d);
			case Failure(_): Failure(newFailureData);
		});
	}

	/** If a surprise returns a Failure, transform the Failure data to a wrapped error. **/
	public static function changeFailureToError<D,F>( s:Surprise<D,F>, ?msg:String, ?p:Pos ):Surprise<D,Error> {
		return s.map(function(outcome) return switch outcome {
			case Success(d): Success(d);
			case Failure(inner):
				if ( msg==null )
					msg = 'Failure: $inner';
				Failure( HttpError.wrap(inner, msg, p) );
		});
	}
}

/**
Tools to help transform callbacks surprises.
**/
class CallbackTools {

	/**
		Transform a NodeJS style async call with no returned values into a surprise.

		This expects an async call which has a callback with a single `error` argument.

		If the error argument is not null, it will return a Failure, with a `tink.core.Error` with the error message and the position of the call that failed.

		If the error argument is null, then the call is a `Success( Noise )`.
	**/
	static public function asVoidSurprise<T>( cb:(Null<String>->Void)->Void, ?pos:PosInfos ):Surprise<Noise,Error> {
		var t = Future.trigger();
		cb( function(errorMsg:Null<String>) {
			if ( errorMsg!=null ) {
				var e = Error.withData( InternalError, errorMsg, pos );
				t.trigger( Failure(e) );
			}
			else {
				t.trigger( Success(Noise) );
			}
		});
		return t.asFuture();
	}

	/**
		Transform a NodeJS style async call with one returned value into a surprise.

		This expects an async call which has a callback with a first `error` argument (a string) and a second `data` argument of any type.

		If the error argument is not null, it will return a Failure, with a `tink.core.Error` with the error message and the position of the call that failed.

		If the error argument is null, then the call is assumed to be a success, and the value of the data is returned.

		Please note if both the `error` and `data` arguments are null, then a `Success(null)` will be returned.
	**/
	static public function asSurprise<T>( cb:(Null<String>->Null<T>->Void)->Void, ?pos:PosInfos ):Surprise<T,Error> {
		var t = Future.trigger();
		cb( function(errorMsg:Null<String>,val:Null<T>) {
			if ( errorMsg!=null ) {
				var e = Error.withData( InternalError, errorMsg, pos );
				t.trigger( Failure(e) );
			}
			else {
				t.trigger( Success(val) );
			}
		});
		return t.asFuture();
	}

	/**
		Transform a NodeJS style async call with 2 returned values into a surprise.

		This expects an async call which has a callback with a first `error` argument (a string) and second and third `data` arguments of any type.

		If the error argument is not null, it will return a Failure, with a `tink.core.Error` with the error message and the position of the call that failed.

		If the error argument is null, then the call is assumed to be a success, and a pair containing the data values is returned.

		Please note if both the `error` and `data` arguments are null, then a `Success(Pair(null,null))` will be returned.
	**/
	static public function asSurprisePair<T1,T2>( cb:(Null<String>->Null<T1>->Null<T2>->Void)->Void, ?pos:PosInfos ):Surprise<Pair<T1,T2>,Error> {
		var t = Future.trigger();
		cb( function(errorMsg:Null<String>,val1:Null<T1>,val2:Null<T2>) {
			if ( errorMsg!=null ) {
				var e = Error.withData( InternalError, errorMsg, pos );
				t.trigger( Failure(e) );
			}
			else {
				t.trigger( Success(new Pair(val1,val2)) );
			}
		});
		return t.asFuture();
	}
}
