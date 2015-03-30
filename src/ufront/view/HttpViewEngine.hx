package ufront.view;

import haxe.ds.Option;
import haxe.Http;
using tink.CoreApi;
using haxe.io.Path;
using StringTools;
/**
	A UFViewEngine that loads views over HTTP.
**/
class HttpViewEngine extends UFViewEngine {

	public function new() {
		super();
	}

	/** The path to your views as an absolute HTTP URI. eg `http://ufront.net/views/` **/
	@inject("viewPath") public var viewPath:String;

	/**
		Attempt to load the view via a HTTP call.

		If a valid result is returned (status 200)

		@param relativeViewPath The relative path to the view. Please note this path is not checked for "../" or similar path hacks, so be wary of using user inputted data here. A leading "/" will be ignored.
		@return A future containing details on if the template existed at the given path or not, or a failure if there was an unexpected error.
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
