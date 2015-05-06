package ufront.web;

import haxe.EnumFlags;
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;
import tink.core.Error.Pos;
import tink.macro.ClassBuilder;
import tink.macro.Member;
import ufront.web.Controller;
import ufront.web.result.ActionResult;
using tink.CoreApi;
using tink.MacroApi;
using haxe.macro.Tools;
using StringTools;

class ControllerMacros {
	public static function processRoutesAndGenerateExecuteFunction():Array<Field> {
		// Add the onGenerate function to add `@wrapResult` metadata for each action
		Context.onGenerate( addResultWrappingMetadata.bind(Context.getLocalType().getID()) );

		return ClassBuilder.run([
			processRoutes
		]);
	}

	/**
		The ClassBuilder plugin for routing on ufront controllers.

		Go over every field in a controller looking for @:route metadata, so we can create an appropriate `execute()` function for this class.
	**/
	static function processRoutes( classBuilder:ClassBuilder ):Void {

		var routeInfos:Array<RouteInfo> = [];

		// For each instance field with @:route metadata
		for ( member in classBuilder ) if ( !member.isStatic ) {
			switch getRouteAndMethodFromMember(member) {
				case Success( routeAndMethod ):
					switch member.kind {
						case FFun(fn):
							var routeInfo = getRouteInfoFromFn( member, fn, routeAndMethod );
							if (routeInfo!=null) routeInfos.push(routeInfo);
						case FVar(t,null), FProp("default","null",t,null):
							switch createFunctionForVariable( member, t ) {
								case Success( fnMember ):
									var fn = fnMember.getFunction().sure();
									classBuilder.addMember( fnMember );
									var routeInfo = getRouteInfoFromFn( fnMember, fn, routeAndMethod );
									if (routeInfo!=null) routeInfos.push( routeInfo );
								case Failure( _ ):
							}
						case FVar(t,_), FProp("default","null",t,_):
							Context.warning( 'Routing field ${member.name} cannot have an initialization value.', member.pos );
						case FProp(_,_,t,_):
							Context.warning( 'Routing field ${member.name} must use access (default,null), not setters or getters.', member.pos );
					}


				default:
			}
		}

		if ( routeInfos.length==0 ) {
			Context.warning( 'No valid @:route metadata was found in this controller', classBuilder.target.pos );
		}

		classBuilder.addMember( buildExecuteField(routeInfos) );
	}

	/**
		Given a field, extract the route and httpMethod information.

		Returns a pair, containing a) the route parts (split by "/"), and b) the http method, if one was specified.
		Returns a failure and prints a warning to the console if metadata is found but is invalid.
		Returns a failure if metadata isn't found.
	**/
	static function getRouteAndMethodFromMember( field:Field ):Outcome<Pair<Array<String>,Null<String>>,Error> {
		var routeMeta = field.meta.filter( function(m) return m.name==":route" );
		if ( routeMeta.length>0 ) {
			var metaExprs = [ for (metaEntry in routeMeta) for (expr in metaEntry.params) expr ];
			var routeParts = null,
				method = null;
			for ( expr in metaExprs ) switch expr.expr {
				case EConst(CString(routeStr)):
					if (routeParts==null) {
						routeParts=routeStr.split( "/" );
						if ( routeParts.length>0 && routeParts[0]=="" ) routeParts.shift();
						if ( routeParts.length>0 && routeParts[routeParts.length-1]=="" ) routeParts.pop();
						validateRouteParts( routeParts, expr.pos );
					}
					else Context.warning( 'More than one @:route value for ${field.name} was specified', field.pos );

				case EConst(CIdent(methodName)):
					if (methodName!="POST" && methodName!="GET" && methodName!="PUT" && methodName!="DELETE")
						Context.warning( 'Invalid httpMethod for $methodName for @:route on ${field.name}.  Valid values are POST, GET, PUT and DELETE', field.pos );
					else if ( method!=null )
						Context.warning( 'More than one @:route httpMethod value for ${field.name}: ${methodName} and ${method}', field.pos );
					else
						method = methodName;

				case _:
					Context.warning( 'Unknown metadata value in @:route on ${field.name}: ' + expr.toString(), field.pos );
			}
			if ( routeParts==null ) {
				var msg = '@:route metadata on ${field.name} did not contain a route string.';
				Context.warning( msg, field.pos );
				return Failure( new Error(msg,field.pos) );
			}
			else return Success( new Pair(routeParts,method) );
		}
		else return Failure( new Error("No :route metadata on this field") );
	}

	static var validRoutePart = ~/^\$([a-z0-9_][a-zA-Z0-9_]*)$/;

	/**
		Check if an array of parts are valid according to our rules, and print warnings if not.
	**/
	static function validateRouteParts( parts:Array<String>, pos:Pos ) {
		var i = 0;
		var routeStr = parts.join("/");
		for ( p in parts ) {
			i++;
			if ( p.indexOf("$")>-1 && validRoutePart.match(p)==false ) {
				Context.warning( 'Invalid route part `$p` in @:route("$routeStr"), route capture segments must begin with a $$ and then contain only a valid variable name.', pos );
			}
			var hasAsterisk = p.indexOf("*")>-1;
			var asteriskIsAtEnd = p.indexOf("*")==p.length-1;
			var finalPart = i==parts.length;
			if ( hasAsterisk && (!asteriskIsAtEnd || !finalPart) ) {
				Context.warning( 'Invalid route part `$p` in @:route("$routeStr"), an asterisk can only be used in the final route part, on its own, as a "catch-all".', pos );
			}
			if ( p.length==0 ) {
				Context.warning( 'Invalid route part in @:route("$routeStr"), you cannot have an empty route part.', pos );
			}
		}
	}

	/**
		Take a variable with @:route data, check it is a `ufront.web.Controller`, and create a function:

		```
		function execute_varName() return (new ControllerType(context)).execute();
		```

		Please note this does not add the member to the class, you must explicitly take the return result and add it to the class.
	**/
	static function createFunctionForVariable( varMember:Member, varType:ComplexType ):Outcome<Member,Error> {
		if ( complexTypesUnify(varType, macro :ufront.web.Controller) ) {
			var fnName = "execute_"+varMember.name;
			switch varType {
				case TPath(p):
					var parts = p.pack.copy();
					parts.push( p.name );
					if ( p.sub!=null )
						parts.push( p.sub );
					var name = parts.join('.');
					var fnBody:Expr = macro return this.context.injector.instantiate( $i{name} ).execute();
					var fnReturnType:ComplexType = macro :tink.CoreApi.Surprise<ufront.web.result.ActionResult,tink.core.Error>;
					var fn:Function = {
						ret: fnReturnType,
						args: [],
						expr: fnBody,
					}

					var fnMember:Member = Member.method( fnName, varMember.pos, false, fn );

					// Remove @:route metadata from variable and attach to function
					var metaEntry = varMember.extractMeta( ':route' ).sure();
					fnMember.addMeta( metaEntry.name, metaEntry.pos, metaEntry.params );
					return Success( fnMember );
				case _:
					var msg = 'Unsupported complex type on ${varMember.name}, only TPath is supported.';
					Context.warning( msg, varMember.pos );
					return Failure( new Error(msg,varMember.pos) );
			}
		}
		else {
			var msg = '@:route metadata was used on ${varMember.name}, which was not a controller.';
			Context.warning( msg, varMember.pos );
			Context.warning( '  ${varType.toString()} did not unify with ufront.web.Controller', varMember.pos );
			return Failure( new Error(msg,varMember.pos) );
		}
	}

	/**
		Given a function with @:route metadata, build and return a RouteInfo object.

		Returns null if there was an error.
	**/
	static function getRouteInfoFromFn( member:Member, fn:Function, routeAndMethod:Pair<Array<String>,Null<String>> ):Null<RouteInfo> {
		var routeParts = routeAndMethod.a;
		var finalPart = routeParts[routeParts.length-1];
		var catchAll = finalPart!=null && finalPart.endsWith("*");
		var method = routeAndMethod.b;
		var argumentInfo = getArgumentInfo( fn.args, routeParts, member.pos );
		var args = argumentInfo.a;
		var requiredLength = argumentInfo.b;
		if ( catchAll ) routeParts.pop();
		var voidReturn = checkIfReturnVoid( fn );

		return {
			action: member,
			routeParts: routeParts,
			requiredLength: requiredLength,
			catchAll: catchAll,
			method: method,
			args: args,
			voidReturn: voidReturn
		}
	}

	/**
		Checks if a function returns void.

		Initially checks the return value (`fn.ret`).
		If it is not null, we test if the return type unifies with `StdTypes.Void`.

		If `fn.ret` is null, we search the AST for an `EReturn`, and:

		- If the EReturn has a value, it returns a value, so return false
		- If the EReturn has no value, it is an empty return, so return true
		- If no EReturn is found, return true.
	**/
	static function checkIfReturnVoid( fn:Function ):Bool {
		if ( fn.ret!=null ) {
			return complexTypesUnify( fn.ret, macro :StdTypes.Void );
		}
		else {
			var returnFound = false;
			fn.expr.transform( function(expr:Expr) {
				switch expr.expr {
					case EReturn( expr ):
						if ( expr!=null ) returnFound = true;
					case _:
				}
				return expr;
			});
			return !returnFound; // If no return value found, it returns void.
		}
	}

	/**
		Check if 2 complex types unify.
	**/
	static function complexTypesUnify( ct1:ComplexType, ct2:ComplexType ) {
		return Context.unify( ct1.toType(), ct2.toType() );
	}

	/**
		Given arguments on a routing function, extract info about the type of argument so we can use it in routing.

		Return a pair containing an Array<ArgumentKind>, and the number of required route parts
	**/
	static function getArgumentInfo( fnArgs:Array<FunctionArg>, routeParts:Array<String>, pos:Pos ):Pair<Array<ArgumentKind>,Int> {
		var requiredLength = routeParts.length;

		// If the final part is a wildcard, then it means that part isn't required.
		// We check here rather than where there is an argument, because sometimes you can have a wildcard but no "rest:Array<String>" arg,
		// and in that case we still want to lower the required parts..
		if ( routeParts[routeParts.length-1]=="*" )
			requiredLength--;

		var argumentInfo = [];
		for ( arg in fnArgs ) {
			if ( arg.type!=null ) {
				var argKind = null;

				if ( arg.name=="args" ) {

					argKind = parseArgsArgument( arg, pos );

				}
				else if ( arg.name=="rest" && complexTypesUnify(arg.type,macro :Array<String>) ) {

					if ( routeParts.length>0 && routeParts[routeParts.length-1]=="*" ) {
						argKind = AKRest;
					}
					else Context.error( 'The final part of your route "${routeParts.join("/")}" was not a "*" wildcard, so you cannot use a `rest:Array<String>` argument.', pos );

				}
				else {

					var routePartIndex = routeParts.indexOf( "$"+arg.name );
					if ( routePartIndex==-1 )
						Context.error( 'The argument `${arg.name}` was not supplied in route "${routeParts.join("/")}".', pos );

					var isOptional = arg.opt || arg.value!=null;
					if ( isOptional ) {
						// After an optional route part, all remaining route parts should be optional
						for ( i in routePartIndex...routeParts.length ) {
							var part = routeParts[i];
							var arg = getFunctionArgFromRoutePart( fnArgs, part );
							if ( arg==null || (arg.opt==false && arg.value==null) )
								Context.error( 'The argument `${arg.name}` was optional, but the route part "$part" which came after it was not optional.', pos );
						}

						if ( requiredLength>routePartIndex )
							requiredLength = routePartIndex;
					}

					switch getRouteArgType( arg.type ) {
						case Success(routeArgType):
							var defaultVal =
								if ( isOptional && arg.value!=null ) arg.value
								else if ( isOptional ) macro null
								else null
							;
							argKind = AKPart( arg.name, routePartIndex, routeArgType, isOptional, defaultVal );
						case Failure(_):
					}
				}

				if ( argKind==null ) {

					Context.warning( 'Only String, Int, Float, Bool, rest:Array<String> and args:{} are supported.', pos );
					Context.error( 'Unsuported argument type ${arg.name}:${arg.type.toString()}.', pos );

				}
				else argumentInfo.push( argKind );
			}
			else Context.warning( 'Please provide explicit type information for argument ${arg.name}', pos );
		}
		return new Pair( argumentInfo, requiredLength );
	}

	/**
		Given a route part, eg `$id`, and a list of function args, find the correct arg, eg `id:Int`
	**/
	static function getFunctionArgFromRoutePart( fnArgs:Array<FunctionArg>, routePart:String ):FunctionArg {
		if ( routePart.charAt(0)!="$" )
			return null;

		var argName = routePart.substr(1);
		var arg = [ for (a in fnArgs) if (a.name==argName) a ][0];
		return arg;
	}

	/**
		Check if a complex type unifies with one of our approved routing types.

		Return the appropriate RouteArgType to make it easier to handle later.
	**/
	static function getRouteArgType( argType:ComplexType ) {
		return
			if ( complexTypesUnify(argType, macro :String) || complexTypesUnify(argType, macro :Array<String>) ) Success(SATString);
			else if ( complexTypesUnify(argType, macro :Int) || complexTypesUnify(argType, macro :Array<Int>) ) Success(SATInt);
			else if ( complexTypesUnify(argType, macro :Float) || complexTypesUnify(argType, macro :Array<Float>) ) Success(SATFloat);
			else if ( complexTypesUnify(argType, macro :Bool) || complexTypesUnify(argType, macro :Array<Bool>) ) Success(SATBool);
			else if ( complexTypesUnify(argType, macro :Date) || complexTypesUnify(argType, macro :Array<Date>) ) Success(SATDate);
			else Failure( Noise );
	}

	/**
		Check if a complex type is either optional (has a ?), or is `Null<T>`
	**/
	static function isComplexTypeOptional( argType:ComplexType ) {
		switch argType {
			case TOptional(_):
				return true;
			case TPath(tpath):
				return ( tpath.name==null && tpath.pack.length==0 );
			case _:
				return false;
		}
	}

	/**
		Process an `args:{}` argument on a routing function.

		Return AKParams if it is all good.
		Throw a context error if it failed to parse the object.
		Return null if it wasn't an anonymous object, an error will be thrown later if it isn't a compatible type.
	**/
	static function parseArgsArgument( arg:FunctionArg, pos:Pos ) {
		switch arg.type {
			case TAnonymous( fields ):
				var allOptional = arg.opt;
				var params = [];
				try {
					for ( f in fields ) {
						var member:Member = f;
						var paramVar = member.getVar().sure();
						var argType = getRouteArgType( paramVar.type ).sure();
						var hasOptionalMeta = member.extractMeta(":optional").isSuccess();
						var isNullable = isComplexTypeOptional( paramVar.type );
						var optional = hasOptionalMeta || isNullable;
						params.push({
							name: f.name,
							type: argType,
							optional: optional,
							array: complexTypesUnify( paramVar.type, macro:Array<Dynamic> ),
						});
					}
					return AKParams( params, allOptional );
				}
				catch ( e:Dynamic ) {
					var msg = 'Failed to parse function argument `args`.  The args object must contain only the types String, Int, Float and Bool. \n$e';
					Context.error( msg, pos );
				}
			case _:
		}
		return null;
	}

	/**
		Build a `override public function execute()` method for this controller using the information from our routes.
	**/
	static function buildExecuteField( routeInfos:Array<RouteInfo> ):Member {

		var routes:Array<Pair<ExprOf<Bool>,Expr>> = [];
		for ( routeInfo in routeInfos ) {
			routes.push( buildIfBlockForRoute(routeInfo) );
		}

		var ifElseRoutingBlock:Expr = createIfElseBlock( routes );

		// Build the function
		var fnBody:Expr = macro {
			var uriParts = context.actionContext.uriParts;
			setBaseUri( uriParts );
			var params = context.request.params;
			var method = context.request.httpMethod;

			context.actionContext.controller = this;
			context.actionContext.action = "execute";

			try {
				// The bulk of the processing for each route
				$ifElseRoutingBlock;

				// As a fallback, return a 404 failure
				return throw ufront.web.HttpError.pageNotFound();
			}
			catch ( e:Dynamic ) {
				return ufront.core.Sync.httpError( 'Uncaught error while executing '+context.actionContext.controller+'.'+context.actionContext.action+'()', e );
			}

		}

		var fnReturnType:ComplexType = macro :tink.CoreApi.Surprise<ufront.web.result.ActionResult,tink.core.Error>;
		var fn:Function = {
			ret: fnReturnType,
			args: [],
			expr: fnBody,
		}

		// Build the member field, and return
		var member = Member.method( 'execute', fn );
		member.overrides = true;
		return member;
	}

	/**
		Build the condition and the response expression for the `if( route ) { return doAction() }` expression.
	**/
	static function buildIfBlockForRoute( routeInfo:RouteInfo ):Pair<ExprOf<Bool>,Expr> {
		var condition = generateConditionsForRoute( routeInfo );
		var block = generateBlockForRoute( routeInfo );
		return new Pair( condition, block );
	}

	/**
		Generate the boolean check to see if the current request matches the given route.
	**/
	static function generateConditionsForRoute( routeInfo:RouteInfo ):ExprOf<Bool> {
		var conditions = [];

		// Check the method matches
		if ( routeInfo.method!=null ) {
			var requiredMethod = routeInfo.method.toLowerCase();
			conditions.push( macro method.toLowerCase()==$v{requiredMethod} );
		}

		// Check the length is correct
		var minParts = routeInfo.requiredLength;
		var maxParts = routeInfo.routeParts.length;
		if ( routeInfo.catchAll ) {
			if ( minParts>0 )
				conditions.push( macro $v{minParts}<=uriParts.length );
		}
		else if ( minParts==maxParts ) {
			conditions.push( macro $v{minParts}==uriParts.length );
		}
		else {
			conditions.push( macro ($v{minParts}<=uriParts.length && $v{maxParts}>=uriParts.length) );
		}

		var pos = 0;
		for ( part in routeInfo.routeParts ) {
			if ( !part.startsWith("$") ) {
				// Check non-capture segments match (all parts not beginning with "$")
				conditions.push( macro uriParts[$v{pos}]==$v{part} );
			}
			else {
				// Check required capture segments exist and are not empty...
				if ( pos<minParts )
					conditions.push( macro uriParts[$v{pos}].length>0 );
			}
			pos++;
		}

		return createBooleanAndChain( conditions );
	}

	/**
		Generate the code to execute each route.
	**/
	static function generateBlockForRoute( routeInfo:RouteInfo ):Expr {
		var lines = [];
		var p = routeInfo.action.pos;


		// Prepare for the function call
		var fnIdent = routeInfo.action.name.resolve();
		var fnArgs = [];
		for ( arg in routeInfo.args ) {
			var argData = makeExprToReadArgFromRequest(arg);
			var ident = argData.ident;
			fnArgs.push( ident );
			for ( l in argData.lines )
				lines.push( l );
		}

		lines.push( macro context.actionContext.action = $v{routeInfo.action.name} );
		lines.push( macro context.actionContext.args = $a{fnArgs} );

		// Splice the uriParts so that parts relevant to this execute don't affect subdispatching...
		lines.push( macro context.actionContext.uriParts.splice(0,$v{routeInfo.routeParts.length}) );

		// Execute the call, wrap the results
		var functionCall = { expr: ECall(fnIdent,fnArgs), pos: p };
		var wrappedFunctionCall = wrapReturnExpression( functionCall, routeInfo.action.name, routeInfo.voidReturn, lines );
		lines.push( macro var result:tink.core.Future.Surprise<ufront.web.result.ActionResult,tink.core.Error> = $wrappedFunctionCall );

		var setContextActionResult = macro setContextActionResultWhenFinished( result );
		lines.push( setContextActionResult );

		// Return the actionResult
		lines.push( macro return result );

		return { expr: EBlock(lines), pos: routeInfo.action.pos };
	}

	/**
		Given an argument declaration,

		Returns an object, with

		a) containing the expression of the ident,
		b) the lines to insert, including the `$ident = $readExpr` line.
	**/
	static function makeExprToReadArgFromRequest( arg:ArgumentKind ):{ ident:Expr, lines:Array<Expr> } {
		switch arg {
			case AKPart( name, partNum, type, optional, defaultValue ):
				var ident = name.resolve();
				var expr =
					if ( optional ) macro (uriParts[$v{partNum}]!=null && uriParts[$v{partNum}]!="") ? uriParts[$v{partNum}] : $defaultValue
					else macro uriParts[$v{partNum}]
				;
				var lines = createReadExprForType( name, expr, type, optional );
				return { ident: ident, lines: lines };
			case AKParams( params, allParamsOptional ):
				var lines = [];
				var fields = [];
				// Build a temporary variable to catch each parameter
				for ( p in params ) {

					// If it is not optional, add check to make sure it is present
					var isOptional = p.optional || allParamsOptional;
					if ( false==isOptional ) {
						var checkExists = macro if ( !params.exists($v{p.name}) ) throw ufront.web.HttpError.badRequest( 'Missing parameter '+$v{p.name} );
						lines.push( checkExists );
					}

					var tmpIdentName = '_param_tmp_'+p.name;
					var tmpIdent = tmpIdentName.resolve();
					var getValueExpr = if(p.array) macro params.getAll($v{p.name}) else macro params.get($v{p.name});
					for ( l in createReadExprForType(tmpIdentName, getValueExpr, p.type, isOptional) ) {
						lines.push( l );
					}
					fields.push( { field: p.name, expr: tmpIdent } );
				}

				// Add a args = {} property
				var ident = "args".resolve();
				var expr = { expr: EObjectDecl(fields), pos: Context.currentPos() };
				lines.push( macro var args = $expr );
				return { ident: ident, lines: lines };
			case AKRest:
				var ident = "rest".resolve();
				var expr = macro var rest = context.actionContext.uriParts;
				return { ident: ident, lines: [ expr ] };
		}
	}

	/**
		For a given ident, readExpr and type, create a set of lines that:

		- reads the string, (using $readExpr)
		- converts the input to the appropriate type
		- validates the input
		- declares and sets the value of the ident
	**/
	static function createReadExprForType( identName:String, readExpr:ExprOf<String>, type:RouteArgType, optional:Bool ):Array<Expr> {
		// Reification of `macro var $i{identName} = $readExpr` isn't working, so I'm using this helper
		function createVarDecl( name:String, expr:Expr ) {
			return {
				expr: EVars([{
					name: name,
					expr: expr,
					type: null
				}]),
				pos: Context.currentPos()
			};
		}

		return switch type {
			case SATString:
				var declaration = createVarDecl( identName, readExpr );
				[declaration];
			case SATInt:
				var declaration = createVarDecl( identName, macro Std.parseInt($readExpr) );
				var check = macro if ( $i{identName}==null ) throw ufront.web.HttpError.badRequest( "Could not parse parameter "+$v{identName}+":Int = "+$readExpr );
				( optional ) ? [declaration] : [declaration,check];
			case SATFloat:
				var declaration = createVarDecl( identName, macro Std.parseFloat($readExpr) );
				var check = macro if (Math.isNaN($i{identName})) throw ufront.web.HttpError.badRequest( "Could not parse parameter "+$v{identName}+":Float = "+$readExpr );
				( optional ) ? [declaration] : [declaration,check];
			case SATBool:
				var readStr = macro var v = $readExpr;
				var transformToBool = createVarDecl( identName, macro (v!="false" && v!="0" && v!="null") );
				[readStr,transformToBool];
			case SATDate:
				var declaration = createVarDecl( identName, macro try Date.fromString($readExpr) catch(e:Dynamic) null );
				var check = macro if ( $i{identName}==null ) throw ufront.web.HttpError.badRequest( "Could not parse parameter "+$v{identName}+":Date = "+$readExpr );
				( optional ) ? [declaration] : [declaration,check];
		}
	}

	/**
		Take the return expression of a particular action, and wrap it appropriately.

		This involves using the `wrapResult` method of `ufront.web.Controller`.

		If your action returns `Void`, this will pass "null" to `wrapResult`, resulting in an appropriately wrapped `EmptyResult`.

		Otherwise, it uses `wrapResult` metadata added during an `onGenerate` macro to decide what wrapping is required, and passes that information to `wrapResult`.
		For details see `addRouteWrappingMetadata` (a build macro on ufront.web.Controller).

		This returns a correctly typed expression to use with `result:Surprise<ActionResult,Error> = $expr`
		This will also add extra expressions to a `lines` array, meaning they will be added before the `result=` line above.
	**/
	static function wrapReturnExpression( returnExpr:Expr, routeName:String, voidReturn:Bool, lines:Array<Expr> ):ExprOf<Surprise<ActionResult,Error>> {
		if ( voidReturn ) {
			lines.push( returnExpr );
			return macro wrapResult(null, haxe.EnumFlags.ofInt(0));
		}
		else {
			var classRef = Context.getLocalClass().toString().resolve();
			var readMetadata = macro haxe.rtti.Meta.getFields( $classRef ).$routeName.wrapResult[0];
			var getEnumFlags = macro haxe.EnumFlags.ofInt( $readMetadata );
			lines.push( macro var wrappingRequired = $getEnumFlags );
			return macro wrapResult( $returnExpr, wrappingRequired );
		}
	}

	/**
		An `onGenerate` function that adds `@wrappingRequired( enumFlags )` metadata for each controller action.

		See `getResultWrapFlagsForReturnType` for details on which flags are set.
	**/
	static function addResultWrappingMetadata( id:String, types:Array<Type> ):Void {
		var baseController = Context.getType( "ufront.web.Controller" );
		for ( type in types ) {
			if ( type.getID()==id ) {
				switch type {
					case TInst( ref, _ ):
						var classType = ref.get();
						for ( f in classType.fields.get() ) {
							if ( f.meta.has(":route") ) {
								switch f.type {
									case TFun( _, returnType ):
										var wrapResultInt = getResultWrapFlagsForReturnType( returnType ).toInt();
										f.meta.add( "wrapResult", [macro $v{wrapResultInt}], f.pos );
									case _:
										Context.error( '@:route metadata was used on ${f.name}, which is not a function.', f.pos );
								}
							}
						}
					case _:
				}
			}
		}
	}

	/**
		Return a set of flags showing what sort of wrapping is required for a given return type.

		Basic rules:

		- If it is already `Surprise<ActionResult,Error>`, use as is
		- If it is `Surprise<Dynamic,Dynamic>`, require wrapping in ActionResult/Error
		- If it is `Future<ActionResult>`, require wrapping in Outcome
		- If it is `Future<Dynamic>`, require wrapping in Outcome and ActionResult/Error
		- If it is `Outcome<ActionResult,Error>`, require wrapping in Future
		- If it is `Outcome<Dynamic,Dynamic>`, require wrapping in Future, ActionResult/Error
		- If it is `ActionResult`, require wrapping in Future, Outcome
		- If it is `Dynamic`, require wrapping in Future, Outcome and ActionResult/Error
		- If it is void, leave it, our other macros will pass "null" to the `wrapResult` method of the controller and an EmptyResult will be generated, appropriately wrapped.
	**/
	static function getResultWrapFlagsForReturnType( returnType:Type ):EnumFlags<WrapRequired> {
		var flags = new EnumFlags<WrapRequired>();
		if ( returnType.unify((macro :StdTypes.Void).toType()) ) {
			flags.set(WRFuture);
			flags.set(WROutcome);
			flags.set(WRResultOrError);
		}
		else if ( returnType.unify((macro :tink.core.Future.Surprise<ufront.web.result.ActionResult,tink.core.Error>).toType()) ) {
			// no wrapping required
		}
		else if ( returnType.unify((macro :tink.core.Future.Surprise<StdTypes.Dynamic,StdTypes.Dynamic>).toType()) ) {
			flags.set(WRResultOrError);
		}
		else if ( returnType.unify((macro :tink.core.Future<ufront.web.result.ActionResult>).toType()) ) {
			flags.set(WROutcome);
		}
		else if ( returnType.unify((macro :tink.core.Future<StdTypes.Dynamic>).toType()) ) {
			flags.set(WROutcome);
			flags.set(WRResultOrError);
		}
		else if ( returnType.unify((macro :tink.core.Outcome<ufront.web.result.ActionResult,tink.core.Error>).toType()) ) {
			flags.set(WRFuture);
		}
		else if ( returnType.unify((macro :tink.core.Outcome<StdTypes.Dynamic,StdTypes.Dynamic>).toType()) ) {
			flags.set(WRFuture);
			flags.set(WRResultOrError);
		}
		else if ( returnType.unify((macro :ufront.web.result.ActionResult).toType()) ) {
			flags.set(WRFuture);
			flags.set(WROutcome);
		}
		else {
			// assume return type is `Dynamic`
			flags.set(WRFuture);
			flags.set(WROutcome);
			flags.set(WRResultOrError);
		}
		return flags;
	}

	/**
		Take an array and turn it into an if/elseif block.

		Each array item should contain a pair with, a) a boolean expression b) an expression or block to execute if the boolean is true.

		Trivia: In writing this method, I realized something I never have before:

		`if (x==1) doThis() else if (x==2) doThat()`

		is actually just shorthand (missing some curly brackets) for:

		`if (x==1) { doThis(); } else { if (x==2) { doThat(); } }`

		"else if" is actually just "else" with the else block containing another if statement.
		Hence no representation of "elseif" in the EIf definition.
	**/
	static function createIfElseBlock( conditionsAndBlocks:Array<Pair<ExprOf<Bool>,Expr>> ) {
		var expr:Expr = null;
		while ( conditionsAndBlocks.length>0 ) {
			var finalRemaining = conditionsAndBlocks.pop();
			var condition = finalRemaining.a;
			var block = finalRemaining.b;
			if ( expr==null ) {
				expr = macro if ($condition) $block;
			}
			else {
				expr = macro if ($condition) $block else $expr;
			}
		}
		return
			if ( expr!=null ) expr
			else macro null;
	}

	/**
		Combine several boolean checks with the && (AND) operator.
	**/
	static function createBooleanAndChain( conditions:Array<ExprOf<Bool>> ):ExprOf<Bool> {
		if ( conditions.length>0 ) {
			var expr = null;
			for ( condition in conditions ) {
				if ( expr==null ) expr = condition;
				else expr = macro $expr && $condition;
			}
			return expr;
		}
		else return macro true;
	}
}

typedef RouteInfo = {
	action:Member,
	routeParts:Array<String>,
	requiredLength:Int,
	catchAll:Bool,
	method:Null<String>,
	args:Array<ArgumentKind>,
	voidReturn:Bool
}

enum ArgumentKind {
	AKPart( name:String, partNum:Int, type:RouteArgType, optional:Bool, defaultValue:Expr );
	AKParams( params:Array<{ name:String, type:RouteArgType, optional:Bool, array:Bool }>, ?allOptional:Bool );
	AKRest;
}

enum RouteArgType {
	SATString;
	SATInt;
	SATFloat;
	SATBool;
	SATDate;
}
