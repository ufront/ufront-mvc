package ufront.web;

import haxe.PosInfos;
import ufront.web.context.ActionContext;

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
	@inject public var context:ActionContext;

	/**
		Empty constructor.  
		Included so that you don't need to manually specify a constructor in your controller when you don't need it.
	**/
	public function new() {}

	/**
		A default toString() to aid in debugging.  Just prints the current class name.
	**/
	public function toString() {
		return Type.getClassName( Type.getClass(this) );
	}

	/**
		A shortcut to `HttpContext.ufTrace`
	**/
	public inline function ufTrace( msg:Dynamic, ?pos:PosInfos ) {
		context.httpContext.ufTrace( msg, pos );
	}

	/**
		A shortcut to `HttpContext.ufLog`
	**/
	public inline function ufLog( msg:Dynamic, ?pos:PosInfos ) {
		context.httpContext.ufLog( msg, pos );
	}

	/**
		A shortcut to `HttpContext.ufWarn`
	**/
	public inline function ufWarn( msg:Dynamic, ?pos:PosInfos ) {
		context.httpContext.ufWarn( msg, pos );
	}

	/**
		A shortcut to `HttpContext.ufError`
	**/
	public inline function ufError( msg:Dynamic, ?pos:PosInfos ) {
		context.httpContext.ufError( msg, pos );
	}
}