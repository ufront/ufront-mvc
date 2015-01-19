package ufront.cache;

import tink.CoreApi;
import ufront.core.Futuristic;

interface UFCacheConnection<T> {
	public function getNamespace( namespace:String ):UFCache<T>;
}

interface UFCache<T> {
	public function get( id:String ):Surprise<T,CacheError>;
	public function set( id:String, value:Futuristic<T> ):Surprise<T,CacheError>;
	public function getOrSet( id:String, ?fn:Void->Futuristic<T> ):Surprise<T,CacheError>;
	public function clear():Surprise<Noise,CacheError>;
}

interface UFCacheSync<T> {
	public function getSync( id:String ):Outcome<T,CacheError>;
	public function setSync( id:String, value:T ):Outcome<T,CacheError>;
	public function getOrSetSync( id:String, ?fn:Void->T ):Outcome<T,CacheError>;
	public function clearSync():Outcome<Noise,CacheError>;
}

enum CacheError {
	ENotInCache;
	EUnableToConnect(err:String);
	ECacheNotReadable(err:String);
	ECacheNotWriteable(err:String);
}
