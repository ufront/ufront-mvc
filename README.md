ufront-mvc
==========

The `ufront-mvc` library is the core MVC framework used to handle web requests in Ufront.
It provides:

- [Controllers](http://api.ufront.net/ufront/web/Controller.html)
	- Respond to web requests (page visits, form submits etc.)
	- Return a response (a rendered view, some HTML, some JSON, a redirect, or anything else)
	- Interact with APIs, Sessions, Authentication and more via dependency injection.
- [Views](http://api.ufront.net/ufront/web/result/ViewResult.html)
	- A flexible view engine that can work with any runtime templating system, including:
		- [haxe.Template](http://haxe.org/manual/std-template.html)
		- [erazor](https://github.com/ufront/erazor)
		- [hxtemplo](https://github.com/Simn/hxtemplo)
		- [hxdtl](https://github.com/ajukraine/hxdtl)
		- [mustache](https://github.com/TomahawX/Mustache.hx)
	- Easy to support compile-time templates like erazor, detox, tink and more.
- [APIs](http://api.ufront.net/ufront/api/UFApi.html)
	- Easy to set up APIs that interact easily with the rest of your app.
	- Work well with dependency injection - you can inject anything into them, and have them injected into a controller or another API.
	- Work seamlessly on the server, and are able to be used asynchronously client-side.
- Other features
	- HTTP Sessions
	- Flexible authentication system
	- Low level access to the HttpContext
	- Automatic logging - to the server, to a file, to the browser console etc.
	- Easy to extend with Middleware, RequestHandlers, LogHandlers and ErrorHandlers.
	- Flexible caching implementations
- Ufront MVC does not provide the "Model" in MVC - but take a look at [ufront-orm](https://github.com/ufront/ufront-orm).

See the main [ufront](https://github.com/ufront/ufront) repo or the [ufront.net website](http://ufront.net) for more information about Ufront.

### Learn more

- [API Documentation](http://api.ufront.net/)
- [Ufront website](http://ufront.net) (including tutorials)
- [ufront-nodejs-guide](https://github.com/kevinresol/ufront-nodejs-guide/)

### Contributions

- Please use the [Github Issue Tracker](https://github.com/ufront/ufront-mvc/issues/) to report bugs.
- Pull requests always welcome, please ask on
- Contributions to this README are definitely welcome!

### Support

- [Gitter ufront/ufront](https://gitter.im/ufront/ufront) for chat.
- [Stack Overflow questions tagged ufront](http://stackoverflow.com/questions/tagged/ufront) for Q&A.
