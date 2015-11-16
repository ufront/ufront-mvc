package ufront.web.upload;

import ufront.core.Uuid;
import ufront.remoting.*;
import haxe.*;
using haxe.io.Path;

/**
The `BaseUpload` is a base class that can be used when implementing `UFFileUpload`.

It's main purpose is to make it easier for transferring uploads from the client to the server as serialized objects.

When a `BaseUpload` object is serialized via `RemotingSerializer`, and the purpose is to send the upload to the server, it will serialize the metadata about the object, and ask `RemotingSerializer` to attach the file to the remoting HTTP request.
When the `RemotingUnserializer` tries to unpack a `BaseUpload` object, it will attach the corresponding `UFFileUpload` to

-

**/
class BaseUpload {
	/** The name of the POST argument (that is, the name of the file input) that this file was uploaded with. **/
	public var postName:String;

	/** The original name of this file on the client. **/
	public var originalFileName:String;

	/** The size of the upload in Bytes **/
	public var size:Int;

	/**
	The contentType of the upload.

	Please note this is not verified, so do not rely on this for security.
	**/
	public var contentType:Null<String>;

	/**
	The `UFFileUpload` that was attached to the HTTP request.

	Because of the way Haxe remoting and serialization works, a `BrowserFileUpload` sent to the server will be unserialized as a `BrowserFileUpload` object, even though on the server it was received as a different type, like `TmpFileUpload`.
	During de-serialization, we attach the type the server uses (eg `TmpFileUpload`) to the `attachedUpload` variable.

	In `RemotingHandler`, we swap any instance of `BaseUpload` for the `UFFileUpload` the server is actually using.

	In each sub-class, such as `TmpFileUpload` and `BrowserFileUpload`, we check if `attachedUpload` is present, and if so, all calls to `getBytes()`, `getString()` and `process()` etc should be forwarded to the `attachedUpload` object.
	**/
	public var attachedUpload:Null<UFFileUpload>;

	/**
	Create a new `TempFileUploadSync`.

	It should already be saved to a temporary file by `TmpFileUploadMiddleware` when this object is created.

	Please note that `originalFileName` will be sanitised using `haxe.io.Path.withoutDirectory()`.
	**/
	function new( postName:String, originalFileName:String, size:Int, ?contentType:String ) {
		this.postName = postName;
		this.originalFileName = originalFileName.withoutDirectory();
		this.size = size;
		this.contentType = contentType;
	}

	function hxSerialize( s:haxe.Serializer ) {
		var rs = Std.instance( s, RemotingSerializer );
		var attachingUpload = rs!=null && rs.direction.match(RDClientToServer);
		s.serialize( attachingUpload );
		if ( attachingUpload ) {
			// It's a remoting serializer, and we're sending this upload to the server.
			if ( Std.is(this,UFFileUpload)==false )
				throw 'BaseUpload can only be serialized if the sub-class matches the UFFileUpload interface';
			var uniquePostName = 'postName_'+Uuid.create();
			rs.uploads.add( uniquePostName, cast this );
			s.serialize( uniquePostName );
		}
		s.serialize( postName );
		s.serialize( originalFileName );
		s.serialize( size );
		s.serialize( contentType );
	}

	function hxUnserialize( s:haxe.Unserializer ) {
		var uploadAttached:Bool = s.unserialize();

		var rs = Std.instance( s, RemotingUnserializer );
		if ( uploadAttached ) {
			if ( rs==null )
				throw 'Unable to Unserialize upload. It was serialized with RemotingSerializer, it must be unserialized with RemotingUnserializer';

			// The upload should be there.
			var uniquePostName:String = s.unserialize();
			if ( rs.uploads.exists(uniquePostName) ) {
				this.attachedUpload = rs.uploads[uniquePostName];
			}
			else throw 'Unable to find upload attached as $uniquePostName';
		}

		this.postName = s.unserialize();
		this.originalFileName = s.unserialize();
		this.size = s.unserialize();
		this.contentType = s.unserialize();
	}
}
