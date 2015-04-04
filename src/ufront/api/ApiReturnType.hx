package ufront.api;

/**
A set of flags that indicates if a `UFApi` returns a `Future`, `Outcome`, `Void` or combination of these.
**/
enum ApiReturnType {
	ARTFuture;
	ARTOutcome;
	ARTVoid;
}
