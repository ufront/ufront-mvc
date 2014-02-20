package ufront.web;

import haxe.PosInfos;
import ufront.web.context.ActionContext;
import ufront.web.result.ActionResult;
using tink.CoreApi;

/**
	Similar to `ufront.web.Controller`, but made to be used with `ufront.web.Dispatch`.

	It does not have an `execute()` method, instead it is used with `Dispatch.returnDispatch( controller )`.

	It does not currently support returning futures or surprises, every return is expected to be an `ActionResult`, and if not, it will be wrapped in an `ActionResult`.
**/
@:keep
class DispatchController
{
	/** 
		The Action Context.  

		This is set in the constructor, or can be set manually.  

		When context is set to a non-null value, the injector for the current request will be used to inject dependencies into this controller:

		    `context.httpContext.injector.injectInto( this )`
	**/
	@inject public var context(default,set):ActionContext;

	/**
		Create a new `Controller` instance.

		@param context Set the `context` property.  
		               Currently this is optional for backwards compatibility, but may become required in a future version.
		               If you do not set context `context` via the constructor, you must set it before calling `execute`.
	**/
	public function new( ?context:ActionContext ) {
		if ( context!=null ) this.context = context;
	}

	function set_context( c:ActionContext ) {
		if ( c!=null ) c.httpContext.injector.injectInto(this);
		return this.context = c;
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
		A shortcut to `context.httpContext.ufTrace()`
	**/
	@:noCompletion
	public inline function ufTrace( msg:Dynamic, ?pos:PosInfos ) {
		context.httpContext.ufTrace( msg, pos );
	}

	/**
		A shortcut to `context.httpContext.ufLog()`
	**/
	@:noCompletion
	public inline function ufLog( msg:Dynamic, ?pos:PosInfos ) {
		context.httpContext.ufLog( msg, pos );
	}

	/**
		A shortcut to `context.httpContext.ufWarn()`
	**/
	@:noCompletion
	public inline function ufWarn( msg:Dynamic, ?pos:PosInfos ) {
		context.httpContext.ufWarn( msg, pos );
	}

	/**
		A shortcut to `context.httpContext.ufError()`
	**/
	@:noCompletion
	public inline function ufError( msg:Dynamic, ?pos:PosInfos ) {
		context.httpContext.ufError( msg, pos );
	}
}