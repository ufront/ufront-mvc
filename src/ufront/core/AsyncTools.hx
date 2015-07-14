package ufront.core;

#if macro
	import haxe.macro.Expr;
	import haxe.macro.Context;
	using haxe.macro.Tools;
#else
	import haxe.PosInfos;
	import tink.core.Error;
	import ufront.web.HttpError;
	using tink.CoreApi;
#end

/**
Tools to help create, transform and respond to `Future` values.

This class is designed for use with static extension: `using ufront.core.AsyncTools;`.
**/
class FutureTools {
	#if !macro
		/** Wrap a value in `Future.sync(data)` **/
		public static inline function asFuture<T>( data:T ):Future<T>
			return Future.sync( data );
	#end

	/**
	This helper macro allows you to wait for many futures, and handle them in a single type safe function.

	This works by creating a `combinedFuture:Future<Dynamic> = Future.ofMany([...])`.
	It then returns an object with `handle()` and `map()` functions, with the expected callback types being tailored to the types of your promises.

	```
	var f1 = Future.sync("Jason");
	var f2 = Future.sync(26);
	var f3 = Future.sync(Success(Noise));

	FutureTools.when(f1,f2,f3).handle(function(name,age,outcome) {
		trace('Name: $name');
		trace('Age next year: ${age+1}');
		trace('Outcome is success: '+outcome.match(Success(_)));
	});
	var sentanceFuture = FutureTools.when(f1,f2,f3).map(function(name,age,outcome) {
		return '$name is $age years old and is a ${Type.enumConstructor(outcome)}.';
	});
	sentanceFuture.handle(function(sentence:String) trace(sentence));
	```

	You can use as many or as few promises as you like.

	The compiler will ensure all arguments are handled in a type safe manner.

	Note: If at the time this macro is called, Haxe does not know the complete type signiature of each promise, the macro will print a warning asking for more type hints.
	**/
	public static macro function when( args:Array<Expr> ) {
		var arrayOfFutures = macro ($a{args}:Array<tink.core.Future<Dynamic>>);
		var arrayOfTypes = [];
		var arrayOfCallArgs = [];
		var i = 0;
		for (arg in args) {
			arrayOfCallArgs.push( macro values[$v{i}] );
			switch Context.typeof( arg ).follow() {
				case TAbstract(_.get() => {name:"Future",pack:["tink","core"]}, params) if (params.length==1):
					var ct = params[0].follow().toComplexType();
					// The ComplexType may be null if it was a monomorph (`Unknown<0>` etc). Provide a warning.
					if ( ct==null ) {
						var msg = 'The type parameter for "${arg.toString()}" was not known when the macro was called. Please add a type hint.';
						Context.warning(msg, arg.pos);
						arrayOfTypes.push( macro :Dynamic );
					}
					else arrayOfTypes.push( ct );
				case otherType:
					var msg = 'Expected argument "${arg.toString()}" to be of type "tink.core.Future<T>", but was "${otherType.toString()}"';
					Context.error(msg, arg.pos);
			}
			i++;
		}

		var handleCBType = TFunction(arrayOfTypes,macro :Void);
		var handleFunction = macro function handle(cb:$handleCBType) {
			combinedFuture.handle(function(values:Array<Dynamic>) {
				cb( $a{arrayOfCallArgs} );
			});
		}

		var mapCBType = TFunction(arrayOfTypes,macro :T);
		var mapFunction = macro function map<T>(cb:$mapCBType):tink.core.Future<T> {
			return combinedFuture.map(function(values:Array<Dynamic>) {
				return cb( $a{arrayOfCallArgs} );
			});
		}

		var expr = macro {
			var combinedFuture = tink.core.Future.ofMany( $arrayOfFutures );
			$handleFunction;
			$mapFunction;
			// Return an object with `handle()` and `map()` methods.
			{ handle: handle, map: map };
		};
		return expr;
	}
}

/**
Tools to help create, transform and respond to `Surprise` values.

This class is designed for use with static extension: `using ufront.core.AsyncTools;`.
**/
class SurpriseTools {
	#if !macro
		/** Return a `Surprise<Noise,T>` success. **/
		public static function success<F>():Surprise<Noise,F> {
			if ( s==null ) s = Future.sync( Success(Noise) );
			return cast s;
		}
		static var s:Surprise<Noise,Dynamic>;

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

		/**
		Attempt to execute a function that returns a synchronous value.
		If the function succeeds, the returned value is used as a Success.
		If an exception is thrown, the exception value is used as a Failure.
		**/
		public static function tryCatchSurprise<D>( fn:Void->D, ?msg:String, ?p:Pos ):Surprise<D,Error> {
			return try
				asGoodSurprise( fn() )
			catch ( e:Dynamic )
				asSurpriseError( e, msg, p );
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

		/** If a surprise returns a Failure, use a fallback value instead. This results in a Future rather than a Surprise. **/
		public static function useFallback<D,F>( s:Surprise<D,F>, fallback:D ):Future<D> {
			return s.map(function(outcome) return switch outcome {
				case Failure(_): fallback;
				case Success(data): data;
			});
		}
	#end
}

/**
Tools to help transform callbacks into surprises.

This class is designed for use with static extension: `using ufront.core.AsyncTools;`.
**/
class CallbackTools {
	#if !macro
		/**
		Transform a NodeJS style async call with no returned values into a surprise.

		This expects an async call which has a callback with a single `error` argument.

		If the error argument is not null, it will return a Failure, with a `tink.core.Error` with the error message and the position of the call that failed.

		If the error argument is null, then the call is a `Success( Noise )`.
		**/
		static public function asVoidSurprise<TError>( cb:(Null<TError>->Void)->Void, ?pos:PosInfos ):Surprise<Noise,Error> {
			var t = Future.trigger();
			cb( function(error:Null<TError>) {
				if ( error!=null ) {
					var e = Error.withData( InternalError, '$error', pos );
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
		static public function asSurprise<TError,TData>( cb:(Null<TError>->Null<TData>->Void)->Void, ?pos:PosInfos ):Surprise<TData,Error> {
			var t = Future.trigger();
			cb( function(error:Null<TError>,val:Null<TData>) {
				if ( error!=null ) {
					var e = Error.withData( InternalError, '$error', pos );
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
		static public function asSurprisePair<TError,TData1,TData2>( cb:(Null<TError>->Null<TData1>->Null<TData2>->Void)->Void, ?pos:PosInfos ):Surprise<Pair<TData1,TData2>,Error> {
			var t = Future.trigger();
			cb( function(error:Null<TError>,val1:Null<TData1>,val2:Null<TData2>) {
				if ( error!=null ) {
					var e = Error.withData( InternalError, '$error', pos );
					t.trigger( Failure(e) );
				}
				else {
					t.trigger( Success(new Pair(val1,val2)) );
				}
			});
			return t.asFuture();
		}
	#end
}
