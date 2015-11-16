package ufront.remoting;

import ufront.core.MultiValueMap;
import ufront.web.upload.UFFileUpload;

/**
The RemotingUnserializer is almost identical to the normal `Unserializer`, except that is designed to handle some extra features for Ufront remoting.

In particular, it can link unserialize `UFFileUpload` objects from those attached to the request, if `RemotingSerializer` was used to attach them to the request.
**/
class RemotingUnserializer extends haxe.Unserializer {
	/**
	Files that were uploaded with the current request.
	These should be provided in the constructor, and the files should have been attached using the `RemotingSerializer`.
	**/
	public var uploads(default,null):MultiValueMap<UFFileUpload>;

	public function new( buf:String, ?uploads:MultiValueMap<UFFileUpload> ) {
		super( buf );
		this.uploads = (uploads!=null) ? uploads : new MultiValueMap();
	}
}
