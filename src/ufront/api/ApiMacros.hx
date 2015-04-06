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
			logBuild.bind(_,"Start"),
			addApiListMetaToContext,
			addInjectMetaToContextFields,
			logBuild.bind(_,"Finish"),
		]);
	}

	public static function buildClientApiContext():Array<Field> {
		return ClassBuilder.run([
			logBuild.bind(_,"Start"),
			createClientContextProxyFields,
			logBuild.bind(_,"Finish"),
		]);
	}

	public static function buildApiClass():Array<Field> {
		return ClassBuilder.run([
			logBuild.bind(_,"Start"),
			cacheAPIMembers,
			checkTypeHints,
			addReturnTypeMetadata,
			generalizeComplexTypesOnApiMethods,
			transformClient,
			logBuild.bind(_,"Finish"),
		]);
	}

	public static function buildAsyncApiProxy() {
		return ClassBuilder.run([
			logBuild.bind(_,"Start"),
			addAsyncProxyMemberMethods,
			addAsyncApiMetadata.bind( "asyncApi" ),
			addInjectApiMethod,
			logBuild.bind(_,"Finish"),
		]);
	}

	public static function buildCallbackApiProxy() {
		return ClassBuilder.run([
			logBuild.bind(_,"Start"),
			addCallbackProxyMemberMethods,
			addAsyncApiMetadata.bind( "callbackApi" ),
			addInjectApiMethod,
			logBuild.bind(_,"Finish"),
		]);
	}

	public static function buildSpecificApiProxy():Array<Field> {
		var localClass = Context.getLocalClass().get();
		for (iface in localClass.interfaces) {
			if ( iface.t.toString()=="ufront.remoting.RequireAsyncCallbackApi" ) {
				for ( api in iface.params ) {
					defineCallbackProxyForType( api, localClass.pos );
				}
			}
		}
		return null;
	}

	#if macro

	//
	// CLASSBUILDER FUNCTIONS
	//

	static function logBuild( cb:ClassBuilder, type:String ) {
		#if macro_debug
			trace( '$type ${cb.target.name}' );
		#end
	}

	static function cacheAPIMembers( cb:ClassBuilder ) {
		var fullName = cb.target.pack.concat([cb.target.name]).join(".");
		var members = [for (member in cb) member];
		cachedApiMembers.set( fullName, members );
	}

	static function addApiListMetaToContext( cb:ClassBuilder ) {
		var apis = [];
		for ( member in cb ) {
			var typeName = fullNameFromComplexType( member.getVar().sure().type );
			if ( typeName!=null )
				apis.push( macro $v{typeName} );
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
		constructor.isPublic = true;

		for ( field in serverContext.fields.get() ) {
			// Create the proxy if it doesn't exist yet.
			var apiType = field.type;
			var typePathForProxy = defineCallbackProxyForType( apiType, field.pos );
			var proxyComplexType = TPath( typePathForProxy );

			// Add the field.
			var fieldName = field.name;
			var tmp = macro class Tmp {
				public var $fieldName:$proxyComplexType;
			}
			cb.addMember( tmp.fields[0] );

			// Add the initialisation statement.
			if ( Context.defined("client") )
				constructor.addStatement( macro this.$fieldName = new $typePathForProxy( this.cnx ) );
			else
				constructor.addStatement( macro this.$fieldName = new $typePathForProxy() );
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
						member.extractMeta("returnType");
						member.addMeta( "returnType", metaParams );
					default:
				}
			}
		}
	}

	/**
		Because we cache our members and re-use them in build macros for our API proxies, we need the ComplexTypes to be generalized to work in a different "context".
		See documentation of `addProxyMemberMethods` for more details.
	**/
	static function generalizeComplexTypesOnApiMethods( cb:ClassBuilder ) {
		for ( member in cb ) {
			if ( member.isPublic && !member.isStatic ) {
				switch member.getFunction() {
					case Success(fn):
						fn.ret = generalizeComplexType( fn.ret, member.pos );
						for ( arg in fn.args ) {
							arg.type = generalizeComplexType( arg.type, member.pos );
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
		var syncApiType = getTypeFromFirstTypeParam( cb );
		if ( syncApiType!=null ) {
			var syncApiName = fullNameFromComplexType( syncApiType.toComplex() );
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
		var syncApiType = getTypeFromFirstTypeParam( cb );
		if ( syncApiType!=null ) {
			var asyncName = Context.getLocalClass().toString();
			var syncApiClassType = getClassTypeFromFirstTypeParam( cb );
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

		The flow of logic here is slightly unexpected. I have documented the reasons below, so anybody attempting a refactor can understand the reasoning.

		- Getting Access to the API Fields:
			- When we generate our API proxies, we need access to the fields of the original API, so we can mirror them.
			- We can get the `ClassType` of the original API via the type parameter, but if the original API's build macro is still running, the API's fields won't be available.
			- What we can do is cache the fields during the start of the API's build macro (save them to a static variable), and then read them during the proxy API.
			- But if the Proxy builds before the API, the fields won't be ready. *It seems* we can trigger the build be getting the `Ref<ClassType>` of the original API and calling `get()`. (I am not sure if this behaviour is defined, or just happens to work for now.)
			- So we can consistently get a list of `Field`s (from the build macro) rather than `ClassField`s (from the ClassType).
		- Knowing the type of the new API fields:
			- Now that we are using `Field` or `Member` rather than `ClassField`, we are dealing with `ComplexType`s not `Type`s.
			- These are literally just the description of the type based on the syntax, rather than the fully typed information from the compiler.
			- We can use `complexType.toType().sure()` to turn it into a complete type, but, this will often fail when you are in a different context.
			- For example, the ComplexType of the return value on an API method can be analysed with `toType()` in the APIs build macro, but `toType()` will fail in the Proxy's build macro.
			- You will get errors like "Class not found : Outcome", when Outcome is most definitely imported.
			- One possible workaround is, during the API build macro, completing a round-trip: `complexType.toType( pos ).sure().toComplex()`
			- This will return a ComplexType the same as the original, but with absolute paths that will work independently of context.
		- Our final solution:
			- If our Proxy builds before the UFApi, we try to trigger the build on the UFApi.
			- When we build our `UFApi`, we convert all ComplexTypes to use absolut paths in the `generalizeComplexTypesOnApiMethods()` method.
			- When we build our `UFApi`, we also cache the `Array<Member>` for the API in `cachedApiMembers`.
			- We can use these members to then create the appropriate fields for the proxy.
			- Our call to `getResultWrapFlagsForReturnType` still requires `unify()` and therefore converting ComplexType to Type, but because of the transformations in our build macro above, it all works.

		@param cb The current ClassBuilder.
		@param getExtraArgs A function that takes the return type and the flags and generates extra arguments for the field.
		@param getFnBody A function that takes the field name, arguments and return type flags and generates a function body expression.
		@param getReturnType A function that takes the return type and the flags and generates a new return type to use for the field.
	**/
	static function addProxyMemberMethods( cb:ClassBuilder, getExtraArgs:ComplexType->EnumFlags<ApiReturnType>->Array<FunctionArg>, getFnBody:String->Iterable<FunctionArg>->EnumFlags<ApiReturnType>->Expr, getReturnType:ComplexType->EnumFlags<ApiReturnType>->ComplexType  ) {
		var apiClassTypeRef = getClassTypeFromFirstTypeParam( cb );
		var pos = cb.target.pos;
		if ( apiClassTypeRef!=null ) {
			var apiClassName = apiClassTypeRef.toString();
			var apiClassType = apiClassTypeRef.get();

			// It seems calling `get()` on the ClassType Ref is forcing the compiler to build the type parameter.
			// I'm not sure if this is defined or just "happens to work". If it changes in future we will need to rethink this.
			var apiMembers = cachedApiMembers[apiClassName];
			if ( apiMembers!=null ) {
				for ( apiMember in apiMembers ) {
					if ( apiMember.isPublic && !apiMember.isStatic ) {
						switch apiMember.getFunction() {
							case Success(f):
								// TODO: We should investigate if we can read metadata here instead of unifying types again.
								var flags = getResultWrapFlagsForReturnType( f.ret, pos );
								var returnType = getReturnType( f.ret, flags );
								var fnBody = getFnBody( apiMember.name, f.args, flags );
								var member:Member = {
									pos: apiMember.pos,
									name: apiMember.name,
									meta: [],
									kind: FFun({
										ret: returnType,
										// TODO: write some unit tests to check type parameters in API functions are correctly supported.
										params: f.params,
										expr: fnBody,
										args: f.args.concat( getExtraArgs(f.ret,flags) ),
									}),
									doc: 'Async call for `${apiClassName}.${apiMember.name}()`',
									access: [ APublic ],
								};
								cb.addMember( member );
							case _:
						}
					}
				}
			}
			else throw 'Build order issue: ${apiClassName} may not have been compiled before ${cb.target.name}';
		}
	}

	//
	// HELPER METHODS
	//

	/**
		If a UFApi is half way through building, and UFAsyncApi starts to build, then UFAsyncApi will not be able to read the fields in UFApi, and so won't be able to mirror them.
		Caching the fields gives our UFAsyncApi an ability to see the UFApi's fields while the build is still in progress.
	**/
	static var cachedApiFields:Map<String,Array<ClassField>> = new Map();
	static var cachedApiMembers:Map<String,Array<Member>> = new Map();

	/**
		If our type is a sub-type of a module, then type.toString() may not generate an accurate path that can be used as an expression.
		When the complex type is not a TPath, otherwise it will throw an error.
	**/
	static function fullNameFromComplexType( ct:ComplexType ):Null<String> {
		return switch ct {
			case TPath(p):
				if ( p.sub!=null ) p.pack.concat([p.name,p.sub]).join(".");
				else p.pack.concat([p.name]).join(".");
			case _:
				throw "Expected TPath";
		}
	}

	static function generalizeComplexType( ct:ComplexType, pos:Position ):ComplexType {
		return ct.toType( pos ).sure().toComplex();
	}

	static function getTypeFromFirstTypeParam( cb:ClassBuilder ):Null<Type> {
		var params = cb.target.superClass.params;
		if ( params.length!=1 ) {
			cb.target.pos.errorExpr( 'Expected exactly one type parameter' );
			return null;
		}
		return params[0];
	}

	static function getClassTypeFromFirstTypeParam( cb:ClassBuilder ):Null<haxe.macro.Ref<ClassType>> {
		switch getTypeFromFirstTypeParam(cb) {
			case TInst(apiClassTypeRef,params):
				return apiClassTypeRef;
			case _:
				cb.target.pos.errorExpr( 'Expected type parameter to be a class' );
				return null;
		}
	}

	/**
		Change `doSomething():String` to `doSomething:Suprise<String,RemotingError<Noise>` etc.
		Only works with a TPath ComplexType.
		Please note this makes assumptions about the type parameters.
		If your API returns a `Surprise` or `Outcome`, it expects the 1st type parameter to represent a `Success` and the second to represent a `Failure` type.
		If your API returns a `Future` it expects the first type parameter to be a `Success` type.
		If your API returns values that unify with `Outcome`, `Future` or `Surprise`, but do not meet the above expectations, you may encounter strange results.
		I'm not sure if there is a workaround for this.
	**/
	static function asyncifyReturnType( rt:ComplexType, flags:EnumFlags<ApiReturnType> ):ComplexType {
		var typeParams = getParamsFromComplexType( rt );
		if ( flags.has(ARTVoid) ) {
			return macro :tink.core.Future.Surprise<Noise,ufront.remoting.RemotingError<tink.core.Noise>>;
		}
		else if ( flags.has(ARTFuture) && flags.has(ARTOutcome) ) {
			var successType = typeParams[0];
			var failureType = typeParams[1];
			return macro :tink.core.Future.Surprise<$successType,ufront.remoting.RemotingError<$failureType>>;
		}
		else if ( flags.has(ARTFuture) ) {
			var type = typeParams[0];
			return macro :tink.core.Future.Surprise<$type,ufront.remoting.RemotingError<tink.core.Noise>>;
		}
		else if ( flags.has(ARTOutcome) ) {
			var successType = typeParams[0];
			var failureType = typeParams[1];
			return macro :tink.core.Future.Surprise<$successType,ufront.remoting.RemotingError<$failureType>>;
		}
		else {
			var type = rt;
			return macro :tink.core.Future.Surprise<$type,ufront.remoting.RemotingError<tink.core.Noise>>;
		}
	}

	static function getCallbackArgsForField( rt:ComplexType, flags:EnumFlags<ApiReturnType> ):Array<FunctionArg> {
		var typeParams = getParamsFromComplexType( rt );
		var onResultType:ComplexType,
			onErrorType:ComplexType;
		if ( flags.has(ARTVoid) ) {
			onResultType = macro :tink.core.Callback<tink.core.Noise>;
			onErrorType = macro :tink.core.Callback<ufront.remoting.RemotingError<tink.core.Noise>>;
		}
		else if ( flags.has(ARTFuture) && flags.has(ARTOutcome) ) {
			var successType = typeParams[0];
			var failureType = typeParams[1];
			onResultType = macro :tink.core.Callback<$successType>;
			onErrorType = macro :tink.core.Callback<ufront.remoting.RemotingError<$failureType>>;
		}
		else if ( flags.has(ARTFuture) ) {
			var type = typeParams[0];
			onResultType = macro :tink.core.Callback<$type>;
			onErrorType = macro :tink.core.Callback<ufront.remoting.RemotingError<tink.core.Noise>>;
		}
		else if ( flags.has(ARTOutcome) ) {
			var successType = typeParams[0];
			var failureType = typeParams[1];
			onResultType = macro :tink.core.Callback<$successType>;
			onErrorType = macro :tink.core.Callback<ufront.remoting.RemotingError<$failureType>>;
		}
		else {
			var type = rt;
			onResultType = macro :tink.core.Callback<$type>;
			onErrorType = macro :tink.core.Callback<ufront.remoting.RemotingError<tink.core.Noise>>;
		}
		return [
			{ name:"onResult", opt:false, type:onResultType, value:null },
			{ name:"onError", opt:true, type:onErrorType, value:null },
		];
	}

	static function getParamsFromComplexType( ct:ComplexType ):Array<ComplexType> {
		var typeParams = [];
		switch ct {
			case TPath(t):
				for ( p in t.params ) switch p {
					case TPType(paramCT): typeParams.push( paramCT );
					case _:
				}
			case _:
		}
		return typeParams;
	}

	static function buildAsyncFnBody( name:String, args:Iterable<FunctionArg>, flags:EnumFlags<ApiReturnType> ):Expr {
		var argIdents = [ for(a in args) macro $i{a.name} ];
		return macro return _makeApiCall( $v{name}, $a{argIdents}, haxe.EnumFlags.ofInt($v{flags}) );
	}

	static function buildAsyncCallbackFnBody( name:String, args:Iterable<FunctionArg>, flags:EnumFlags<ApiReturnType> ):Expr {
		var argIdents = [ for(a in args) macro $i{a.name} ];
		return macro _makeApiCall( $v{name}, $a{argIdents}, haxe.EnumFlags.ofInt($v{flags}), onResult, onError );
	}

	static function buildSyncFnBody( name:String, args:Iterable<{name:String}> ):Expr {
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

	static function defineCallbackProxyForType( type:Type, pos:Position ):Null<TypePath> {
		switch (type) {
			case TInst(t, _):
				var cls = t.get();

				// TODO: consider checking for an existing, manually defined version of this class.
				// `cls.meta.has("callbackApi")` would tell us if one had been built already, but that will depend on build order, so we may end up building it twice anyway.

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
					var proxyDefinition = macro class Tmp extends ufront.api.UFCallbackApi<$complex> {};
					proxyDefinition.pack = classPackage;
					proxyDefinition.name = className;
					proxyDefinition.pos = pos;
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
