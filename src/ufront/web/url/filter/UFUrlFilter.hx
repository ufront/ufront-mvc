package ufront.web.url.filter;
import ufront.web.context.HttpRequest;

/**
Interface for defining new Url filters.

These filters are used in `HttpContext.getRequestUri()` and `HttpContext.generateUri()`.
**/
interface UFUrlFilter {
	/**
	Filter a raw URI from the web server into a normalized state for our web app to handle.

	For example:

	- Changing `index.n/home/` to `/home/` (as in `PathInfoUrlFilter`).
	- Changing `/path/to/app/item/34/` to `/item/34/` (as in `DirectoryUrlFilter`).
	**/
	public function filterIn( url:PartialUrl ):Void;

	/**
	Transform a normalized URI from the app into a raw URI that fits the current server environment.

	For example:

	- Changing `/home/` to `index.n/home/` (as in `PathInfoUrlFilter`).
	- Changing `/item/34/` to `/path/to/app/item/34/` (as in `DirectoryUrlFilter`).
	**/
	public function filterOut( url:VirtualUrl ):Void;
}
