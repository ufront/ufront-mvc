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

import ufront.web.DispatchStd;
import haxe.web.Dispatch.DispatchConfig;
import haxe.web.Dispatch.DispatchError;
import haxe.web.Dispatch.DispatchRule;
import ufront.web.HttpContext;
import ufront.web.mvc.ControllerContext;
private class Redirect { public function new() {} }


// typedef DispatchConfig = haxe.web.Dispatch.DispatchConfig;
// typedef Lock<T> = T;
// typedef DispatchError = haxe.web.Dispatch.DispatchError;

// class Dispatch extends haxe.web.Dispatch {
	// Had to change this as there was a part of the macro that wouldn't let us subclass it.  DispatchStd is exactly the same as haxe.Web.dispatch except that you can subclass it and use it for subDispatches
class Dispatch extends ufront.web.DispatchStd {

	public var method:String;
	public var httpContext:HttpContext;

	public function new(url:String, params, httpContext, ?method) {
		super (url, params);
		this.httpContext = httpContext;
		this.method = (method != null) ? method.toLowerCase() : null;
	}

	// This is the same, but makeConfig() will refer to the static function in this class, not the super class
	override public macro function dispatch( ethis : Expr, obj : ExprOf<{}> ) : ExprOf<Void> {
		var p = Context.currentPos();
		var cfg = makeConfig(obj);
		return { expr : ECall({ expr : EField(ethis, "runtimeDispatch"), pos : p }, [cfg]), pos : p };
	}

	override function resolveName( name : String ) {
		return "do" + name.charAt(0).toUpperCase() + name.substr(1);
	}

	function resolveNames( name : String ) {
		var arr = [];
		if ( method != null ) arr.push( method+"_"+resolveName(name) );
		arr.push( resolveName(name) );
		return arr;
	}

	// The main difference is that we call resolveNames(), and match against
	// multiple names, so that we can find post_doSubmit() etc
	// We also force lower-case the method name, making Dispatch case insensitive.
	// We also have this runtimeReturnDispatch, which returns the function result. 
	// runtimeDispatch() is still available but just calls this
	public function runtimeReturnDispatch( cfg : DispatchConfig ):{ result:Dynamic, controllerContext:ControllerContext } {
		name = parts.shift();
		if( name == null )
			name = "doDefault";
		var names = resolveNames(name);
		this.cfg = cfg;
		var r : DispatchRule = null;
		trace (cfg);
		for ( n in names ) {
			trace (n);
			r = Reflect.field(cfg.rules, n);
			if ( r != null ) { name = n; break; }
		}
		if( r == null ) {
			r = Reflect.field(cfg.rules, "doDefault");
			if( r == null )
				throw DENotFound(name);
			parts.unshift(name);
			name = "doDefault";
		}
		var args = [];
		subDispatch = false;
		loop(args, r);
		if( parts.length > 0 && !subDispatch ) {
			if( parts.length == 1 && parts[parts.length - 1] == "" ) parts.pop() else throw DETooManyValues;
		}
		try {
			var field = Reflect.field(cfg.obj, name);
			return {
				result: Reflect.callMethod(cfg.obj, Reflect.field(cfg.obj, name), args),
				controllerContext: cfg.obj.controllerContext
			}
		} catch( e : Redirect ) {
			return runtimeReturnDispatch(cfg);
		}
	}

	override public function runtimeDispatch( cfg : DispatchConfig ) {
		runtimeReturnDispatch( cfg );
	}

	// The only differences is building 
	//  - we return an expression for new ufront.web.Dispatcher instead of haxe.web.Dispatcher
	//  - and we capture the HTTP method too

	public static macro function run( url : ExprOf<String>, params : ExprOf<haxe.ds.StringMap<String>>, obj : ExprOf<{}>, ?method : ExprOf<String> ) : ExprOf<Void> {
		var p = Context.currentPos();
		var cfg = makeConfig(obj);
		var args = [url,params];
		if (method != null) { args.push(method); }
		return { expr : ECall({ expr : EField({ expr : ENew({ name : "Dispatch", pack : ["ufront","web"], params : [], sub : null },args), pos : p },"runtimeDispatch"), pos : p },[cfg]), pos : p };
	}

	#if macro 

	// Main changes
	//  - force lower case names in config
	//  - allow post_ and get_
	static function makeConfig( obj : Expr ) {
		var p = obj.pos;
		if( Context.defined("display") )
			return { expr :  EObjectDecl([ { field : "obj", expr : obj }, { field : "rules", expr : { expr : EObjectDecl([]), pos : p } } ]), pos : p };
		var t = Context.typeof(obj);
		switch( Context.follow(t) ) {
		case TAnonymous(fl):
			var fields = [];
			for( f in fl.get().fields ) {
				if( f.name.substr(0, 2) != "do" )
					continue;
				if (!f.meta.has(':keep'))
					f.meta.add(':keep', [], f.pos);
				var r = DispatchStd.makeRule(f);
				fields.push( { field : "do"+f.name.substr(2), expr : Context.makeExpr(r,p) } );
			}
			if( fields.length == 0 )
				Context.error("No dispatch method found", p);
			var rules = { expr : EObjectDecl(fields), pos : p };
			return { expr : EObjectDecl([ { field : "obj", expr : obj }, { field : "rules", expr : rules } ]), pos : p };
		case TInst(i, _):
			var i = i.get();
			// store the config inside the class metadata (only once)
			if( !i.meta.has("dispatchConfig") ) {
				var fields = {};
				var tmp = i;
				while( true ) {
					for( f in tmp.fields.get() ) {
						var name = f.name;
						if( f.meta.has(":method") ) name = name.substr(name.indexOf("_") + 1);
						if( name.substr(0, 2) != "do" )
							continue;
						if (!f.meta.has(':keep'))
							f.meta.add(':keep', [], f.pos);
						var r = DispatchStd.makeRule(f);
						for( m in f.meta.get() )
							if( m.name.charAt(0) != ":" ) {
								DispatchStd.checkMeta(f);
								r = DRMeta(r);
								break;
							}
						Reflect.setField(fields, f.name, r);
					}
					if( tmp.superClass == null )
						break;
					tmp = tmp.superClass.t.get();
				}
				if( Reflect.fields(fields).length == 0 )
					Context.error("No dispatch method found", p);
				var str = DispatchStd.serialize(fields);
				i.meta.add("dispatchConfig", [ { expr : EConst(CString(str)), pos : p } ], p);
			}
			return { expr : EUntyped ({ expr : ECall({ expr : EField(Context.makeExpr(DispatchStd,p),"extractConfig"), pos : p },[obj]), pos : p }), pos : p };
		default:
			Context.error("Configuration should be an anonymous object",p);
		}
		return null;
	}

	#end

}
