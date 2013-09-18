package ufront.web.session;

import hxevents.Async;

/**
	An interface describing an open HTTP session.

	The methods are similar to Map(), with `get`, `set`, `exists`, `remove` and `clear`.

	There are also some methods to do with the actual session, not the data inside it: `dispose`, `id` and `setLifeTime`.
	
	@author Franco Ponticelli
	@author Jason O'Neil
**/
interface IHttpSessionState
{
	/** Empty the session of values.  Please note this does not end the session. **/
	public function clear() : Void;

	/** Get an existing session item **/
	public function get(name : String) : Dynamic;

	/** Set a session item.  This should not be committed until `commit()` is called **/
	public function set(name : String, value : Dynamic) : Void;

	/** Check if a session value exists **/
	public function exists(name : String) : Bool;

	/** Remove an item from the session **/
	public function remove(name : String) : Void;

	/** Return the ID of the current session **/
	public function getID() : String;

	/** Flag the current session for removal.  The session data and session ID should be set to null and when `commit()` is called and the session should be removed from the server. **/
	public function close() : Void;

	/** Set the number of seconds a session should last.  A value of 0 means the session will expire when the browser window is closed. **/
	public function setExpiry(lifetime:Int):Void;
}

/**
	An extension to IHttpSessionState that requires asynchronous methods `start`, `commit` and `regenerateID` be exposed.
**/
interface IHttpSessionStateAsync extends IHttpSessionState
{
	/** Initiate the session (either read existing or start new session) and prepare so other operations can happen synchronously **/
	public function init( next:Async ) : Void;

	/** Commit the request **/
	public function commit( next:Async ) : Void;

	/** 
		Regenerate the session ID, making the changes on the server and informing the client.  

		The actual renaming of the session file should take place when `commit()` is called.

		Doing this at regular intervals can help prevent session highjacking. 

		This is async because asynchronous checks may need to be made that the ID is not already in use
	**/
	public function regenerateID( next:Async ) : Void;
}

/**
	An extension to IHttpSessionState that requires the synchronous `start`, `commit` and `regenerateID` methods be exposed
**/
interface IHttpSessionStateSync extends IHttpSessionState
{
	/** Initiate the session (either read an existing session or start a new session) and prepare so other operations can happen quickly **/
	public function init() : Void;

	/** Commit the request **/
	public function commit() : Void;

	/** 
		Regenerate the session ID, making the changes on the server and informing the client.  

		The actual renaming of the session file should take place when `commit()` is called.

		Doing this at regular intervals can help prevent session highjacking. 

		This method should return the new ID.
	**/
	public function regenerateID() : String;

}