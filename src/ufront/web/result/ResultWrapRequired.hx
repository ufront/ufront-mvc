package ufront.web.result;

/**
A collection of flags describing operations that are required to wrap any controller return type into a `FutureActionOutcome`.

In our `Controller.execute()` methods, we return a consistent `Future<Outcome<ActionResult,tink.core.Error>>` type, despite the return type of the method/action executed.

This is used by the `Controller` build macro, and the `Controller.execute()` method in conjunction with `haxe.EnumFlags` to know which wrapping operations are required on a given result.
**/
enum ResultWrapRequired {
	/** The return type was synchronous, and must be wrapped in a `Future`. **/
	WRFuture;
	/** The return type was not an `Outcome`, and must be wrapped in either `Outcome.Success` or `Outcome.Failure`. **/
	WROutcome;
	/**
	The return type was not an `ActionResult` (or on the failure case, a `tink.core.Error`).
	It must be wrapped into the appropriate object.
	**/
	WRResultOrError;
}
