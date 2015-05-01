package ufront.web.url.filter;
import thx.error.NullArgument;
import ufront.web.context.HttpRequest;
import thx.Error;
using StringTools;

/**
	A URL filter that can be used to limit allowed parameters on a URL.

	TODO: decide if this overlaps with our routing's functionality. Is it needed anymore?
	TODO: document further
**/
class SegmentToParamUrlFilter implements UFUrlFilter
{
	public var defaultValue : String;
	public var allowedValues : Array<String>;
 	public var paramName : String;

	public function new(paramName : String, allowedValues : Array<String>, ?defaultValue : String) {
		NullArgument.throwIfNull(paramName);
		NullArgument.throwIfNull(allowedValues);
		this.paramName = paramName;
		this.defaultValue = defaultValue;
		this.allowedValues = allowedValues;
	}

	public function filterIn(url : PartialUrl, request : HttpRequest) {
		if( allowedValues.indexOf(url.segments[0]) > -1 ) {
			var value = url.segments.shift();
			request.query.set(paramName, value);
		}
	}

	public function filterOut(url : VirtualUrl, request : HttpRequest) {
		var params = url.query;
		if(params.exists(paramName)) {
			var value = params.get(paramName).value;
			if( allowedValues.indexOf(value) == -1 )
				return;
			params.remove(paramName);
			if(value != defaultValue)
				url.segments.unshift(value);
		}
	}
}
