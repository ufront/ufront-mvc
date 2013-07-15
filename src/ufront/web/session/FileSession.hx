package ufront.web.session;

import ufront.web.session.IHttpSessionState;
import thx.error.NotImplemented;

/**
	A static helper to create a FileSession on each of the supported platforms.
**/
class FileSession
{
	/**
		Create a new FileSession (using the appropriate platform implementation) at the given path.

		@param savePath - relative path to directory where sessions will be saved.
		@param expire - the number of seconds the session should last.  Default is 0.  If the value is 0 the session does not have an expiry time.
	**/
	public static function create( savePath:String, ?expire:Int=0 ) : IHttpSessionState {

		#if php
				return new php.ufront.web.session.FileSession(savePath, expire);
		#elseif neko
				return new neko.ufront.web.session.FileSession(savePath, expire);
		#elseif nodejs
				return new nodejs.ufront.web.session.FileSession(savePath, expire);
		#else
				throw new NotImplemented();
				return null;
		#end
	}
}
