package ufront.mock;

import ufront.web.context.*;
import ufront.web.session.IHttpSessionState;
import ufront.auth.*;
import thx.error.NullArgument;
using mockatoo.Mockatoo;

/**
	A set of functions to make it easier to mock various ufront classes and interfaces to help with unit testing.

	Every `mock` function uses `Mockatoo` for mocking, see the [Github Readme](https://github.com/misprintt/mockatoo/) and [Developer Guide](https://github.com/misprintt/mockatoo/wiki/Developer-Guide) for more information.

	Designed for `using ufront.mock.UfrontMocker`.  



	It will also work best to add `using mockatoo.Mockatoo.*` to make the mocking functions easily accessible.
**/
class UfrontMocker
{
	/**
		Mock a HttpContext.

		Usage:

		```
		'/home'.mockHttpContext();
		'/home'.mockHttpContext( request, response, session, auth );
		UFMocker.mockHttpContext( '/home' );
		UFMocker.mockHttpContext( '/home', request, response, session, auth );
		```

		The URI provided is the raw `REQUEST_URI` and so can include a query string etc.
		
		The mocking is as follows:

		* The uri is used for `request.uri` if the request is being mocked.  (If the request object is given, not mocked, the supplied Uri is ignored)
		* `getRequestUri` calls the real method, so will process filters on `request.uri`
		* The request, response, session and auth return either the supplied value, or are mocked
		* `addUrlFilter` and `generateUri` call the real method.
	**/
	public static function mockHttpContext( uri:String, ?request:HttpRequest, ?response:HttpResponse, ?session:IHttpSessionState, ?auth:IAuthHandler<IAuthUser> )
	{
		// Check the supplied arguments
		NullArgument.throwIfNull( uri );
		if ( request==null ) {
			request = HttpRequest.mock();
			request.uri.returns( uri );
		}
		if ( response==null ) {
			response = HttpResponse.spy();
			response.flush().stub();
		}
		if (session==null) session = IHttpSessionState.mock();
		if (auth==null) auth = IAuthHandler.mock([IAuthUser]);

		// Mock the HttpContext
		var ctx = HttpContext.mock();
		ctx.getRequestUri().callsRealMethod();
		ctx.request.returns(request);
		ctx.response.returns(response);
		ctx.session.returns(session);
		ctx.auth.returns(auth);
		ctx.addUrlFilter(cast anyObject).callsRealMethod();
		ctx.generateUri(cast anyString).callsRealMethod();
		return ctx;
	}
}

/**
	Alias of Mockatoo, included so that `using UfrontMocker` implies `using Mockatoo`
**/
typedef Mockatoo = mockatoo.Mockatoo;