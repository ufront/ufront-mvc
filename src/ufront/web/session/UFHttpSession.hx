package ufront.web.session;

import tink.CoreApi;

/**
	An interface describing an open HTTP session.

	The methods are similar to `Map`, with `get()`, `set()`, `exists()`, `remove()` and `clear()`.

	There are also some methods to do with the actual session, not the data inside it: `init()`, `isActive()`, `getID()`, `close()`, `commit()`, `regenerateID()` and `setExpiry()`.

	@author Franco Ponticelli
	@author Jason O'Neil
**/
interface UFHttpSession
{
	/** The ID of the current session **/
	public var id(get,null):String;

	/**
		Initiate the session (either read existing or start new session) and prepare so other operations can happen synchronously

		Returns a Surprise to let you know when the session is ready, after which operations can happen synchronously until you `commit()`.

		If the session fails to initiate, the Surprise will be a Failure, containing the error message.
	**/
	public function init():Surprise<Noise,String>;

	/** Empty the session of values.  Please note this does not end the session. **/
	public function clear():Void;

	/** Get an existing session item. **/
	public function get( name:String ):Dynamic;

	/** Set a session item.  This should not be committed until `commit()` is called **/
	public function set( name:String, value:Dynamic ):Void;

	/** Check if a session value exists **/
	public function exists( name:String ):Bool;

	/** Remove an item from the session **/
	public function remove( name:String ):Void;

	/** Return whether or not there is already an active session, and whether it is ready to use (that is, `init()` has been completed). **/
	public function isActive():Bool;

	/** Flag the current session for removal.  The session data and session ID should be set to null and when `commit()` is called and the session should be removed from the server. **/
	public function close():Void;

	/** Set the number of seconds a session should last.  A value of 0 means the session will expire when the browser window is closed. **/
	public function setExpiry( lifetime:Int ):Void;

	/** Commit the request.  Return a surprise, either notifying you of completion or giving an error message if it failed. **/
	public function commit():Surprise<Noise,String>;

	/** Flag this session for a commit.  This will happen automatically if you call `set`, `remove`, `clear`, or `regenerateID`, but this can be useful if a value has updated without "set" being called. **/
	public function triggerCommit():Void;

	/**
		Regenerate the session ID, making the changes on the server and informing the client.

		The new ID should be reserved now, though the actual content should not be saved until commit() is called.

		If commit() is not called, the existing ID will remain.

		Returns a Surprise to notify you when a new ID has been selected, or if a new ID was not able to be set.
	**/
	public function regenerateID():Surprise<String,String>;
}
