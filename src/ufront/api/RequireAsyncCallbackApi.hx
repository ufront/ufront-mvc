package ufront.api;

/**
	RequireApiProxy is a marker interface that makes sure an API proxy is built before we reference it.

	This may be required because in Haxe, "build order" (the order in which classes are built and build macros run) is unspecified.
	What this means in practice, is that a `UserController` that uses `UserApiProxy`, may be built before `UserApiProxy` has been created - resulting in a compiler error.

	You can work around this by having `class UserController implements RequireAsyncCallbackApi<UserApi>`, which will ensure `UserApiProxy` is generated in time.

	You can also require more than one proxy at a time: `class UserController implements RequireAsyncCallbackApi<UserApi,LoginApi>`.
**/
@:autoBuild(ufront.api.ApiMacros.buildSpecificApiProxy())
interface RequireAsyncCallbackApi<T> {}
