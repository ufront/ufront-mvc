package ufront.view;

import haxe.ds.Option;
import haxe.Http;
using tink.CoreApi;
using haxe.io.Path;
using StringTools;
/**
A `UFViewEngine` that loads views over HTTP.

This is especially useful when running applications client-side, as it allows you to share a view directory with the server and access it via HTTP rather than the filesystem.
**/
class HttpViewEngine extends UFViewEngine {

	/**
	Create a new HttpViewEngine.

	@param cachingEnabled Should we cache templates between requests? If not supplied, the value of `UFViewEngine.cacheEnabledByDefault` will be used by default.
	**/
	public function new( ?cachingEnabled=null ) {
		super( cachingEnabled );
	}

	/**
	The path to your views as an absolute HTTP URI.
	eg `http://ufront.net/views/`

	This value should be provided by dependency injection (a String named `viewPath`).
	**/
	@inject("viewPath") public var viewPath:String;

	/**
	Attempt to load the view via a HTTP call.

	The `relativeViewPath` is relative to the URL specified in `viewPath`.
	A leading "/" will be ignored.

	- If a status code of `200` is returned, then the content of the HTTP response is used as the template.
	- If a status code of 404 is returned, then a `Success(None)` is triggered - meaning no error was encountered, but the template did not exist.
	- If a different status code is returned, it is considered an error and a `Failure(err)` is returned.
	**/
	override public function getTemplateString( relativeViewPath:String ):Surprise<Option<String>,Error> {
		if ( relativeViewPath.startsWith("/") )
			relativeViewPath = relativeViewPath.substr( 1 );
		var fullPath = viewPath.addTrailingSlash()+relativeViewPath;
		try {
			var ft = Future.trigger();
			var req = new Http( fullPath );
			var status:Int = -1;
			req.onStatus = function( st ) status = st;
			req.onData = function( data ) ft.trigger( Success(Some(data)) );
			req.onError = function( err ) {
				if ( status==404 ) ft.trigger( Success(None) );
				else ft.trigger( Failure(Error.withData(status,'Failed to load template $fullPath', err)) );
			}
			req.request();
			return ft.asFuture();
		}
		catch ( e:Dynamic ) return Future.sync( Failure(Error.withData('Failed to load template $fullPath', e)) );
	}
}
