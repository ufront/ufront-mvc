package ufront.cache;

import tink.CoreApi;
import ufront.core.Futuristic;
import ufront.cache.UFCache;

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

class MemoryCache implements UFCache implements UFCacheSync {

	var map:Map<String,Dynamic>;

	public function new()
		map = new Map();

	public function getSync( id:String ):Outcome<Dynamic,CacheError>
		return
			if ( map.exists(id) )
				Success( map[id] )
			else
				Failure( ENotInCache );

	public function setSync<T>( id:String, value:T ):Outcome<T,CacheError>
		return Success( map[id] = value );

	public function getOrSetSync<T>( id:String, ?fn:Void->T ):Outcome<Dynamic,CacheError>
		return
			if ( map.exists(id) )
				Success( map[id] )
			else
				Success( map[id] = fn() );

	public function clearSync():Outcome<Noise,CacheError> {
		map = new Map();
		return Success(Noise);
	}

	public function get( id:String ):Surprise<Dynamic,CacheError>
		return Future.sync( getSync(id) );

	public function set<T>( id:String, value:Futuristic<T> ):Surprise<T,CacheError>
		return value.map( function(v:T) return Success(map[id]=v) );

	public function getOrSet<T>( id:String, ?fn:Void->Futuristic<T> ):Surprise<Dynamic,CacheError>
		return
			if ( map.exists(id) )
				Future.sync( Success(map[id]) )
			else
				fn().map( function(v:T) return Success(map[id]=v) );

	public function clear():Surprise<Noise,CacheError>
		return Future.sync( clearSync() );
}
