package ufront.middleware;

import ufront.web.context.HttpContext;
import ufront.web.context.HttpResponse;
import ufront.app.UFMiddleware;
import ufront.core.Sync;
import ufront.cache.UFCache;
import haxe.rtti.Meta;
using tink.CoreApi;

/**
	A very simple request caching middleware.

	At the end of a request, if a the controller / action had the `@cacheRequest` metadata, the response will be cached.

	At the start of a request, if the URI matches an already matched request, the response from the cache will be used and no further processing is required.

	@author Jason O'Neil
**/
class RequestCacheMiddleware implements UFMiddleware
{
	public static var contentTypesToCache:Array<String> = [
		"text/plain",
		"text/html",
		"text/xml",
		"text/css",
		"text/csv",
		"application/json",
		"application/javascript",
		"application/atom+xml",
		"application/rdf+xml",
		"application/rss+xml",
		"application/soap+xml",
		"application/xhtml+xml",
		"application/xml",
		"application/xml-dtd"
	];
	/**
		The cache system to use.

		Will be injected by the `ufront.app.HttpApplication` when the middleware is added.
	**/
	@inject public var cacheConnection:UFCacheConnection<HttpResponse>;

	var cache:UFCache<HttpResponse>;

	public function new() {
	}

	/**
		See if a cache exists for this URI.
		If it does, mirror the cached request and mark the request as complete.
	**/
	public function requestIn( ctx:HttpContext ):Surprise<Noise,Error> {
		if ( cache==null ) {
			cache = cacheConnection.getNamespace("ufront.middleware.RequestCache");
		}
		if ( ctx.request.httpMethod.toLowerCase()=="get" ) {
			var uri = ctx.request.uri;
			var keys:Iterator<String> = untyped cache.map.keys();
			return cache.get( uri ).map(function(result) {
				switch result {
					case Success(cachedResponse):
						ctx.ufTrace( 'Loading $uri from cache' );
						ctx.response.clearContent();
						ctx.response.contentType = cachedResponse.contentType;
						ctx.response.redirectLocation = cachedResponse.redirectLocation;
						ctx.response.charset = cachedResponse.charset;
						ctx.response.status = cachedResponse.status;
						for ( c in cachedResponse.getCookies() ) {
							ctx.response.setCookie( c );
						}
						var headers = cachedResponse.getHeaders();
						for ( key in headers.keys() ) {
							ctx.response.setHeader( key, headers.get(key) );
						}
						ctx.response.write( cachedResponse.getBuffer() );
						ctx.completion.set(CRequestHandlersComplete);
					default:
						// Silently ignore
				}
				return Success( Noise );
			});
		}
		else return Sync.success();
	}

	/**
		Check if the request was cacheable.  If it was, attempt to cache it.
	**/
	public function responseOut( ctx:HttpContext ):Surprise<Noise,Error> {
		// If it's a get request and we have data about the controller/action used
		if ( ctx.request.httpMethod.toLowerCase()=="get" && ctx.actionContext!=null && ctx.actionContext.controller!=null && ctx.actionContext.action!=null ) {

			// If it's one of our approved content types.
			if ( contentTypesToCache.indexOf(ctx.response.contentType)>-1 ) {
				var controller = ctx.actionContext.controller;
				var cls = Type.getClass( controller );
				var controllerMeta = Meta.getType( cls );
				var fieldMeta = Reflect.field( Meta.getFields(cls), ctx.actionContext.action );

				if ( hasCacheMeta(controllerMeta) || hasCacheMeta(fieldMeta) ) {
					var uri = ctx.request.uri;
					return cache.set( uri, ctx.response ) >> function(result:Outcome<HttpResponse,CacheError>):Outcome<Noise,Error> {
						switch result {
							case Failure(e):
								// This isn't fatal, so just log the error and continue.
								ctx.ufError( 'Failed to save cache for $uri: $e' );
							default:
						}
						var keys:Iterator<String> = untyped cache.map.keys();
						return Success( Noise );
					}
				}
			}
		}
		return Sync.success();
	}

	/**
		Clear all cached pages.
	**/
	public function invalidate():Surprise<Noise,CacheError> {
		return cache.clear();
	}

	static var metaName = "cacheRequest";
	static function hasCacheMeta( meta:Dynamic<Array<Dynamic>> ) {
		return Reflect.hasField(meta,metaName);
	}
}
