package ufront.web;

import haxe.PosInfos;
import ufront.web.context.ActionContext;
import ufront.web.result.ActionResult;
using tink.CoreApi;

/**
	A simple base controller class.  
	It's main function is an autobuild macro, which will be used to provide some helpers in future.  
	It also has an empty constructor and a `context:ActionContext` property.  See below for details.
**/
// @:autoBuild()
@:keep
class Controller
{
	/** 
		The Action Context.  

		This is usually injected by `ufront.web.DispatchModule`.
	**/
	public var context(default,set):ActionContext;

	/**
		Empty constructor.  
		Included so that you don't need to manually specify a constructor in your controller when you don't need it.
	**/
	public function new( ?context:ActionContext ) {
		if ( context!=null ) this.context = context;
	}

	function set_context( c:ActionContext ) {
		if ( c!=null ) c.httpContext.injector.injectInto(this);
		return this.context = c;
	}

	public function execute():Surprise<ActionResult,HttpError> {
		return Future.sync( Failure(HttpError.internalServerError('Field execute() in ufront.web.Controller is an abstract method, please override it in ${this.toString()} ')) );
	}

	/**
		A default toString() to aid in debugging.  Just prints the current class name.
	**/
	@:noCompletion
	public function toString() {
		return Type.getClassName( Type.getClass(this) );
	}

	/**
		A shortcut to `HttpContext.ufTrace`
	**/
	@:noCompletion
	public inline function ufTrace( msg:Dynamic, ?pos:PosInfos ) {
		context.httpContext.ufTrace( msg, pos );
	}

	/**
		A shortcut to `HttpContext.ufLog`
	**/
	@:noCompletion
	public inline function ufLog( msg:Dynamic, ?pos:PosInfos ) {
		context.httpContext.ufLog( msg, pos );
	}

	/**
		A shortcut to `HttpContext.ufWarn`
	**/
	@:noCompletion
	public inline function ufWarn( msg:Dynamic, ?pos:PosInfos ) {
		context.httpContext.ufWarn( msg, pos );
	}

	/**
		A shortcut to `HttpContext.ufError`
	**/
	@:noCompletion
	public inline function ufError( msg:Dynamic, ?pos:PosInfos ) {
		context.httpContext.ufError( msg, pos );
	}
}