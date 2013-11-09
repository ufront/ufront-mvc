package ufront.cache;

import tink.CoreApi;
import ufront.core.Futuroid;

interface UFCacheConnection<T> {
	public function for( namespace:String ):UFCache<T>
}

interface UFCache<T> {
	public function get( id:String ):Surprise<T,CacheError>;
	public function set( id:String, value:Futuroid<T> ):Surprise<T,CacheError>;
	public function getOrSet( id:String, ?fn:Void->Futuroid<T> );
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