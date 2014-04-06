package ufront.api;

import haxe.PosInfos;
import ufront.log.Message;

/** 
	This class provides a build macro that will take some extra precautions to make
	sure your Api class compiles successfully on the client as well as the server.

	Basically, the build macro strips out private methods, and the method bodies of public methods,
	so all that is left is the method signiature.

	This way, the Proxy class will still be created successfully, but none of the server-side APIs
	get tangled up in client side code.
**/
@:autoBuild(ufront.api.ApiMacros.buildApiClass())
class UFApi 
{
	/**
		A default constructor.  

		This has no effect, it just exists so you don't need to create a constructor on every child class. 
	**/
	public function new() {}
	
	/**
		The messages list.  This must be injected for `ufTrace`, `ufLog`, `ufWarn` and `ufError` to function correctly.

		When called from a web context, this will usually result in the HttpContext's `messages` array being pushed to.
	**/
	@inject public var messages:MessageList;

	/**
		A shortcut to `HttpContext.ufTrace`

		A `messages` array must be injected for these to function correctly.  Use `ufront.handler.MVCHandler` and `ufront.handler.RemotingHandler` to inject this correctly.
	**/
	@:noCompletion
	inline function ufTrace( msg:Dynamic, ?pos:PosInfos ) {
		messages.push({ msg: msg, pos: pos, type:Trace });
	}

	/**
		A shortcut to `HttpContext.ufLog`

		A `messages` array must be injected for these to function correctly.  Use `ufront.handler.MVCHandler` and `ufront.handler.RemotingHandler` to inject this correctly.
	**/
	@:noCompletion
	inline function ufLog( msg:Dynamic, ?pos:PosInfos ) {
		messages.push({ msg: msg, pos: pos, type:Log });
	}

	/**
		A shortcut to `HttpContext.ufWarn`

		A `messages` array must be injected for these to function correctly.  Use `ufront.handler.MVCHandler` and `ufront.handler.RemotingHandler` to inject this correctly.
	**/
	@:noCompletion
	inline function ufWarn( msg:Dynamic, ?pos:PosInfos ) {
		messages.push({ msg: msg, pos: pos, type:Warning });
	}

	/**
		A shortcut to `HttpContext.ufError`

		A `messages` array must be injected for these to function correctly.  Use `ufront.handler.MVCHandler` and `ufront.handler.RemotingHandler` to inject this correctly.
	**/
	@:noCompletion
	inline function ufError( msg:Dynamic, ?pos:PosInfos ) {
		messages.push({ msg: msg, pos: pos, type:Error });
	}

	/**
		Print the current class name
	**/
	@:noCompletion
	public function toString() {
		return Type.getClassName( Type.getClass(this) );
	}
}

