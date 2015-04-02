package ufront.api;

import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;
import haxe.EnumFlags;
using haxe.macro.Tools;
using tink.CoreApi;
using tink.MacroApi;
using StringTools;
using Lambda;

class ApiMacros {

	//
	// BUILD METHODS
	//

	public static function buildApiContext():Array<Field> {
		return ClassBuilder.run([
			addApiListMetaToContext,
			addInjectMetaToContextFields,
		]);
	}

	public static function buildClientApiContext():Array<Field> {
		return ClassBuilder.run([
			createClientContextProxyFields,
		]);
	}

	public static function buildApiClass():Array<Field> {
		return ClassBuilder.run([
			checkTypeHints,
			addReturnTypeMetadata,
			transformClient,
		]);
	}

	public static function buildAsyncApiProxy() {
		return ClassBuilder.run([
			addAsyncProxyMemberMethods,
			addAsyncApiMetadata.bind( "asyncApi" ),
			addInjectApiMethod,
		]);
	}

	public static function buildAsyncApiCallbackProxy() {
		return ClassBuilder.run([
			addCallbackProxyMemberMethods,
			addAsyncApiMetadata.bind( "asyncCallbackApi" ),
			addInjectApiMethod,
		]);
	}

	public static function buildSpecificApiProxy():Array<Field> {
		for (iface in Context.getLocalClass().get().interfaces) {
			if ( iface.t.toString()=="ufront.remoting.RequireAsyncCallbackApi" ) {
				for ( api in iface.params ) {
					defineCallbackProxyForType( api );
				}
			}
		}
		return null;
	}

	#if macro

	//
	// CLASSBUILDER FUNCTIONS
	//

	static function addApiListMetaToContext( cb:ClassBuilder ) {
		var apis = [];
		for ( member in cb ) {
			switch member.getVar().sure().type {
				case TPath(p):
					var typeName = p.pack.concat([p.name]).join(".");
					apis.push( macro $v{typeName} );
				case _:
			}
		}
		cb.target.meta.remove( "apiList" );
		cb.target.meta.add( "apiList", apis, cb.target.pos );
	}
	static function addInjectMetaToContextFields( cb:ClassBuilder ) {
		for ( member in cb ) {
			if ( member.isStatic==false && member.kind.match(FVar(_,_)) ) {
				member.addMeta( "inject" );
				member.publish();
			}
		}
	}

	static function createClientContextProxyFields( cb:ClassBuilder ) {
		var serverContext = getClassTypeFromFirstTypeParam( cb ).get();

		// Get (or create) a constructor.
		// The tink_macro default will forward all arguments (url and errorHandler), which is fine for us.
		var constructor = cb.getConstructor();

		for ( field in serverContext.fields.get() ) {
			// Create the proxy if it doesn't exist yet.
			var apiType = field.type;
			var typePathForProxy = defineCallbackProxyForType( apiType );
			var proxyComplexType = TPath( typePathForProxy );

			// Add the field.
			var fieldName = field.name;
			var tmp = macro class Tmp {
				public var $fieldName:$proxyComplexType;
			}
			cb.addMember( tmp.fields[0] );

			// Add the initialisation statement.
			constructor.addStatement( macro this.$fieldName = new $typePathForProxy( this.cnx ) );
		}
	}

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
		}
	}

	/**
		Replace all the public API methods on the client with synchronous remoting calls, that have a matching type signiature so they can be used interchangeably.
		Remove any member methods or variables which are not part of the public API.
	**/
	static function transformClient( cb:ClassBuilder ) {
		// To compile correctly on the client, keep only the public methods, and only their signiatures - remove the actual function body.
		if ( Context.defined("client") ) {
			for ( member in cb ) {
				if ( member.isPublic==true && !member.isStatic ) {
					switch member.kind {
						case FFun(fun):
							var remotingCall = buildSyncFnBody(member.name,fun.args);
							var returnsVoid = fun.ret==null || fun.ret.match(TPath({name:"Void"}));
							fun.expr =
 								if ( returnsVoid ) macro $remotingCall;
								else macro return $remotingCall;
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
						var returnType = fn.ret;
						var returnFlags = getResultWrapFlagsForReturnType( returnType, member.pos );
						var int = returnFlags.toInt();
						// If the metadata does not already exist, overwrite it, rather than add it.
						var metaParams = [macro $v{int}];
						switch member.extractMeta("returnType") {
							case Success(metaEntry): metaEntry.params = metaParams;
							case Failure(_): member.addMeta( "returnType", metaParams );
						}
					default:
				}
			}
		}
	}

	/**
		We cannot use `@inject public var api:T` on our UFAsyncApi objects, because minject does not play nice with generics.
		Instead we add a `@inject public var setApi()` method.
		This should also set the `className` field.
	**/
	static function addInjectApiMethod( cb:ClassBuilder ) {
		var syncApiClassType = getClassTypeFromFirstTypeParam( cb );
		if ( syncApiClassType!=null ) {
			var syncApiName = syncApiClassType.toString();
			var syncApiReference = syncApiName.resolve();
			var tmp = macro class Tmp {
				@inject public function injectApi( injector:minject.Injector ) {
					#if server
						this.api =
							try injector.getInstance( $syncApiReference )
							catch (e:Dynamic) throw 'Failed to inject '+Type.getClassName($syncApiReference)+' into '+Type.getClassName(Type.getClass(this));
					#end
					this.className = $v{syncApiName};
				}
			}
			cb.addMember( tmp.fields[0] );
		}
	}

	/**
		Add some metadata to `UFAsyncApi` to map the API class name to the AsyncAPI class name, so we can inject both at runtime.
	**/
	static function addAsyncApiMetadata( metaName:String, cb:ClassBuilder ) {
		var syncApiClassType = getClassTypeFromFirstTypeParam( cb );
		if ( syncApiClassType!=null ) {
			var pack = cb.target.pack.join(".");
			var name = cb.target.name;
			var asyncName = (pack!="") ? '$pack.$name' : name;

			var meta = syncApiClassType.get().meta;
			if ( meta.has(metaName) )
				meta.remove( metaName );
			meta.add( metaName, [macro $v{asyncName}], cb.target.pos );
		}
	}

	static function addAsyncProxyMemberMethods( cb:ClassBuilder ) {
		function getExtraArgs( _, _ ) return [];
		addProxyMemberMethods( cb, getExtraArgs, buildAsyncFnBody, asyncifyReturnType );
	}

	static function addCallbackProxyMemberMethods( cb:ClassBuilder ) {
		function getReturnType(_,_) return macro :Void;
		addProxyMemberMethods( cb, getCallbackArgsForField, buildAsyncCallbackFnBody, getReturnType );
	}

	/**
		For example:

		- `LoginApiAsync extends UFAsyncApi<LoginApi>`
		- Find all the public methods on LoginApi
		- Create an appropriate Async method, using `getExtraArgs`, `getFnBoy` and `getReturnType` to transform it.
		- See `addAsyncProxyMemberMethods` and `addCallbackProxyMemberMethods` for examples.

		@param cb The current ClassBuilder.
		@param getExtraArgs A function that takes the return type and the flags and generates extra arguments for the field.
		@param getFnBody A function that takes the field name, arguments and return type flags and generates a function body expression.
		@param getReturnType A function that takes the return type and the flags and generates a new return type to use for the field.
	**/
	static function addProxyMemberMethods( cb:ClassBuilder, getExtraArgs:haxe.macro.Type->EnumFlags<ApiReturnType>->Array<FunctionArg>, getFnBody:String->Array<{name:String}>->EnumFlags<ApiReturnType>->Expr, getReturnType:haxe.macro.Type->EnumFlags<ApiReturnType>->ComplexType  ) {
		var apiClassType = getClassTypeFromFirstTypeParam( cb );
		var pos = cb.target.pos;
		if ( apiClassType!=null ) {
			for ( classField in apiClassType.get().fields.get() ) {
				if ( classField.isPublic ) {
					var fieldType = classField.type.reduce();
					switch fieldType {
						case TFun( args, ret ):
							var flags = getResultWrapFlagsForReturnType( ret.toComplex(), pos );
							var member:Member = {
								pos: pos,
								name: classField.name,
								meta: [/** Do we need to add the return type meta? **/],
								kind: FFun({
									ret: getReturnType( ret, flags ),
									// TODO: write some unit tests to check type parameters in API functions are correctly supported.
									params: [for (p in classField.params) { params:[], name:p.name, constraints:[p.t.toComplex()]}],
									expr: getFnBody( classField.name, args, flags ),
									args: [for (arg in args) { name:arg.name, opt:arg.opt, type:arg.t.toComplex(), value:null }].concat( getExtraArgs(ret,flags) ),
								}),
								doc: 'Async call for `${apiClassType.toString()}.${classField.name}()`',
								access: [ APublic ],
							}
							cb.addMember( member );
						case _:
					}
				}
			}
		}
	}

	//
	// HELPER METHODS
	//

	static function getClassTypeFromFirstTypeParam( cb:ClassBuilder ):Null<haxe.macro.Ref<ClassType>> {
		var params = cb.target.superClass.params;
		var pos = cb.target.pos;
		if ( params.length!=1 ) {
			pos.errorExpr( 'Expected exactly one type parameter' );
			return null;
		}
		var origApi = params[0];
		switch origApi {
			case TInst(apiClassTypeRef,params):
				return apiClassTypeRef;
			case _:
				pos.errorExpr( 'Expected type parameter to be a class' );
				return null;
		}
	}

	/**
		Change `doSomething():String` to `doSomething:Suprise<String,RemotingError<Noise>` etc.
	**/
	static function asyncifyReturnType( rt:haxe.macro.Type, flags:EnumFlags<ApiReturnType> ):ComplexType {
		var typeParams = switch rt {
			case TType(_,params): params;
			default: [];
		}
		if ( flags.has(ARTVoid) ) {
			return macro :tink.core.Future.Surprise<Noise,ufront.remoting.RemotingError<tink.core.Noise>>;
		}
		else if ( flags.has(ARTFuture) && flags.has(ARTOutcome) ) {
			var successType = typeParams[0].toComplex();
			var failureType = typeParams[1].toComplex();
			return macro :tink.core.Future.Surprise<$successType,ufront.remoting.RemotingError<$failureType>>;
		}
		else if ( flags.has(ARTFuture) ) {
			var type = typeParams[0].toComplex();
			return macro :tink.core.Future.Surprise<$type,ufront.remoting.RemotingError<tink.core.Noise>>;
		}
		else if ( flags.has(ARTOutcome) ) {
			var successType = typeParams[0].toComplex();
			var failureType = typeParams[1].toComplex();
			return macro :tink.core.Future.Surprise<$successType,ufront.remoting.RemotingError<$failureType>>;
		}
		else {
			var type = rt.toComplex();
			return macro :tink.core.Future.Surprise<$type,ufront.remoting.RemotingError<tink.core.Noise>>;
		}
	}

	static function getCallbackArgsForField( rt:haxe.macro.Type, flags:EnumFlags<ApiReturnType> ):Array<FunctionArg> {
		var typeParams = switch rt {
			case TType(_,params): params;
			default: [];
		}
		var onResultType:ComplexType,
			onErrorType:ComplexType;
		if ( flags.has(ARTVoid) ) {
			onResultType = macro :tink.core.Callback<tink.core.Noise>;
			onErrorType = macro :tink.core.Callback<ufront.remoting.RemotingError<tink.core.Noise>>;
		}
		else if ( flags.has(ARTFuture) && flags.has(ARTOutcome) ) {
			var successType = typeParams[0].toComplex();
			var failureType = typeParams[1].toComplex();
			onResultType = macro :tink.core.Callback<$successType>;
			onErrorType = macro :tink.core.Callback<ufront.remoting.RemotingError<$failureType>>;
		}
		else if ( flags.has(ARTFuture) ) {
			var type = typeParams[0].toComplex();
			onResultType = macro :tink.core.Callback<$type>;
			onErrorType = macro :tink.core.Callback<ufront.remoting.RemotingError<tink.core.Noise>>;
		}
		else if ( flags.has(ARTOutcome) ) {
			var successType = typeParams[0].toComplex();
			var failureType = typeParams[1].toComplex();
			onResultType = macro :tink.core.Callback<$successType>;
			onErrorType = macro :tink.core.Callback<ufront.remoting.RemotingError<$failureType>>;
		}
		else {
			var type = rt.toComplex();
			onResultType = macro :tink.core.Callback<$type>;
			onErrorType = macro :tink.core.Callback<ufront.remoting.RemotingError<tink.core.Noise>>;
		}
		return [
			{ name:"onResult", opt:false, type:onResultType, value:null },
			{ name:"onError", opt:true, type:onErrorType, value:null },
		];
	}

	static function buildAsyncFnBody( name:String, args:Array<{name:String}>, flags:EnumFlags<ApiReturnType> ):Expr {
		var argIdents = [ for(a in args) macro $i{a.name} ];
		return macro return _makeApiCall( $v{name}, $a{argIdents}, haxe.EnumFlags.ofInt($v{flags}) );
	}

	static function buildAsyncCallbackFnBody( name:String, args:Array<{name:String}>, flags:EnumFlags<ApiReturnType> ):Expr {
		var argIdents = [ for(a in args) macro $i{a.name} ];
		return macro return _makeApiCall( $v{name}, $a{argIdents}, onResult, onError );
	}

	static function buildSyncFnBody( name:String, args:Array<{type:Null<ComplexType>,opt:Bool,name:String}> ):Expr {
		var argIdents = [ for(a in args) macro $i{a.name} ];
		return macro _makeApiCall( $v{name}, $a{argIdents} );
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
	static function getResultWrapFlagsForReturnType( returnType:ComplexType, pos:tink.core.Error.Pos ):EnumFlags<ApiReturnType> {
		var returnFlags = new EnumFlags<ApiReturnType>();
		if ( unify(returnType,macro :StdTypes.Void,pos) ) {
			returnFlags.set( ARTVoid );
		}
		else if ( unify(returnType,macro :tink.core.Future.Surprise<StdTypes.Dynamic,StdTypes.Dynamic>,pos) ) {
			returnFlags.set( ARTFuture );
			returnFlags.set( ARTOutcome );
		}
		else if ( unify(returnType,macro :tink.core.Future<StdTypes.Dynamic>,pos) ) {
			returnFlags.set( ARTFuture );
		}
		else if ( unify(returnType,macro :tink.core.Outcome<StdTypes.Dynamic,StdTypes.Dynamic>,pos) ) {
			returnFlags.set( ARTOutcome );
		}
		return returnFlags;
	}

	static function unify( complexType1:ComplexType, complexType2:ComplexType, pos:tink.core.Error.Pos ):Bool {
		var t1 = complexType1.toType( pos ).sure();
		var t2 = complexType2.toType( pos ).sure();
		return t1.unify( t2 );
	}

	static function defineCallbackProxyForType( type:Type ):Null<TypePath> {
		switch (type) {
			case TInst(t, _):
				var cls = t.get();

				// TODO: consider checking for an existing, manually defined version of this class.
				// `cls.meta.has("asyncCallbackApi")` would tell us if one had been built already, but that will depend on build order, so we may end up building it twice anyway.

				var suffix = "Proxy";
				var fullName = t.toString()+suffix;
				var className = cls.name+suffix;
				var classPackage = cls.pack;

				// Use `Context.getType` to see if it already exists.
				var alreadyExists = false;
				try {
					var existing = Context.getType( fullName );
					alreadyExists = true;
				}
				catch ( e:Dynamic ) {
					if ( e=="Type not found '"+fullName+"'" ) alreadyExists = false;
					else neko.Lib.rethrow(e);
				}

				// If it does not exist, create it now.
				if (!alreadyExists) {
					var complex = Context.toComplexType(type);
					var proxyDefinition = macro class $className extends ufront.remoting.UFCallbackApi<$complex> {};
					proxyDefinition.pack = classPackage;
					Context.defineType(proxyDefinition);
				}

				// Return the TypePath
				return { sub: null, params: [], pack: classPackage, name: className };
			default: // do nothing
				return null;
		}
	}
	#end
}
