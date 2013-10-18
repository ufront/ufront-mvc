package ufront.core;

using tink.CoreApi;

/**
	Similar to `tink.core.Callback`, except it allows for a function which has async execution to inform us when it is completed.

	Auto casts from:

	- `Void->Void` - no argument, sync
	- `A->Void` - argument, sync
	- `Void->Future<AsyncCompletion>` - no argument, async
	- `A->Future<AsyncCompletion>` - argument, async
**/
abstract AsyncCallback<T>( T->Future<AsyncCompletion> ) from T->Future<AsyncCompletion> {
	inline function new( f ) 
		this = f;
	
	public inline function invoke( data:T ):Future<AsyncCompletion>
		return (this)( data );
	
	@:from static inline function fromSync<A>( f:A->Void ):AsyncCallback<A> 
		return new AsyncCallback( function (v) { f(v); return COMPLETED; } );
	
	@:from static inline function fromNiladic<A>(f:Void->Future<AsyncCompletion>):AsyncCallback<A> 
		return new AsyncCallback( function (v) return f() );
	
	@:from static inline function fromNiladicSync<A>(f:Void->Void):AsyncCallback<A> 
		return new AsyncCallback( function (v) { f(); return COMPLETED; } );
	
	@:from static function fromMany<A>(callbacks:Array<AsyncCallback<A>>):AsyncCallback<A> 
		return
			function ( v:A ) {
				var futures = [];
				for ( callback in callbacks )
					futures.push( callback.invoke(v) );
				return Future.ofMany( futures ).map(function(results) {
					for ( r in results )
						if ( !Type.enumEq(r,Completed) ) return r;
					return Completed;
				});
			}

	public static var COMPLETED = Future.sync(Completed);
}

/**
	Similar to `tink.core.Callback.Cell`, except uses `AsyncCallback` instead of `Callback`
**/
private class AsyncCell<T> {
	public var cb:AsyncCallback<T>;
	
	function new() {}
	
	public inline function free():Void {
		this.cb = null;
		pool.push( this );
	}
	
	static var pool:Array<AsyncCell<Dynamic>> = [];
	
	static public inline function get<A>():AsyncCell<A> 
		return
			if ( pool.length>0 ) cast pool.pop();
			else new AsyncCell();
}

/**
	Similar to `tink.core.CallbackList`, except uses `AsyncCallback<T>` instead of `Callback<T>`
**/
abstract AsyncCallbackList<T>( Array<AsyncCell<T>> ) {
	
	public var length(get, never):Int;
	
	public inline function new():Void
		this = [];
	
	inline function get_length():Int 
		return this.length;	
	
	public function add( cb:AsyncCallback<T> ):CallbackLink {
		var cell = AsyncCell.get();
		cell.cb = cb;
		this.push(cell);
		return function () {
			if ( this.remove(cell) )
				cell.free();
			cell = null;
		}
	}
		
	public function invoke( data:T ):Future<AsyncCompletion> {
		var futures = [];
		try {
			for ( cell in this.copy() ) 
				if ( cell.cb!=null ) //This occurs when an earlier cell in this run dissolves the link for a later cell - usually a sign of convoluted code, but who am I to judge
					futures.push( cell.cb.invoke(data) );
		}
		catch ( e:Dynamic ) {
			return Future.sync( Error(e) );
		}
		return Future.ofMany( futures ).map(function(results) {
			for ( r in results )
				if ( !Type.enumEq(r,Completed) ) return r;
			return Completed;
		});
	}
			
	public function clear():Void 
		for ( cell in this.splice(0, this.length) )
			cell.free();
}

enum AsyncCompletion {
	/** All callbacks finished **/
	Completed;

	/** There was an error executing one of the callbacks.  Execution may have stopped **/
	Error( e:Dynamic );
	
	/** The callbacks were not all executed.  The execution was stopped deliberately. **/
	Aborted;
}