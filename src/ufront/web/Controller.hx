package ufront.web;

import haxe.EnumFlags;
import haxe.PosInfos;
import ufront.web.context.HttpContext;
import ufront.web.result.ActionResult;
import ufront.web.result.EmptyResult;
using tink.CoreApi;
using haxe.io.Path;

/**
A Controller ties your Ufront application together - responding to routes, executing certain actions, and returning a result for the client.

This class is the base class for any controllers you create in your website or application.
Controllers can run on the client or the server, responding to user input, and calling APIs - either directly on the server, or via remoting on the client.
They then return a result, describing the output that should be sent to the client.

The role of a controller, in Ufront's MVC pattern, includes:

- **Routing:**

    Responding to a request from a client, by looking at `HttpContext.getRequestUri()` and matching it to our `@:route()` metadata.

- **Executing Actions:**

    Each request will execute a method on the controller (sometimes called an "Action").
    This method can validate or transform user input, interact with APIs, and prepare a result.

    It is recommended to keep your filesystem access, DB access, or security focused application logic in a `UFApi` rather than a Controller.
    This guarantees your code to run on the server and not the client, and keeps it safe from tampering.

- **Returning a result:**

    Each controller will return a result.
    This can be an `ActionResult`, a `FutureActionResult`, an `ActionOutcome` or a `FutureActionOutcome`.
    Any return type that does not fit this pattern - for example, returning a String, or even returning Void - will be wrapped in one of these result types.

    Ufront's `MVCHandler` will then take the result returned by the controller and execute it, writing the output to the `HttpResponse`.

Each of these steps is described in more detail below.

### Routing

When you app executes, it tries to match the URI of the `HttpRequest` with the routes on your controller.

Each controller has a macro generated `execute()` method, which goes through the fields of the controller looking for matching `@:route()` metadata.
When it finds a route which matches the current URI, it executes the method/action for that route.
Routing always begins with the Controller you set in `UfrontConfiguration.indexController`, and can drill down into any sub controllers from there.

You set up an action by defining a function and giving it `@:route` metadata.
You can also use `@:route` metadata on a variable which holds a sub-controller.

Here are some examples:

```
@:route('/') function homepage() {}
@:route('/staff/') function staff() {}
@:route('/staff/$name/') function viewPerson( name:String ) {}
@:route('/staff/$name/contact/',GET) function contact( name:String ) {}
@:route('/staff/$name/contact/',POST) function contact( name:String, args:{ subject:String, text:String } ) {}
@:route('/article/$name/$page/') function article( name:String, page:Int ) {}
@:route('/file/*') function viewFile( parts:Array<String> ) {}
@:route('/ufadmin/*') var adminController:UFAdminHomeController;
```

### Executing Actions

Once a matching route has been found, your controller will execute the given action.

- *If the action was a sub-controller variable*, it will call `this.executeSubController()` for the given controller, and return the result.
- *If the action was a method*, it will gather the function arguments based on the `HttpRequest`, and execute the function, and return the result.
    - In your controller actions you have access to the current `this.context:HttpContext`, which allows you to read data from the request and add items to the response.
    - Controllers also have dependency injection available to them - you can inject whatever you need, especially any `UFApi` classes you plan to use.
    - If you would like to trace output, each controller has private `ufTrace()`, `ufLog()`, `ufWarn()` and `ufError()` methods, which will send output to your `UFLogHandler`s.
    - Your function should return a result, which will define what content is sent to the client. See the section below for details.

> **Note:** It is wise to do most of the "heavy lifting" of your app in a `UFApi`, which you call from the controller, rather than in a controller directly.
>
> Some web frameworks prefer you to include most of your application logic in your controller actions.
> However, Ufront controllers can run on the server or on the client - which means our controllers cannot assume access to system resources (for example, a database), and they cannot be trusted with sensitive code, because they run client side and are open to inspection or modification.
>
> For this reason, we recommend that anything to do with database connections, file systems, permission checks or sensitive application logic, be kept on the server and called through a `UFApi`.

### Returning a Result

Each controller action returns a result of some kind - and these results are how we control what response gets written to the browser.
Possible return values are:

- `Surprise<ActionResult,tink.core.Error>`
- `Surprise<Dynamic,Dynamic>`
- `Future<ActionResult>`
- `Future<Dynamic>`
- `Outcome<ActionResult,tink.core.Error>`
- `Outcome<Dynamic,Dynamic>`
- `ActionResult`
- `Dynamic`
- `Void`

No matter what the return type of your action is, when `execute is called` it will be appropriately wrapped into a `FutureActionOutcome` (which is really a `Future<Outcome<ActionResult,Error>>`).

Assuming the result was successful, there will be a valid `ActionResult` that the `MVCHandler` in your application will be able to execute, and this is what writes content to the browser.

Action results are designed to be easy to work with.
For example:

- `return new ViewResult({ title:"Ufront", subtitle:"Community" });`
- `return new JsonResult({ title:"Ufront", subtitle:"Community" });`
- `return new RedirectResult("http://haxe.org");`
- `return new FilePathResult(context.contentDirectory+"my-upload.jpg");`

See `ActionResult` and each of the sub-classes for a complete list of result types provided, or for information on creating your own.

> **Note:** It is recommended to use an `ActionResult` rather than using `Sys.println()` or `HttpResponse.write()` directly.
>
> Not only are these more convenient, they are easier to write unit tests for, and allow the app to show error pages gracefully when required.

### The Build Macro (or, "How This Actually Works")

The `this.execute()` method on this class is abstract, and will always be overridden on each child class.
The build macro will build a custom execute field for each controller based on that controller's `@:route()` metadata.

The execute function that is generated is essentially a giant `if / else if / else` chain:

```haxe
class HomeController extends Controller {
  @:route("/") function index() return "Homepage!";
  @:route("/contact",GET) function contactForm() return "Contact form!";
  @:route("/contact",POST) function contactSend() return "Email sent!";

  override public function execute() {
    if ( uri=="/" ) return index();
    else if ( uri=="/contact/" && method=="GET" ) return contactForm();
    else if ( uri=="/contact/" && method=="POST" ) return contactSend();
    else throw HttpError.pageNotFound();
  }
}
```

It is of course slightly more complex than this, and involves calling some private functions to ensure we have a consistent return type of `FutureActionOutcome`.
But knowing this is the basic structure of the execute method can be helpful.
If you ever want to check the exact details, compile your code with `-D dump=pretty` to get the Haxe compiler to show you the code output of the macros.

The `execute()` method will test each route in the order they are defined.
So if you have a wildcard route `@:route("/*")`  at the top of your class, and a specific route `@:route('/mypage/')` below it, the wildcard will match first and be called every time.

If the build macro encounters `@:route()` metadata on a variable rather than a method, it will:

- Check the given variable's type represents a `Controller`.
- Create a method: `function execute_$varName() return executeSubController(context);`
- Perform the routing on the generated function.

The build macro does not effect any existing fields other than `this.execute()`.
**/
#if !macro
@:autoBuild( ufront.web.ControllerMacros.processRoutesAndGenerateExecuteFunction() )
#end
class Controller {
	/**
	The current HttpContext.

	This is set via dependency injection.

	If you want to run some code after this has been injected, but before routing occurs, you can use `@post`.
	For example:

	```
	@post public function doAuthCheck() {
	  context.auth.requirePermission(AccessAdminArea);
	}
	```
	**/
	@inject public var context:HttpContext;

	/**
	The Base URI that was used to access this controller.

	This will always include a trailing slash.

	For example if you had `/user/profile/jason/` trigger `UserController` and the `profile` action for "jason", then baseUri would be `/user/`.

	This is set at the beginning of `this.execute()`, before routing occurs.
	**/
	public var baseUri(default,null):String;

	/**
	Create a new `Controller` instance.

	In Ufront controllers are usually created through dependency injection, so you can use `@inject` metadata on your sub-controller constructors.

	If creating a controller manually, rather than via dependency injection, be sure to inject the dependencies (such as `context`) manually.
	**/
	public function new() {}

	/**
	Execute this controller using the current `HttpContext`.

	This will anazlyze the URI and the current `HttpRequest`, and match it to the appropriate action using the `@:route()` metadata.

	It will wrap the return result of your action in a `Surprise<ActionResult,tink.core.Error>`.

	Please note this is an abstract method.
	Each controller that extends `ufront.web.Controller` will have an override, provided by a build macro, that has the appropriate code for that class.
	**/
	public function execute():FutureActionOutcome {
		return Future.sync( Failure(HttpError.internalServerError('Field execute() in ufront.web.Controller is an abstract method, please override it in ${this.toString()} ')) );
	}

	/**
	Instantiate and execute a sub controller.
	**/
	public function executeSubController( controller:Class<Controller> ):FutureActionOutcome {
		#if !macro
			return context.injector.instantiate( controller ).execute();
		#else
			return null;
		#end
	}

	/**
	A default toString() that prints the current class name.
	This is useful primarily for logging requests and knowing which controller was called.
	**/
	@:noCompletion
	public function toString() {
		return Type.getClassName( Type.getClass(this) );
	}

	/**
	A shortcut to `context.ufTrace()`
	**/
	@:noCompletion
	inline function ufTrace( msg:Dynamic, ?pos:PosInfos ) {
		if (context!=null) context.ufTrace( msg, pos );
		else haxe.Log.trace( '$msg', pos ); // If called during the constructor, `context` will not be set yet.
	}

	/**
	A shortcut to `context.ufLog()`
	**/
	@:noCompletion
	inline function ufLog( msg:Dynamic, ?pos:PosInfos ) {
		if (context!=null) context.ufLog( msg, pos );
		else haxe.Log.trace( 'Log: $msg', pos ); // If called during the constructor, `context` will not be set yet.
	}

	/**
	A shortcut to `context.ufWarn()`
	**/
	@:noCompletion
	inline function ufWarn( msg:Dynamic, ?pos:PosInfos ) {
		if (context!=null) context.ufWarn( msg, pos );
		else haxe.Log.trace( 'Warning: $msg', pos ); // If called during the constructor, `context` will not be set yet.
	}

	/**
	A shortcut to `context.ufError()`
	**/
	@:noCompletion
	inline function ufError( msg:Dynamic, ?pos:PosInfos ) {
		if (context!=null) context.ufError( msg, pos );
		else haxe.Log.trace( 'Error: $msg', pos ); // If called during the constructor, `context` will not be set yet.
	}

	// The following are helpers which are called by the macro-generated code in each controller's execute() method.
	// You probably don't need to touch these unless you're working on a new way to generate the execute() method.

	function setBaseUri( uriPartsBeforeRouting:Array<String> ) {
		var remainingUri = uriPartsBeforeRouting.join( "/" ).addTrailingSlash();
		var fullUri = context.getRequestUri().addTrailingSlash();
		baseUri = fullUri.substr( 0, fullUri.length-remainingUri.length ).addTrailingSlash();
	}

	/** Based on a set of enum flags, wrap as required.  If null, return an appropriately wrapped EmptyResult() **/
	function wrapResult( result:Dynamic, wrappingRequired:EnumFlags<WrapRequired> ):Surprise<ActionResult,Error> {
		if ( result==null ) {
			var actionResult:ActionResult = new EmptyResult( true );
			return Future.sync( Success(actionResult) );
		}
		else {
			var future:Future<Dynamic> = wrappingRequired.has(WRFuture) ? wrapInFuture( result ) : cast result;
			var surprise:Surprise<Dynamic,Dynamic> = wrappingRequired.has(WROutcome) ? wrapInOutcome( future ) : cast future;
			var finalResult:Surprise<ActionResult,Error> = wrappingRequired.has(WRResultOrError) ? wrapResultOrError( surprise ) : cast surprise;
			return finalResult;
		}
	}

	/** A helper to wrap a return result in a Future **/
	@:noCompletion @:noDoc @:noUsing
	function wrapInFuture<T>( result:T ):Future<T> {
		return Future.sync( result );
	}

	/** A helper to wrap a return result in a Future **/
	@:noCompletion @:noDoc @:noUsing
	function wrapInOutcome<T>( future:Future<T> ):Surprise<T,Error> {
		return future.map( function(result) return Success( result ) );
	}

	/** A helper to wrap a return result in a Future **/
	@:noCompletion @:noDoc @:noUsing
	function wrapResultOrError( surprise:Surprise<Dynamic,Dynamic> ):Surprise<ActionResult,Error> {
		return surprise.map( function(outcome) return switch outcome {
			case Success(result): Success( ActionResult.wrap(result) );
			case Failure(error): Failure( HttpError.wrap(error) );
		});
	}

	/** A helper to set context.actionResult once the result of execute() has finished loading. **/
	@:noCompletion @:noDoc @:noUsing
	function setContextActionResultWhenFinished( result:Surprise<ActionResult,Error> ) {
		result.handle( function (outcome) switch outcome {
			case Success(ar): context.actionContext.actionResult = ar;
			case _:
		});
	}

}

/**
A collection of flags describing operations that are required to wrap any return type into a `FutureActionOutcome`.

In our `Controller.execute()` methods, we return a consistent `Future<Outcome<ActionResult,tink.core.Error>>` type, despite the return type of the method/action executed.
**/
enum WrapRequired {
	/** The return type was synchronous, and must be wrapped in a `Future`. **/
	WRFuture;
	/** The return type was not an `Outcome`, and must be wrapped in either `Outcome.Success` or `Outcome.Failure`. **/
	WROutcome;
	/**
	The return type was not an `ActionResult` (or on the failure case, a `tink.core.Error`).
	It must be wrapped into the appropriate object.
	**/
	WRResultOrError;
}
