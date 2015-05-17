package ufront.cache;

import tink.CoreApi;
import ufront.core.Futuristic;
import ufront.cache.UFCache;

/** A `UFCacheConnection` that works with `MemoryCache`. **/
class MemoryCacheConnection implements UFCacheConnection implements UFCacheConnectionSync {
	var caches:Map<String,MemoryCache>;

	public function new()
		caches = new Map();

	public function getNamespaceSync( namespace:String ):MemoryCache
		return
			if ( caches.exists(namespace) )
				caches[namespace]
			else
				caches[namespace] = new MemoryCache();

	public function getNamespace( namespace:String ):MemoryCache
		return getNamespaceSync( namespace );
}

/**
A `UFCache` and `UFCacheSync` implementation that works by using a `Map<String,Dynamic>` that can persist through requests.

Caveats:

- Some platforms do not keep static variables initialised between requests. For example PHP will never keep cached items between requests.
- Neko must be using `neko.Web.cacheModule()` to keep the cache alive between requests.
- This does not use the memory sharing tools in `mod_tora`. As such a different cache may be kept for each thread handling requests.
- This may lead to high memory usage if the data is not cleared occasionally. Use with care.
**/
class MemoryCache implements UFCache implements UFCacheSync {

	var map:Map<String,Dynamic>;

	public function new()
		map = new Map();

	/** Implementation of `UFCacheSync.getSync()`. **/
	public function getSync( id:String ):Outcome<Dynamic,CacheError>
		return
			if ( map.exists(id) )
				Success( map[id] )
			else
				Failure( ENotInCache );

	/** Implementation of `UFCacheSync.setSync()`. **/
	public function setSync<T>( id:String, value:T ):Outcome<T,CacheError>
		return Success( map[id] = value );

	/** Implementation of `UFCacheSync.getOrSetSync()`. **/
	public function getOrSetSync<T>( id:String, ?fn:Void->T ):Outcome<Dynamic,CacheError>
		return
			if ( map.exists(id) )
				Success( map[id] )
			else
				Success( map[id] = fn() );

	/** Implementation of `UFCacheSync.removeSync()`. **/
	public function removeSync( id:String ):Outcome<Noise,CacheError> {
		map.remove( id );
		return Success(Noise);
	}

	/** Implementation of `UFCacheSync.clearSync()`. **/
	public function clearSync():Outcome<Noise,CacheError> {
		map = new Map();
		return Success(Noise);
	}

	/** Implementation of `UFCache.get()`. **/
	public function get( id:String ):Surprise<Dynamic,CacheError>
		return Future.sync( getSync(id) );

	/** Implementation of `UFCache.set()`. **/
	public function set<T>( id:String, value:Futuristic<T> ):Surprise<T,CacheError>
		return value.map( function(v:T) return Success(map[id]=v) );

	/** Implementation of `UFCache.getOrSet()`. **/
	public function getOrSet<T>( id:String, ?fn:Void->Futuristic<T> ):Surprise<Dynamic,CacheError>
		return
			if ( map.exists(id) )
				Future.sync( Success(map[id]) )
			else
				fn().map( function(v:T) return Success(map[id]=v) );

	/** Implementation of `UFCache.remove()`. **/
	public function clear():Surprise<Noise,CacheError>
		return Future.sync( clearSync() );

	/** Implementation of `UFCache.clear()`. **/
	public function remove( id:String ):Surprise<Noise,CacheError>
		return Future.sync( removeSync(id) );
}
