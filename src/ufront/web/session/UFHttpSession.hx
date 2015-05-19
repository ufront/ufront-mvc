package ufront.web.session;

import tink.CoreApi;

/**
An interface describing an open HTTP session.

The methods are similar to `Map`, with `get()`, `set()`, `exists()`, `remove()` and `clear()`.

There are also some methods and properties to do with the actual session, not the data inside it: `init()`, `isActive()`, `id`, `close()`, `commit()`, `regenerateID()` and `setExpiry()`.

Using the `UFHttpSession` interface, rather than one of the implementation classes, allows you to write code that can function with a different session implementation.
This is useful if you are writing that will be used by multiple apps (perhaps with multiple session implementations), or if you might change your session technology in future.

@author Franco Ponticelli
@author Jason O'Neil
**/
interface UFHttpSession {
	/**
	The ID of the current session.

	This is usually read from cookies or other HTTP parameters.
	If an ID is not set, or if `this.regenerateID()` is called, a new ID will be generated during `this.commit()`.
	You cannot set the ID manually, you can only request a new ID using `this.regenerateID()`.
	**/
	public var id(get,null):String;

	/**
	Initiate the session (either read existing or start new session) and prepare so other operations can happen synchronously.

	If the session fails to initiate, the Surprise will be a Failure, containing the error message.

	@return A Surprise to let you know when the session is ready, after which you can read and modify session data synchronously, until you call `this.commit()`.
	**/
	public function init():Surprise<Noise,Error>;

	/**
	Empty the session of values.

	Please note this does not end the session.
	**/
	public function clear():Void;

	/** Get an existing session item. **/
	public function get( name:String ):Dynamic;

	/**
	Set a session item.

	Please note this will not save the session - you must call `commit()` for the change to persist.
	**/
	public function set( name:String, value:Dynamic ):Void;

	/** Check if a session value exists. **/
	public function exists( name:String ):Bool;

	/** Remove an item from the session. **/
	public function remove( name:String ):Void;

	/** Return whether or not there is already an active session, and whether it is ready to use (that is, `this.init()` has been completed). **/
	public function isActive():Bool;

	/**
	Flag the current session for removal.

	The session data and session ID should be set to null and when `commit()` is called and the session should be removed from the server.
	**/
	public function close():Void;

	/**
	Set the number of seconds a session should last.

	A value of 0 means the session will expire when the browser window is closed.
	**/
	public function setExpiry( lifetime:Int ):Void;

	/**
	Commit the request.

	Return a surprise, either notifying you of completion or giving an error message if it failed.
	**/
	public function commit():Surprise<Noise,Error>;

	/**
	Flag this session for a commit.

	This will happen automatically if you call `set`, `remove`, `clear`, or `regenerateID`.
	Otherwise, this can be useful if a value has updated without `set` being called - for example by pushing a new item to an array that was already in the session.
	**/
	public function triggerCommit():Void;

	/**
	Request the session ID be regenerated on the next commit.

	This will generate a new ID on the server, move the session data to the new ID, and inform the client of the new ID.

	If `commit()` is not called, the existing ID will remain.
	**/
	public function regenerateID():Void;
}
