package ufront.remoting;

import ufront.core.MultiValueMap;
import ufront.web.upload.UFFileUpload;

/**
The RemotingSerializer is almost identical to the normal `Unserializer`, except that is designed to handle some extra features for Ufront remoting.

In particular, it can attach `UFFileUpload` objects to the HTTP Request, so that `UFUnserializer` can access them.
**/
class RemotingSerializer extends haxe.Serializer {
	/**
	Files that should be uploaded with the current request.

	Any `UFFileUpload` that uses custom serialization will add itself to this map, and `ufront.remoting.HttpConnection` or `ufront.remoting.HttpAsyncConnection` will then know to attach the files.
	**/
	public var uploads(default,null):MultiValueMap<UFFileUpload>;

	/**
	The direction the request is heading.

	If `RemotingDirection.RDClientToServer`, then
	**/
	public var direction:RemotingDirection;

	public function new( dir:RemotingDirection ) {
		super();
		this.direction = dir;
		this.uploads = new MultiValueMap();
	}

	public static function run( obj:Dynamic, direction:RemotingDirection ):String {
		var s = new RemotingSerializer( direction );
		s.serialize( obj );
		return s.toString();
	}
}

/**
The direction the remoting is for.

If the client is serializing a `UFFileUpload` to send it to the server, it will attach it differently than if a server is sending a file to the client.
**/
enum RemotingDirection {
	RDClientToServer;
	RDServerToClient;
}
