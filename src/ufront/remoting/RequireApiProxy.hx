package ufront.remoting;

/** RequireApiProxy is a marker interface that makes sure an API proxy is built before we reference it.

Basically, build order in Haxe is undefined, meaning that class UserController that uses UserApiProxy might be built
before the UserApi class.  And because the UserApiProxy class doesn't exist until the UserApi class is built,
it's not ready in time for UserController.

So if Haxe did this:

 * Build UserApi
	* UserApiProxy is defined
 * Build UserController

We would be okay.  Unfortunately, there's no way to guarantee that it will work in that order.  It might do:

 * Build UserController
	* Error "Class UserApiProxy not found"!
 * Build UserApi
	* UserApiProxy is defined

What we do, is have another build macro, triggered by this interface, that lets you know to build it:

	class UserController implements RequireApiProxy<UserApi>
	{
		var api:UserApiProxy;
	}

Which would result in:

 * Build UserController implements RequireApiProxy<UserAPI>
	* UserApiProxy is defined
 * Build UserApi
	* Checks UserApiProxy is already defined... it is... good!

*/

@:autoBuild(ufront.remoting.ApiMacros.buildSpecificApiProxy())
interface RequireApiProxy<T> {}