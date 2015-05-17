package ufront.cache;

import tink.CoreApi;
import ufront.core.Futuristic;

/**
A `UFCacheConnection` is used to give you a `UFCache` for a particular namespace.

Usually you will inject a `UFCacheConnection` into your application injector, and then various parts of your application can request a cache for their given namespace.

If you use a cache implementation that can function both synchronously and asynchronously, it may be wise to inject both `UFCacheConnection` and `UFCacheConnectionSync`.
**/
interface UFCacheConnection {
	/** Get a `UFCache` instance for a particular namespace. **/
	public function getNamespace( namespace:String ):UFCache;
}

/**
A `UFCacheConnectionSync` is used to give you a `UFCacheSync` for a particular namespace.

Usually you will inject a `UFCacheConnectionSync` into your application injector, and then various parts of your application can request a cache for their given namespace.

If you use a cache implementation that can function both synchronously and asynchronously, it may be wise to inject both `UFCacheConnection` and `UFCacheConnectionSync`.
**/
interface UFCacheConnectionSync {
	/** Get a `UFCacheSync` instance for a particular namespace. **/
	public function getNamespaceSync( namespace:String ):UFCacheSync;
}

/**
A `UFCache` is an interface that describes a basic asynchronous caching system that can be used in Ufront projects.

Writing against the `UFCache` interface rather than a specific implementation allows you to support multiple caching solutions.
This means you can change your cache technology at a later date without needing to rewrite your code.
It also allows libraries to write code that will work regardless of cache technology - see for example `CacheSession`.

`UFCache` has methods that are designed to work asynchronously and return a `Surprise`.
If you prefer to work with synchronous methods, you can use a `UFCacheSync` instead.
**/
interface UFCache {
	/** Fetch a cached item with a given ID. **/
	public function get( id:String ):Surprise<Dynamic,CacheError>;

	/** Set an item in the cache with a given ID and value. The value provided can be a regular value or a future. **/
	public function set<T>( id:String, value:Futuristic<T> ):Surprise<T,CacheError>;

	/**
	Attempt to get an item from a cache.
	If it is not found, use a function to generate the value and save that value to the cache for next time.
	The function may return a regular value or a future.
	**/
	public function getOrSet<T>( id:String, ?fn:Void->Futuristic<T> ):Surprise<Dynamic,CacheError>;

	/** Remove a cached item with a given ID. **/
	public function remove( id:String ):Surprise<Noise,CacheError>;

	/** Clear all items in this cache / namespace. **/
	public function clear():Surprise<Noise,CacheError>;
}

/**
`UFCacheSync` is an interface describing a basic synchronous caching system that can be used in Ufront projects.

Similar to `UFCache`, this allows you to write code against an interface, and support multiple caching solutions.

The primary difference is that `UFCacheSync` methods run synchronously, and return an `Outcome` rather than a `Future`.
If you are confident that your target platform performs mostly synchronous operations (eg. Neko or PHP), then using `UFCacheSync` allows you to avoid having to handle asynchronous code.
**/
interface UFCacheSync {
	/** Fetch a cached item with a given ID synchronously. **/
	public function getSync( id:String ):Outcome<Dynamic,CacheError>;

	/** Set an item in the cache with a given ID and value synchronously. **/
	public function setSync<T>( id:String, value:T ):Outcome<T,CacheError>;

	/**
	Attempt to get an item from a cache.
	If it is not found, use a function to generate the value and save that value to the cache for next time.
	This operation is synchronous.
	**/
	public function getOrSetSync<T>( id:String, ?fn:Void->T ):Outcome<Dynamic,CacheError>;

	/** Remove a cached item with a given ID synchronously. **/
	public function removeSync<T>( id:String ):Outcome<Noise,CacheError>;

	/** Clear all items in this cache / namespace synchronously. **/
	public function clearSync():Outcome<Noise,CacheError>;
}

/**
A selection of errors that can occur in a `UFCache` or `UFCacheSync` implementation.
**/
enum CacheError {
	/** The requested item did not exist in the cache. **/
	ENotInCache;

	/** An attempt to connect to the cache failed. **/
	EUnableToConnect(err:String);

	/** An attempt to read from the cache failed. **/
	ECacheNotReadable(err:String);

	/** An attempt to write to the cache failed. **/
	ECacheNotWriteable(err:String);

}
