package ufront.cache;

import tink.CoreApi;
import ufront.core.Futuristic;

interface UFCacheConnection {
	public function getNamespace( namespace:String ):UFCache;
}

interface UFCacheConnectionSync {
	public function getNamespaceSync( namespace:String ):UFCacheSync;
}

interface UFCache {
	public function get( id:String ):Surprise<Dynamic,CacheError>;
	public function set<T>( id:String, value:Futuristic<T> ):Surprise<T,CacheError>;
	public function getOrSet<T>( id:String, ?fn:Void->Futuristic<T> ):Surprise<Dynamic,CacheError>;
	public function clear():Surprise<Noise,CacheError>;
}

interface UFCacheSync {
	public function getSync( id:String ):Outcome<Dynamic,CacheError>;
	public function setSync<T>( id:String, value:T ):Outcome<T,CacheError>;
	public function getOrSetSync<T>( id:String, ?fn:Void->T ):Outcome<Dynamic,CacheError>;
	public function clearSync():Outcome<Noise,CacheError>;
}

enum CacheError {
	ENotInCache;
	EUnableToConnect(err:String);
	ECacheNotReadable(err:String);
	ECacheNotWriteable(err:String);
}
