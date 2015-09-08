package ufront.web.result;

interface WrappedResult<T:ActionResult> {
	public var originalResult:T;
}
