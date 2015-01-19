package ufront.cache;

import tink.CoreApi;
import ufront.core.Futuristic;
import ufront.cache.UFCache;

class MemoryCacheConnection<T> implements UFCacheConnection<T> {
	var caches:Map<String,MemoryCache<T>>;

	public function new()
		caches = new Map();

	public function getNamespace( namespace:String ):UFCache<T>
		return
			if ( caches.exists(namespace) )
				caches[namespace]
			else
				caches[namespace] = new MemoryCache();
}

class MemoryCache<T> implements UFCache<T> implements UFCacheSync<T> {

	var map:Map<String,T>;

	public function new()
		map = new Map();

	public function getSync( id:String ):Outcome<T,CacheError>
		return
			if ( map.exists(id) )
				Success( map[id] )
			else
				Failure( ENotInCache );

	public function setSync( id:String, value:T ):Outcome<T,CacheError>
		return Success( map[id] = value );

	public function getOrSetSync( id:String, ?fn:Void->T ):Outcome<T,CacheError>
		return
			if ( map.exists(id) )
				Success( map[id] )
			else
				Success( map[id] = fn() );

	public function clearSync():Outcome<Noise,CacheError> {
		map = new Map();
		return Success(Noise);
	}

	public function get( id:String ):Surprise<T,CacheError>
		return Future.sync( getSync(id) );

	public function set( id:String, value:Futuristic<T> ):Surprise<T,CacheError>
		return value.map( function(v:T) return Success(map[id]=v) );

	public function getOrSet( id:String, ?fn:Void->Futuristic<T> ):Surprise<T,CacheError>
		return
			if ( map.exists(id) )
				Future.sync( Success(map[id]) )
			else
				fn().map( function(v:T) return Success(map[id]=v) );

	public function clear():Surprise<Noise,CacheError>
		return Future.sync( clearSync() );
}
