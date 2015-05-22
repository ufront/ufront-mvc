package ufront.web.result;

import haxe.io.Bytes;
import thx.error.NullArgument;
import ufront.web.context.ActionContext;
import ufront.core.AsyncTools;
using haxe.io.Path;

/**
A base `ActionResult` that is used to send binary file content to the client response.

This is an abstract class, please see `BytesResult` and `FilePathResult` for implementations you can use.
**/
class FileResult extends ActionResult {
	/**
	A mapping of common file extensions to mime content types.
	**/
	public static var extMap = [
		// @todo: add complete list from http://en.wikipedia.org/wiki/Internet_media_type#List_of_common_media_types

		// Image
		"jpg" => "image/jpeg",
		"jpeg" => "image/jpeg",
		"png" => "image/png",
		"gif" => "image/gif",
		"svg" => "image/svg+xml",
		"tiff" => "image/tiff",

		// Application (not exhaustive)
		"zip" => "application/zip",
		"atom" => "application/atom+xml",
		"json" => "application/json",
		"js" => "application/javascript",
		"ogg" => "application/ogg",
		"pdf" => "application/pdf",
		"ps" => "application/postscript",
		"rdf" => "application/rdf",
		"rss" => "application/rss",
		"woff" => "application/woff",
		"xml" => "application/xml",
		"dtd" => "application/xml-dtd",
		"gz" => "application/gzip",
	];

	/**
	The content type to use for the response.
	If it is not supplied in the constructor, but a filename is supplied, the content type will be set using the mappings in `extMap`.
	If it is null, no content-type header will be set, and the client will do its best to guess the type.
	**/
	public var contentType:String;

	/**
	The file name for the current download.
	If this is a non-null value, the client will force the file to display a download window with the specified filename.
	This is achieved by setting the HTTP Header `content-disposition: attachment; filename=$fileDownloadName`.
	**/
	public var fileDownloadName:Null<String>;

	function new( contentType:String, fileDownloadName:String ) {
		this.contentType = contentType;
		this.fileDownloadName = fileDownloadName;
		if( null==contentType ) {
			setContentTypeByFilename();
		}
	}

	/**
	Using the extension of a filename, attempt to use the correct content-type.
	If `filename` is not supplied, and fileDownloadName exists, it will be used instead.
	**/
	public function setContentTypeByFilename( ?filename:String ) {
		if ( filename==null ) filename = fileDownloadName;
		if( null!=filename ) {
			var ext = filename.extension();
			if ( extMap.exists(ext) ) contentType = extMap[ext];
		}
	}

	override function executeResult( actionContext:ActionContext ) {
		NullArgument.throwIfNull( actionContext );

		if( null!=contentType )
			actionContext.httpContext.response.contentType = contentType;

		if( null!=fileDownloadName )
			actionContext.httpContext.response.setHeader( "content-disposition", 'attachment; filename=$fileDownloadName' );

		return SurpriseTools.success();
	}
}
