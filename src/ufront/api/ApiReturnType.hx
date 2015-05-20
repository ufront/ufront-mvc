package ufront.api;

/**
A set of flags that indicates if a `UFApi` returns a `Future`, an `Outcome`, a `Void` or a combination of these.
**/
enum ApiReturnType {
	ARTFuture;
	ARTOutcome;
	ARTVoid;
}
