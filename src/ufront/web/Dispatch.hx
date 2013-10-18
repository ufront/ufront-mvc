/*
 * Copyright (C)2005-2012 Haxe Foundation
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 */
package ufront.web;

#if macro
import haxe.macro.Expr;
import haxe.macro.Type.ClassField;
import haxe.macro.Context;
#end

import haxe.web.Dispatch;
import tink.core.Signal;
import tink.core.Noise;
import ufront.web.context.HttpContext;

/**
	An extension of `haxe.web.Dispatch` modified for use in the ufront framework.

	Key differences:

	- It can check for HTTP methods (get/post) etc and specialised actions for those.
	- Dispatching returns the result of the called action
	- Processing the dispatch and executing the action are separated, so code (for example, ufront's DispatchModule) can intercept execution inbetween stages.
	- The controller, action and arguments that are used are recorded, to assist with unit testing.
	- It is case insensitive.  So "doSomethingLong" will resolve to "/somethinglong/" or "/SomethingLONG/" etc

	The important static macros and methods are still available here and function similarly to those in `haxe.web.Dispatch`, except for the changes described above.
**/
class Dispatch extends haxe.web.Dispatch 
{	
	/** 
		The method used in the request.  

		Is set via the constructor.  Whatever value this is set to will be transformed to lowercase.
	**/
	public var method(default,null):String;
	
	/** 
		The controller / API object that was used.

		After a successful `processDispatchRequest`, it will contain the object (controller) to be used
		for dispatching.  This may be the object passed to Dispatch, or it may be another object, that
		was used as a sub-dispatch.

		This can be useful to get Controller Information while processing an ActionResult, for example,
		while trying to find the appropriate View to use for a controller.

		Before a successful `processDispatchRequest`, it will be null.

		This value can be changed, and will affect `executeDispatchRequest()`, do so at your peril.
	**/
	public var controller:Null<{}>;
	
	/** 
		The name of the selected action to be used in the dispatch.

		After a successful `processDispatchRequest`, it will contain the name of the action that
		dispatch has chosen to execute.  eg. `doSomething` if `doSomething()` is to be called.

		This can be useful to get Action Information while processing an ActionResult, for example,
		while trying to find the appropriate View to use for an action.

		Before a successful `processDispatchRequest`, it will be null.

		This value can be changed, and will affect `executeDispatchRequest()`, do so at your peril.
	**/
	public var action:Null<String>;
	
	/** 
		The arguments created based on the request.

		After a successful `processDispatchRequest`, it will contain an array of the arguments sent to
		the given action.

		Before a successful `processDispatchRequest`, it will be null.

		This value can be changed, and will affect `executeDispatchRequest()`, do so at your peril.
	**/
	public var arguments:Null<Array<Dynamic>>;

	/**
		Fires whenever `processDispatchRequest` is called.

		This allows you to listen to changes to the controller, action and arguments and process them accordingly.
	**/
	public var onProcessDispatchRequest:Signal<Noise>;
	public var onProcessDispatchRequestTrigger:SignalTrigger<Noise>;

	/**
		Construct a new Dispatch object, for the given URL, parameters and HTTP method
	**/
	public function new( url:String, params:Map<String,String>, ?method:String ) {
		super (url, params);
		this.onProcessDispatchRequestTrigger = Signal.trigger();
		this.onProcessDispatchRequest = onProcessDispatchRequestTrigger.asSignal();
		this.method = (method!=null) ? method.toLowerCase() : null;
		this.controller = null;
		this.action = null;
		this.arguments = null;
	}

	/**
		Dispatch a request and return the resulting value.

		Same as `haxe.web.Dispatch`, except it uses the ufront version of `makeConfig()`, and will call
		`runtimeReturnDispatch()`, not `runtimeDispatch()`, meaning that this will return a value.
	**/
	public macro function returnDispatch( ethis:Expr, obj:ExprOf<{}> ):ExprOf<Dynamic> {
		var p = Context.currentPos();
		var cfg = makeConfig(obj);
		return macro $ethis.runtimeReturnDispatch($cfg);
	}

	/**
		Will return an array of possible names. 

		If method is not null, it will match '$method_$name'. 

		For example:

		'someAction' with no method will produce ['doSomeAction']  
		'someAction' with 'post' method will produce ['post_doSomeAction', 'doSomeAction']
	**/
	function resolveNames( name:String ) {
		var arr = [];
		if ( method != null ) arr.push( method+"_"+name );
		arr.push( name );
		return arr;
	}

	/**
		Process the request and find the controller, action and arguments to be used.
		
		The logic in processing the request is slightly different to `haxe.web.Dispatch`

		Full list of differences:

		* We call resolveNames(), and match against multiple names, so that we can find 
		  `post_doSubmit()` etc
		* We also make the method name lower-case, making Dispatch case insensitive.
		* When a successful match is found, we populate the "controller" and "action" and 
		  "argument" properties of the Dispatch object.
		
		This function does not execute the result, it merely populates `controller`, `action`
		and `argument` properties.  Use `executeDispatchRequest` to then execute this request.
	**/
	public function processDispatchRequest( cfg:DispatchConfig ) {
		var partName = parts.shift();
		if( partName==null || partName=="" )
			partName = "default";
		var names = resolveNames('do$partName');
		this.cfg = cfg;
		var name:String = null;
		var r:DispatchRule = null;
		for ( n in names ) {
			for ( fieldName in Reflect.fields(cfg.rules) ) {
				var lcName = fieldName.toLowerCase();
				if ( lcName==n.toLowerCase() ) {
					r = Reflect.field( cfg.rules, fieldName );
					name = fieldName;
					break;
				}
			}
			if ( name!=null ) break;
		}
		if( r==null ) {
			r = Reflect.field( cfg.rules, "doDefault" );
			if( r==null )
				throw DENotFound( name );
			parts.unshift( partName );
			name = "doDefault";
		}
		var args = [];
		subDispatch = false;
		loop( args, r );
		if( parts.length > 0 && !subDispatch ) {
			if( parts.length==1 && parts[parts.length-1]=="" ) 
				parts.pop()
			else 
				throw DETooManyValues;
		}
		this.controller = cfg.obj;
		this.action = name;
		this.arguments = args;
		onProcessDispatchRequestTrigger.trigger( null );
	}

	/**
		Will execute the action, controller and arguments specified by `processDispatchRequest`

		The result of the action will be returned.

		If `processDispatchRequest`has not been run, `DispatchError.DEMissing` will be thrown.
	
		This method will not catch or handle `Redirect` exceptions in the same way as `runtimeReturnDispatch`.  If you are calling this method manually you should account for this.
	**/
	public function executeDispatchRequest():Dynamic {
		if ( controller==null || action==null || arguments==null )
			throw DEMissing;
		
		var actionMethod = Reflect.field(controller, action);
		return Reflect.callMethod(controller, actionMethod, arguments);
	}

	/**
		The same as `runtimeReturnDispatch`, except it does not return a result, so it is consistent with the super class.
	**/
	override public function runtimeDispatch( cfg:DispatchConfig ) {
		runtimeReturnDispatch( cfg );
	}

	/**
		This simple calls `processDispatchRequest`,followed by `executeDispatchRequest`

		If a `Redirect` is thrown, it will rerun the two method recursively until a result is reached or an error thrown.

		So the functionality is similar to the `runtimeDispatch` in `haxe.web.Dispatch`, except ufront's processing rules are used, and a result is returned.
	**/
	public function runtimeReturnDispatch( cfg:DispatchConfig ) {
		processDispatchRequest( cfg );
		try {
			return executeDispatchRequest();
		} catch( e:Redirect ) {
			processDispatchRequest( cfg );
			return executeDispatchRequest();
		}
	}

	/** When tracing arguments, a Dispatch argument can cause recursive errors.  Better to just have this return a String **/
	public function toString() return Type.getClassName( Type.getClass(this) );

	/**
		
		A macro similar to `haxe.web.Dispatch.run()`, with the following differences:

		* We create a new `ufront.web.Dispatch` instead of `haxe.web.Dispatch` instance.
		* We call `runtimeReturnDispatch` followed by `executeDispatchRequest`, returning the result of the action called.
		* We allow you to specify the HTTP method, which can be used to trigger method-specific actions
	**/
	public static macro function run( url:ExprOf<String>, params:ExprOf<haxe.ds.StringMap<String>>, ?method:ExprOf<String>, obj:ExprOf<{}> ):ExprOf<Dynamic> {
		var p = Context.currentPos();
		var cfg = makeConfig(obj);
		var args = [url,params];
		if (method != null) { args.push(method); }
		return macro new ufront.web.Dispatch($a{args}).runtimeReturnDispatch($cfg);
	}

	/**
		Generates a DispatchConfig object at macro time

		The difference is that this uses the ufront `makeConfig` function, which:

		* Allows `$method_doSomething` eg `post_doGetName` methods
		* Save all names as lower case, making `ufront.web.Dispatch` case insensitive
	**/
	public static macro function make( obj:ExprOf<{}> ):ExprOf<DispatchConfig> {
		return makeConfig(obj);
	}

	#if macro 
		static function makeConfig( obj:Expr ) {
			var p = obj.pos;
			if( Context.defined("display") )
				return { expr: EObjectDecl([ { field:"obj", expr:obj }, { field:"rules", expr:{ expr:EObjectDecl([]), pos:p } } ]), pos:p };
			var t = Context.typeof(obj);
			switch( Context.follow(t) ) {
			case TAnonymous(fl):
				var fields = [];
				for( f in fl.get().fields ) {
					if( f.name.substr(0, 2) != "do" )
						continue;
					if (!f.meta.has(':keep'))
						f.meta.add(':keep', [], f.pos);
					var r = haxe.web.Dispatch.makeRule(f);
					fields.push( { field:"do"+f.name.substr(2), expr:Context.makeExpr(r,p) } );
				}
				if( fields.length==0 )
					Context.error("No dispatch method found", p);
				var rules = { expr:EObjectDecl(fields), pos:p };
				return { expr:EObjectDecl([ { field:"obj", expr:obj }, { field:"rules", expr:rules } ]), pos:p };
			case TInst(i, _):
				var i = i.get();
				// store the config inside the class metadata (only once)
				if( !i.meta.has("dispatchConfig") ) {
					var fields = {};
					var tmp = i;
					while( true ) {
						for( f in tmp.fields.get() ) {
							var name = f.name;
							if( name.indexOf("_do")>-1 ) name = name.substr(name.indexOf("_") + 1);
							if( name.substr(0, 2) != "do" )
								continue;
							if (!f.meta.has(':keep'))
								f.meta.add(':keep', [], f.pos);
							var r = haxe.web.Dispatch.makeRule(f);
							for( m in f.meta.get() )
								if( m.name.charAt(0) != ":" ) {
									haxe.web.Dispatch.checkMeta(f);
									r = DRMeta(r);
									break;
								}
							Reflect.setField(fields, f.name, r);
						}
						if( tmp.superClass==null )
							break;
						tmp = tmp.superClass.t.get();
					}
					if( Reflect.fields(fields).length==0 )
						Context.error("No dispatch method found", p);
					var str = haxe.web.Dispatch.serialize(fields);
					i.meta.add("dispatchConfig", [ { expr:EConst(CString(str)), pos:p } ], p);
				}
				return { expr:EUntyped ({ expr:ECall({ expr:EField(Context.makeExpr(haxe.web.Dispatch,p),"extractConfig"), pos:p },[obj]), pos:p }), pos:p };
			default:
				Context.error("Configuration should be an anonymous object",p);
			}
			return null;
		}

	#end
}