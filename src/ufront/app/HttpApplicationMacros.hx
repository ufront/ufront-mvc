package ufront.app;

#if macro
	using tink.MacroApi;
	import haxe.macro.Expr;
#end
import ufront.web.context.HttpContext;
import ufront.web.HttpError;
import haxe.PosInfos;
using tink.CoreApi;

class HttpApplicationMacros {
	/**
		Given a bunch of modules (handlers,middleware) and the name of the method on that
		module, return a

		`Array<Pair<(HttpContext->Surprise<Noise,Error>),PosInfos>>`

		so we can execute them all in the same way.
	**/
	@:allow( ufront.app.HttpApplication )
	static macro function prepareModules( modules:ExprOf<Array<Dynamic>>, methodName:String, ?bindArgs:ExprOf<Array<Dynamic>> ):ExprOf<Array<Pair<HttpContext->Surprise<Noise,Error>,PosInfos>>> {
		#if macro
			var argsToBind:Array<Expr>;
			var argsForPos:Array<String> = [];

			switch bindArgs.expr {
				case EArrayDecl( args ):
					argsToBind = args;
					for ( a in args ) {
						if ( !a.isWildcard() )
							argsForPos.push( a.toString() );
						else
							argsForPos.push( "{HttpContext}" );
					}
				default:
					argsToBind = [];
					argsForPos = [];
			}

			var fakePos:Expr = macro HttpError.fakePosition( m, $v{methodName}, $v{argsForPos} );
			var boundMethod:Expr = macro m.$methodName.bind( $a{argsToBind} );

			return macro $modules.map( function(m) return new Pair($boundMethod,$fakePos) );
		#end
	}
}
