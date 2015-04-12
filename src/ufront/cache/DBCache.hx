package ufront.cache;

#if ufront_orm
import ufront.cache.UFCache;
import ufront.db.Object;
import sys.db.Types;
import ufront.core.Futuristic;
using tink.CoreApi;

/**
A `UFCacheConnection` that works with `DBCache`, using a database table to store cached results.
**/
class DBCacheConnection implements UFCacheConnection implements UFCacheConnectionSync {
	public function new() {}

	public function getNamespaceSync( namespace:String ):DBCache
		return new DBCache( namespace );

	public function getNamespace( namespace:String ):DBCache
		return getNamespaceSync( namespace );
}

/**
A `UFCache` and `UFCacheSync` implementation that saves cached items to a `DBCacheItem` database table.

Only works on sys platforms, if compiled with `ufront-orm`.
**/
class DBCache implements UFCache implements UFCacheSync {

	var namespace:String;

	public function new( namespace:String )
		this.namespace = namespace;

	public function getSync( id:String ):Outcome<Dynamic,CacheError> {
		try {
			var item = DBCacheItem.manager.select( namespace==$namespace && $cacheID==id );
			return
				if ( item!=null ) Success( cast item.data );
				else Failure( ENotInCache );
		}
		catch ( e:Dynamic ) return Failure( ECacheNotReadable('Unable to read from DBCacheItem table: $e') );
	}

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

	public function getOrSetSync<T>( id:String, ?fn:Void->T ):Outcome<Dynamic,CacheError> {
		var getResult = getSync( id );
		return switch getResult {
			case Failure(ENotInCache): setSync( id, fn() );
			case _: getResult;
		}
	}

	public function clearSync():Outcome<Noise,CacheError> {
		try {
			DBCacheItem.manager.delete( $namespace==namespace );
			return Success(Noise);
		}
		catch ( e:Dynamic ) return Failure( ECacheNotWriteable('Unable to clear "$namespace" items frpm DBCacheItem table: $e') );
	}

	public function get( id:String ):Surprise<Dynamic,CacheError> {
		return Future.sync( getSync(id) );
	}

	public function set<T>( id:String, value:Futuristic<T> ):Surprise<T,CacheError> {
		return value.map( function(v:T) return setSync(id,v) );
	}

	public function getOrSet<T>( id:String, ?fn:Void->Futuristic<T> ):Surprise<Dynamic,CacheError> {
		var getResult = getSync( id );
		return switch getResult {
			case Failure(ENotInCache): set( id, fn() );
			case _: Future.sync( getResult );
		}
	}

	public function clear():Surprise<Noise,CacheError>
		return Future.sync( clearSync() );
}

@:index( namespace )
@:index( namespace, id, unique )
class DBCacheItem extends Object {
	public var namespace:SString<255>;
	public var cacheID:SString<255>;
	public var data:SData<Dynamic>;
}
#end
