package ufront.api;

import haxe.macro.Context;
import haxe.macro.Expr;
using StringTools;
using Lambda;

class ApiMacros
{
	macro public static function buildApiContext():Array<Field>
	{
		classPos = Context.currentPos();
		localClass = Context.getLocalClass().get();
		fields = Context.getBuildFields();

		// Add an empty constructor
		var apiConstructor = getApiConstructorField();

		// For the client
			// Define a new type, in the same package, same name but with "Client" on the end
			// The constructor initiates the connection and the error handling

		var clientClass = getClientClassDefinition();
		clientClass.fields.push(getCnxField());
		clientClass.fields.push(getClientConstructorField());

		// For each var
		for (f in fields.copy())
		{
			switch (f.kind)
			{
				case FVar(TPath(p), _):
					// Add @inject metadata so that injection goes down the line...
					var newExpr:Expr = { expr: ENew(p, []), pos: classPos };
					if (!f.meta.exists(function (me) return me.name=="inject")) {
						f.meta.push({ name:"inject", params:[], pos: f.pos });
					}

					// Define a proxy for the given type
					var typeName = p.pack.concat([p.name]).join(".");
					var type = Context.getType(typeName);
					var proxyTPath = defineProxyForType(type);

					// Create a copy of the field for the client class (change type to proxy)
					clientClass.fields.push(convertFieldToProxy(f, proxyTPath));

					// Generate an instantiation for the Proxy constructor
					var fName = f.name;
					var cnxField = macro cnx.$fName;
					var newProxyExpr:Expr = { expr: ENew(proxyTPath, [cnxField]), pos: classPos };
					var instProxyExpr = macro $i{f.name} = $newProxyExpr;
					addLineToFnBody(clientConstructorBlock, instProxyExpr);
				case _:
					// skip
			}
		}

		// Now that we have all our fields, define the client type and add our constructor to the server api
		Context.defineType(clientClass);
		fields.push(apiConstructor);
		
		return fields;
	}

	macro public static function buildApiClass():Array<Field>
	{
		classPos = Context.currentPos();
		localClass = Context.getLocalClass().get();
		var fields = Context.getBuildFields();
		
		// To compile correctly on the client, keep only the public methods, and only their signiatures - remove the actual function body.
		if (Context.defined("client"))
		{
			for (f in fields.copy())
			{
				if (f.access.has(APublic) && f.access.has(AStatic)==false)
				{
					switch (f.kind) {
						case FFun(fun):
							// Trim the function body 
							if (f.name == "new") fun.expr = macro {};
							else if (fun.ret == null) {
								fun.expr = macro return;
							}
							else fun.expr = macro return null;
						default: 
							// Not a function, get rid of it
							fields.remove(f);
					}
				}
				else
				{
					// Not a public member method, get rid of it
					fields.remove(f);
				}
			}
			return fields;
		}
		else 
		{
			// Not on the client, so leave everything as is...
			return null;
		}
	}

	macro public static function buildSpecificApiProxy():Array<Field>
	{
		for (iface in Context.getLocalClass().get().interfaces)
		{
			if (iface.t.toString() == "ufront.api.RequireApiProxy")
			{
				// If this class implements RequireApiProxy<T>, find <T>
				for (api in iface.params)
				{
					defineProxyForType(api);
				}
			}
		}
		return null;
	}

	#if macro 

	static var classPos;
	static var localClass;
	static var fields;

	static function getClientClassDefinition()
	{
		return {
			pos: classPos,
			params: [],
			pack: localClass.pack,
			name: localClass.name + "Client",
			meta: [],
			kind: TDClass(),
			isExtern: false,
			fields: []
		};
	}
	static function getCnxField()
	{
		return {
			pos: classPos,
			name: "cnx",
			meta: [],
			kind: FVar(macro :haxe.remoting.HttpAsyncConnection),
			doc: null,
			access: [APrivate]
		};
	}

	static var apiConstructorBlock:Expr;
	static function getApiConstructorField()
	{
		apiConstructorBlock = macro { super(); }
		return {
			pos: classPos,
			name: "new",
			meta: [],
			kind: FFun(
				{
					ret: null,
					params: [],
					expr: apiConstructorBlock,
					args: []
				}
			),
			doc: null,
			access: [APublic]
		};
	}

	static var clientConstructorBlock:Expr;
	static function getClientConstructorField()
	{
		clientConstructorBlock = macro {
			cnx = ufront.api.HttpAsyncConnectionWithTraces.urlConnect(url,errorHandler);
		}
		return {
			pos: classPos,
			name: "new",
			meta: [],
			kind: FFun(
				{
					ret: null,
					params: [],
					expr: clientConstructorBlock,
					args: [
						{ value: null, type: macro :String, opt: false, name: "url" },
						{ value: null, type: macro :ufront.api.HttpAsyncConnectionWithTraces.RemotingError->Void, opt: false, name: "errorHandler" },
					]
				}
			),
			doc: null,
			access: [APublic]
		};
	}

	static function defineProxyForType(type:haxe.macro.Type):Null<TypePath>
	{
		switch (type)
		{
			case TInst(t, _):
				var cls = t.get();

				// See if it already exists
				var alreadyExists = false;
				var proxyName = t.toString() + "Proxy";
				try 
				{
					var existing = Context.getType(proxyName);
					alreadyExists = true;
				} 
				catch (e:Dynamic)
				{
					if (e == 'Type not found \'$proxyName\'')
						alreadyExists = false;
					else
						throw (e);
				}

				if (!alreadyExists)
				{
					// If not, define the new type
					var complex = Context.toComplexType(type);
					var superClass = TDClass({ // haxe.remoting.AsyncProxy<app.login.LoginAPI>
						sub: null, 
						params: [TPType(complex)], 
						pack: ["haxe","remoting"], 
						name: "AsyncProxy" 
					});
					var proxyDefinition = {
						pos: classPos,
						params: [],
						pack: cls.pack,
						name: cls.name + "Proxy",
						meta: [],
						kind: superClass,
						isExtern: false,
						fields: []
					};
					Context.defineType(proxyDefinition);
				}

				// Return the TypePath
				return { sub: null, params: [], pack: cls.pack, name: cls.name + "Proxy" };
			default: // do nothing
				return null;
		}
	}

	static function convertFieldToProxy(f:Field, proxyTPath:TypePath)
	{
		return {
			pos: classPos,
			name: f.name,
			meta: f.meta,
			kind: FVar(TPath(proxyTPath)),
			doc: null,
			access: f.access
		};
	}

	static function addLineToFnBody(fnBody:Expr, line:Expr)
	{
		switch (fnBody.expr)
		{
			case EBlock(exprs):
				exprs.push(line);
			case _: trace ("fnBody was not an EBlock, so we're not adding anything");
		}
	}
	#end
}