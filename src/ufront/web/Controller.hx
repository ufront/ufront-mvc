package ufront.web;

import haxe.EnumFlags;
import haxe.PosInfos;
import thx.error.NullArgument;
import ufront.web.context.HttpContext;
import ufront.web.result.ActionResult;
import ufront.web.result.EmptyResult;
using tink.CoreApi;
using haxe.io.Path;

/**
	A base class for your controllers when using Ufront's MVC (Model View Controller) pattern.

	A controller helps decide on the appropriate action to be taken given the route and parameters provided.
	It then interacts with the site's API, and returns a `ufront.web,result.ActionResult`, which is used to write a response back to the client.

	#### The base controller provides:

	- A constructor where you can set `context` upon initialization.
	- A `context` property holding the current `ufront.web.context.ActionContext`
	- An `execute()` method which for each sub-class:
		- decides which method to execute as the "action" for this request based upon the URI and parameters
		- from the URI and HTTP parameters, extract variables required for the chosen action
		- return a `tink.core.Surprise`, that holds either an `ActionResult` or a `Error`
	- Dependency injection.  When `context` is set, the injector in the current HttpContext is used to provide dependency injection to this controller.
	- Shortcuts to `ufTrace()`, `ufLog()`, `ufWarn()` and `ufError()` that can be used in your controller code.
	- A `toString()` method that prints the current class name, helpful when logging debug information.

	#### How to set up routes:

	An "action" is a method of the controller that can be called by visiting a certain route.

	You set up an action by defining function and giving it `@:route` metadata.

	Here are some examples:

	- `@:route('/') function homepage() {}`
	- `@:route('/staff/') function staff() {}`
	- `@:route('/staff/$name/') function viewPerson( name:String ) {}`
	- `@:route('/staff/$name/contact/') function contact( name:String ) {}`
	- `@:route('/staff/$name/contact/',POST) function contact( name:String, args:{ subject:String, text:String } ) {}`
	- `@:route('/article/$name/$page/') function article( name:String, page:Int ) {}`
	- `@:route('/upload/*') function article( parts:Array<String> ) {}`
	- `@:route('/ufadmin/') var adminController:UFAdminController;`

	#### How to write output to the browser:

	- Each action must return a value
	- Possible return values are:
		- `Surprise<ActionResult,Error>`
		- `Surprise<Dynamic,Dynamic>`
		- `Future<Dynamic>`
		- `Outcome<ActionResult,Error>`
		- `Outcome<Dynamic,Error>`
		- `ActionResult`
		- `Dynamic`

	Each different return type will be handled by `execute()`, and wrapped appropriately so that execute will always return a `Surprise<ActionResult,Error>`.

	Please note that if an exception is thrown in one of your actions, it will be caught and turned into an appropriate `Error` object to be handled by your application's error handlers.

	#### Build macro

	The `execute()` method on this class is abstract, and should be overridden on each child class via a build macro customized especially for that class given the `@:route()` metadata.

	If the build macro encounters `@:route()` metadata on a variable rather than a method, it will:

	- Check the given variable's type represents a Controller
	- Create a method: `function execute_$varName() return new $controller(context).execute()`
	- Perform the routing on the generated function

	The build macro should not effect any existing fields other than `execute()`.
**/
#if !macro
@:autoBuild( ufront.web.ControllerMacros.processRoutesAndGenerateExecuteFunction() )
#end
class Controller
{
	/**
		The current HttpContext.

		This is set via dependency injection.

		If you want to run some code after this has been injected, you can use for example: `@post public function doAuthCheck() { context.auth.requirePermission(AccessAdminArea); }`.
	**/
	@inject public var context(default,null):HttpContext;
	
	/**
		The Base URI that was used to access this controller.

		Includes a trailing slash.

		For example if you had `/user/jason/profile/` trigger `UserController` (for Jason) and the `profile` action, then baseUrl would be `/user/jason/`. 
	**/
	public var baseUri(default,null):String;

	/**
		Create a new `Controller` instance.

		Most of the time a controller will be created using dependency injection:

		    `injector.instantiate( MyController )`

		If not creating a controller with `new MyController()` by sure to inject the dependencies (such as `context`) manually.
	**/
	public function new() {}

	/**
		Execute the this controller with the current context.

		This will anazlyze the URI and the given Http Parameters, and match it to the appropriate action using the `@:route()` metadata.

		It will wrap the return result of your action in an `ActionResult` or `Error`.

		Please note this is an abstract method.
		Each child class will have an override, provided by a build macro, that has the appropriate code for that class.
	**/
	public function execute():FutureActionOutcome {
		return Future.sync( Failure(HttpError.internalServerError('Field execute() in ufront.web.Controller is an abstract method, please override it in ${this.toString()} ')) );
	}
	
	/**
		Instantiate and execute a sub controller.
	**/
	public function executeSubController( controller:Class<Controller> ):FutureActionOutcome {
		return context.injector.instantiate( controller ).execute();
	}

	/**
		A default toString() to aid in logging, tracing or debugging.
		Prints the current class name.
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
	
	function setBaseUri( uriPartsBeforeRouting:Array<String> ) {
		var remainingUri = uriPartsBeforeRouting.join( "/" ).addTrailingSlash();
		var fullUri = context.getRequestUri().addTrailingSlash();
		baseUri = fullUri.substr( 0, fullUri.length-remainingUri.length );
	}

	// The following are helpers which are called by the macro-generated code in each controller's execute() method.
	// You probably don't need to touch these unless you're working on a new way to generate the execute() method.

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

enum WrapRequired {
	WRFuture;
	WROutcome;
	WRResultOrError;
}
