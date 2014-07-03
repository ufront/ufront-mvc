package ufront.core;

import haxe.PosInfos;
import tink.core.Error;
using tink.CoreApi;

class SurpriseTools {

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