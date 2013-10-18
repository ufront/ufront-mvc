package ufront.core;

import ufront.core.AsyncCallback;
using tink.CoreApi;

/**
	An Async signal implementation that returns a `Future<Noise>` to let you know when the callbacks have been completed.

	It draws concepts from tink's `Signal`, and is built on top of an AsyncCallbackList, and has a similar API, but is not compatible.= with tink's signals.

	One reason for this is that I'm designing it for use in Ufront, where each Signal must be able to be triggered given only the Signal, not a SignalTrigger, unlike tink, which prevents the public from being able to trigger a signal.
**/
abstract AsyncSignal<T>(AsyncCallbackList<T>) from AsyncCallbackList<T> {
	
	public inline function new() this = new AsyncCallbackList();
	
	public inline function handle(handler:AsyncCallback<T>):CallbackLink 
		return this.add(handler);

	public inline function trigger(event:T):Future<AsyncCompletion>
		return this.invoke(event);
	
	public inline function getLength()
		return this.length;
	
	/**
		Dispatch each signal in a chain, passing the specified `val` to each signal.

		Each signal will trigger each of it's handlers, and will wait for those handlers to complete before triggering the next signal in the chain.

		You can optionally specify a `showStopper` function, which will be called before each signal is triggered.  If it does not return true, the chain is terminated early.  Otherwise, the next signal in the chain is called.

		This returns a surprise.  It is triggered/resolved once the final signal has been dispatched and it's handlers have completed.  A `Success` value specifies that every event in the chain was completed, a `Failure` value specifies that the `showStopper` function terminated the chain early.  Once this surprise has been triggered, you can be sure that no event handlers are still running from this dispatchChain.
	**/
	public static function dispatchChain<A>( val:A, chain:Array<AsyncSignal<A>>, ?showStopper:Void->Bool ):Future<AsyncCompletion> {
		var allDone = Future.trigger();
		chain = chain.copy();
		
		function triggerNextSignal( signal:AsyncSignal<A> ) {
			if ( showStopper!=null && showStopper() ) 
				allDone.trigger( Aborted );
			else {
				signal.trigger( val ).handle(function(resultFromCallbacks) {
					switch resultFromCallbacks {
						case Completed:
							signal = chain.shift();
							if ( signal==null ) 
								allDone.trigger( Completed );
							else
								triggerNextSignal( signal );
						default:
							allDone.trigger( resultFromCallbacks );
					}
				});
			}
		};

		var signal = chain.shift();
		if ( signal==null ) 
			allDone.trigger( Completed );
		else
			triggerNextSignal( signal );

		return allDone;
	}
}