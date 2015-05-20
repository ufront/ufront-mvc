package ufront.cache;

#if (ufront_orm && server)
import ufront.cache.UFCache;
import ufront.db.Object;
import ufront.api.UFApi;
import sys.db.Types;
import sys.db.TableCreate;
import ufront.core.Futuristic;
using tink.CoreApi;

/**
A `UFCacheConnection` that works with `DBCache`, using a database table to store cache items.
**/
class DBCacheConnection implements UFCacheConnection implements UFCacheConnectionSync {
	public function new() {}

	public function getNamespaceSync( namespace:String ):DBCache
		return new DBCache( namespace );

	public function getNamespace( namespace:String ):DBCache
		return getNamespaceSync( namespace );
}

/**
`DBCache` is a `UFCache` and `UFCacheSync` implementation that saves cached items to a `DBCacheItem` database table.

Each namespace will be differentiated by the `namespace` column on the `DBCacheItem` table.

Only works on `sys` platforms, if compiled with `ufront-orm`.
**/
class DBCache implements UFCache implements UFCacheSync {

	/**
	The namespace of the current cache.
	The cached items will still be stored in the `DBCacheItem` table, but this will set the `namespace` column.
	**/
	public var namespace(default,null):String;

	public function new( namespace:String )
		this.namespace = namespace;

	/** Implementation of `UFCacheSync.getSync()`. **/
	public function getSync( id:String ):Outcome<Dynamic,CacheError> {
		try {
			var item = DBCacheItem.manager.select( namespace==$namespace && $cacheID==id );
			return
				if ( item!=null ) Success( item.data );
				else Failure( ENotInCache );
		}
		catch ( e:Dynamic ) return Failure( ECacheNotReadable('Unable to read from DBCacheItem table: $e') );
	}

	/** Implementation of `UFCacheSync.setSync()`. **/
	public function setSync<T>( id:String, value:T ):Outcome<T,CacheError> {
		try {
			var item = DBCacheItem.manager.select( namespace==$namespace && $cacheID==id );
			if ( item==null )
				item = new DBCacheItem();
			item.namespace = namespace;
			item.cacheID = id;
			item.data = value;
			item.save();
			return Success( value );
		}
		catch ( e:Dynamic ) return Failure( ECacheNotWriteable('Unable to write to DBCacheItem table: $e') );
	}

	/** Implementation of `UFCacheSync.getOrSetSync()`. **/
	public function getOrSetSync<T>( id:String, ?fn:Void->T ):Outcome<Dynamic,CacheError> {
		var getResult = getSync( id );
		return switch getResult {
			case Failure(ENotInCache): setSync( id, fn() );
			case _: getResult;
		}
	}

	/** Implementation of `UFCacheSync.removeSync()`. **/
	public function removeSync( id:String ):Outcome<Noise,CacheError> {
		try {
			DBCacheItem.manager.delete( $namespace==namespace && $cacheID==id );
			return Success(Noise);
		}
		catch ( e:Dynamic ) return Failure( ECacheNotWriteable('Unable to delete item "$id" in namespace "$namespace" from DBCacheItem table: $e') );
	}

	/** Implementation of `UFCacheSync.clearSync()`. **/
	public function clearSync():Outcome<Noise,CacheError> {
		try {
			DBCacheItem.manager.delete( $namespace==namespace );
			return Success(Noise);
		}
		catch ( e:Dynamic ) return Failure( ECacheNotWriteable('Unable to clear "$namespace" items from DBCacheItem table: $e') );
	}

	/** Implementation of `UFCache.get()`. **/
	public function get( id:String ):Surprise<Dynamic,CacheError> {
		return Future.sync( getSync(id) );
	}

	/** Implementation of `UFCache.set()`. **/
	public function set<T>( id:String, value:Futuristic<T> ):Surprise<T,CacheError> {
		return value.map( function(v:T) return setSync(id,v) );
	}

	/** Implementation of `UFCache.getOrSet()`. **/
	public function getOrSet<T>( id:String, ?fn:Void->Futuristic<T> ):Surprise<Dynamic,CacheError> {
		var getResult = getSync( id );
		return switch getResult {
			case Failure(ENotInCache): set( id, fn() );
			case _: Future.sync( getResult );
		}
	}

	/** Implementation of `UFCache.remove()`. **/
	public function remove( id:String ):Surprise<Noise,CacheError> {
		return Future.sync( removeSync(id) );
	}

	/** Implementation of `UFCache.clear()`. **/
	public function clear():Surprise<Noise,CacheError>
		return Future.sync( clearSync() );
}

/**
`DBCacheItem` is a model that saves cached items to a database table.

Different namespaces are differentiated via the `namespace` column.
**/
@:index( namespace )
@:index( namespace, id, unique )
class DBCacheItem extends Object {
	public var namespace:SString<255>;
	public var cacheID:SString<255>;
	public var data:SData<Dynamic>;
}

/**
A simple API to setup and clear `DBCacheItem`s from the database.
**/
class DBCacheApi extends UFApi {
	/** Set up cache table. Returns `true` if the table was newly created, or false if it already existed. **/
	public function setup():Bool {
		if ( TableCreate.exists(DBCacheItem.manager)==false ) {
			TableCreate.create( DBCacheItem.manager );
			return true;
		}
		return false;
	}

	/** Delete all items from the cache. **/
	public function clearAll():Void {
		DBCacheItem.manager.delete( true );
	}

	/** Delete all items from a certain namespace. **/
	public function clearNamespace( namespace:String ):Void {
		DBCacheItem.manager.delete( $namespace==namespace );
	}

	/** Delete a particular item from the cache. **/
	public function clearItem( namespace:String, cacheID:String ):Void {
		DBCacheItem.manager.delete( $namespace==namespace && $cacheID==cacheID );
	}

	/**
	Delete items from the cache where the `cacheID` is "like" the string `cacheIDLike`.
	You can use a "%" character as a wildcard.
	**/
	public function clearItemLike( namespace:String, cacheIDLike:String ):Void {
		DBCacheItem.manager.delete( $namespace==namespace && $cacheID.like(cacheIDLike) );
	}
}

#if ufront_uftasks
	/**
	A simple `UFTaskSet` that allows you to access the API of `DBCacheApi`.

	Only available if compiled with `ufront-orm` and `ufront-uftasks` on a `sys` target.
	**/
	class DBCacheTasks extends ufront.tasks.UFTaskSet {
		@:skip @inject public var api:DBCacheApi;

		/** Run `DBCacheApi.setup()` with the specified parameters. **/
		public function setup():Void api.setup();
		/** Run `DBCacheApi.clearAll()` with the specified parameters. **/
		public function clearAll():Void api.clearAll();
		/** Run `DBCacheApi.clearNamespace()` with the specified parameters. **/
		public function clearNamespace( namespace:String ) api.clearNamespace( namespace );
		/** Run `DBCacheApi.clearItem()` with the specified parameters. **/
		public function clearItem( namespace:String, cacheID:String ) api.clearItem( namespace, cacheID );
		/** Run `DBCacheApi.clearItemLike()` with the specified parameters. **/
		public function clearItemLike( namespace:String, cacheIDLike:String ) api.clearItemLike( namespace, cacheIDLike );
	}
#end

#end
