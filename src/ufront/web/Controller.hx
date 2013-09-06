package ufront.web;

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
		This is not set automatically, it is up to the DispatchModule or similar to pass the context to the controller.  
		This has a setter that you can override if you want to perform any initialisation logic when the context is set.
	**/
	@:isVar
	public var context(default,set):Null<ActionContext>;
	function set_context(v) return context=v;

	/**
		Empty constructor.  
		Included so that you don't need a constructor in your container
	**/
	public function new() {}

	/**
		A default toString() to aid in debugging.  Just prints the current class name.
	**/
	public function toString() {
		return Type.getClassName( Type.getClass(this) );
	}
}