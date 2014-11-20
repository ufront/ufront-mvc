package ufront.api;

import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.EnumFlags;
using tink.CoreApi;
using tink.MacroApi;
using haxe.macro.Tools;
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
		return ClassBuilder.run([
			checkTypeHints,
			addReturnTypeMetadata,
			transformClient,
//			createAsyncClass
		]);
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

	/**
		Check that the user has provided explicit type hints all round, because we need them for our macros.
	**/
	static function checkTypeHints( cb:ClassBuilder ) {
		for ( member in cb ) {
			if ( member.isPublic && !member.isStatic ) {
				switch member.getFunction() {
					case Success(fn):
						if ( fn.ret==null )
							Context.error( 'Field ${member.name} requires an explicit return type', member.pos );
						for ( arg in fn.args ) {
							if ( arg.type==null )
								Context.error( 'Argument ${arg.name} on field ${member.name} requires an explicit type declaration', member.pos );
						}
					default:
				}
			}
			else {
				// Not a public member method, get rid of it
				cb.removeMember( member );
			}
		}
	}

	/**
		To compile correctly on the client, keep only the public methods, and only their signiatures - remove the actual function body.
	**/
	static function transformClient( cb:ClassBuilder ) {
		// To compile correctly on the client, keep only the public methods, and only their signiatures - remove the actual function body.
		if ( Context.defined("client") ) {
			for ( member in cb ) {
				if ( member.isPublic && !member.isStatic ) {
					switch member.kind {
						case FFun(fun):
							// Trim the function body
							fun.expr =
 								if ( fun.ret==null ) macro {};
								else macro return null;
						default:
							// Not a function, get rid of it
							cb.removeMember( member );
					}
				}
				else {
					// Not a public member method, get rid of it
					cb.removeMember( member );
				}
			}
			// Clear out the constructor as well
			if ( cb.hasConstructor() ) {
				@:privateAccess cb.constructor.oldStatements = [];
				@:privateAccess cb.constructor.nuStatements = [];
			}
		}
	}

	/**
		Add `@returnFuture`, `@returnOutcome` and `@returnVoid` metadata to a field so we know how to handle it at runtime.
	**/
	static function addReturnTypeMetadata( cb:ClassBuilder ) {
		for ( member in cb ) {
			if ( member.isPublic && !member.isStatic ) {
				switch member.getFunction() {
					case Success(fn):
						var returnType = fn.ret.toType();
						var returnFlags = getResultWrapFlagsForReturnType( returnType );
						if (returnFlags.has(ARTFuture)) member.addMeta( "returnFuture" );
						if (returnFlags.has(ARTOutcome)) member.addMeta( "returnOutcome" );
						if (returnFlags.has(ARTVoid)) member.addMeta( "returnVoid" );
					default:
				}
			}
		}
	}
	
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
			cnx = haxe.remoting.HttpAsyncConnectionWithTraces.urlConnect(url,errorHandler);
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
						{ value: null, type: macro :haxe.remoting.RemotingError->Void, opt: false, name: "errorHandler" },
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
			case _:
				fnBody.expr = EBlock([ fnBody, line ]);
		}
	}
	
	/**
		Return a set of flags showing what sort of result the API call returns.

		Basic rules:

		- If it is `Surprise<Dynamic,Dynamic>`, it is a future AND an outcome
		- If it is `Future<Dynamic>`, it is a future
		- If it is `Outcome<Dynamic,Dynamic>`, it is an outcome
		- If it is `Dynamic`, it is a normal value (neither future nor outcome)
		- If it is void, mark it as such
	**/
	static function getResultWrapFlagsForReturnType( returnType:haxe.macro.Type ):EnumFlags<ApiReturnType> {
		var returnFlags = new EnumFlags<ApiReturnType>();
		
		if ( returnType.unify((macro :StdTypes.Void).toType()) ) {
			returnFlags.set( ARTVoid );
		}
		else if ( returnType.unify((macro :tink.core.Future.Surprise<StdTypes.Dynamic,StdTypes.Dynamic>).toType()) ) {
			returnFlags.set( ARTFuture );
			returnFlags.set( ARTOutcome );
		}
		else if ( returnType.unify((macro :tink.core.Future<StdTypes.Dynamic>).toType()) ) {
			returnFlags.set( ARTFuture );
		}
		else if ( returnType.unify((macro :tink.core.Outcome<StdTypes.Dynamic,StdTypes.Dynamic>).toType()) ) {
			returnFlags.set( ARTOutcome );
		}
		return returnFlags;
	}
	#end
}

enum ApiReturnType {
	ARTFuture;
	ARTOutcome;
	ARTVoid;
}