package ufront.view;

import haxe.Constraints;

/**
A wrapper to use with helper functions.

Because some templating engines (*cough* `haxe.Template` *cough*) use helpers in an abnormal way, we need to wrap them to be consistent across templating engines.

The main difference is that `haxe.Template` uses a separate macros object, and it expects each helper (or macro) to have a `resolve(name:String):Dynamic` function passed as the first argument.
While this could be useful, it is not common among other templating languages, so we don't support it in the generic Ufront `ViewResult` and `UFTemplate` classes.

The main purpose of this `TemplateHelper` abstract then is to know how many arguments a helper expects, so that when we use the `haxe.Template` engine, we can wrap our helpers so they know to ignore the first argument (the `resolve()` function).

Please note: TemplateHelper supports a maximum of 7 expected arguments. Attempting to use a function with more arguments will throw an error.
**/
@:forward( numArgs )
abstract TemplateHelper({ numArgs:Int, fn:Function }) {
	function new( numArgs:Int, fn:Function ) {
		// Why 7? With Haxe 3.2.0 I was getting errors with having more than 7 type parameters in my @:from casts.
		if ( numArgs>7 )
			throw 'TemplateHelpers can have a maximum of 7 arguments';
		this = { numArgs:numArgs, fn:fn };
	}

	@:from static function from0( fn:Void->Dynamic ) return new TemplateHelper( 0, fn );
	@:from static function from1<T1>( fn:T1->Dynamic ) return new TemplateHelper( 1, fn );
	@:from static function from2<T1,T2>( fn:T1->T2->Dynamic ) return new TemplateHelper( 2, fn );
	@:from static function from3<T1,T2,T3>( fn:T1->T2->T3->Dynamic ) return new TemplateHelper( 3, fn );
	@:from static function from4<T1,T2,T3,T4>( fn:T1->T2->T3->T4->Dynamic ) return new TemplateHelper( 4, fn );
	@:from static function from5<T1,T2,T3,T4,T5>( fn:T1->T2->T3->T4->T5->Dynamic ) return new TemplateHelper( 5, fn );
	@:from static function from6<T1,T2,T3,T4,T5,T6>( fn:T1->T2->T3->T4->T5->T6->Dynamic ) return new TemplateHelper( 6, fn );
	@:from static function from7<T1,T2,T3,T4,T5,T6,T7>( fn:T1->T2->T3->T4->T5->T6->T7->Dynamic ) return new TemplateHelper( 7, fn );

	public function getFn():Function {
		return switch this.numArgs {
			case 0: call0;
			case 1: call1;
			case 2: call2;
			case 3: call3;
			case 4: call4;
			case 5: call5;
			case 6: call6;
			case 7: call7;
			case _: throw 'TemplateHelpers can have a maximum of 7 arguments';
		}
	}

	function call0() return Reflect.callMethod( {}, this.fn, [] );
	function call1(arg1) return Reflect.callMethod( {}, this.fn, [arg1] );
	function call2(arg1,arg2) return Reflect.callMethod( {}, this.fn, [arg1,arg2] );
	function call3(arg1,arg2,arg3) return Reflect.callMethod( {}, this.fn, [arg1,arg2,arg3] );
	function call4(arg1,arg2,arg3,arg4) return Reflect.callMethod( {}, this.fn, [arg1,arg2,arg3,arg4] );
	function call5(arg1,arg2,arg3,arg4,arg5) return Reflect.callMethod( {}, this.fn, [arg1,arg2,arg3,arg4,arg5] );
	function call6(arg1,arg2,arg3,arg4,arg5,arg6) return Reflect.callMethod( {}, this.fn, [arg1,arg2,arg3,arg4,arg5,arg6] );
	function call7(arg1,arg2,arg3,arg4,arg5,arg6,arg7) return Reflect.callMethod( {}, this.fn, [arg1,arg2,arg3,arg4,arg5,arg6,arg7] );
}
