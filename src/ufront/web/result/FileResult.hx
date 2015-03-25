package ufront.web.result;

import haxe.io.Bytes;
import thx.core.error.NullArgument;
import ufront.web.context.ActionContext;
import ufront.core.Sync;
using haxe.io.Path;

/** Represents a base class that is used to send binary file content to the response. **/
class FileResult extends ActionResult
{
	/**
		A mapping of common extensions to mime content types.
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

	/** Gets the content type to use for the response.  If it is null, no content-type header will be set, and the client will do it's best guess as to the type **/
	public var contentType:String;

	/**
		Gets or sets the content-disposition header so that a file-download dialog box is displayed in the browser with the specified file name.

		Setting a non-null value will set the `content-disposition` to `attachment`, which will force the file to be downloaded rather than displayed in the browser.
	**/
	public var fileDownloadName:String;

	function new( contentType:String, fileDownloadName:String ) {
		this.contentType = contentType;
		this.fileDownloadName = fileDownloadName;
		if( null==contentType ) {
			setContentTypeByFilename();
		}
	}

	/**
		Using the extension of a filename, attempt to use the correct content-type.

		If `filename` is not supplied, and fileDownloadName exists, it will be used.
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

		return Sync.success();
	}
}
