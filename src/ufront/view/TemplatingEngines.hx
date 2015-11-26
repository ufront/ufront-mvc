package ufront.view;

#if mustache import mustache.Mustache; #end
import haxe.Constraints;
using tink.CoreApi;

/**
This class provides some shortcut definitions to common templating engines in the Haxe eco-system.

These shortcuts are added for your convenience.
They don't include the actual template libraries, rather, they return a typedef that let's our UFViewEngine know how to use the templating library so you can add it easily.

The static variables for each library are surrounded in conditionals, so they will only be included if you have that library included in your current build.

Templating engines currently provided:

- `haxe` - provided in the Standard Library, no extra haxelibs needed.
- `hxdtl` - Django Templating Library for Haxe.  Available if `hxdtl` haxelib is being used.
- `hxtemplo` - Simn's port of the `templo` templating language.  Available if `hxtemplo` haxelib is being used.
- `mustache` - Mustache "Logic-less" templates.  Available if `mustache` haxelib is being used.
- `erazor` - A powerful templating language that lets you switch between templates and haxe-code effortlessly.  Based on `mvc-razor`.  Available if `erazor` haxelib is being used.

If you would like to add support for another library, please send a pull request!
**/
class TemplatingEngines {

	/**
	An array of all known templating engines that have been included for compilation.

	The default order is `[erazor,hxtemplo,mustache,hxdtl,haxe]`.
	**/
	public static var all:Array<TemplatingEngine> = [
		#if erazor TemplatingEngines.erazorHtml, #end
		#if erazor TemplatingEngines.erazor, #end
		#if hxtemplo TemplatingEngines.hxtemplo, #end
		#if mustache TemplatingEngines.mustache, #end
		#if hxdtl TemplatingEngines.hxdtl, #end
		TemplatingEngines.haxe
	];

	/**
	A templating engine for `haxe.Template` templates, using "html" and "tpl" extensions.

	This is available through the standard library and is always included in compilation.
	**/
	public static var haxe(get,null):TemplatingEngine;
	static function get_haxe() return {
		factory: function ( tplString ):UFTemplate {
			var t = new haxe.Template( tplString );
			return function (data:TemplateData, ?helpers:Map<String,TemplateHelper>) {
				var macrosObject:Dynamic<Function> = {};
				if ( helpers!=null ) for ( helperName in helpers.keys() ) {
					var paddedHelper = padHelperFnForHaxeTplMacro( helpers[helperName] );
					Reflect.setField( macrosObject, helperName, paddedHelper );
				}
				return t.execute( data.toObject(), macrosObject );
			}
		},
		type: "haxe.Template",
		extensions: ["html", "tpl"]
	}

	static function padHelperFnForHaxeTplMacro( h:TemplateHelper ):Function {
		return switch h.numArgs {
			case 0: function(_) return h.getFn()();
			case 1: function(_,a) return h.getFn()(a);
			case 2: function(_,a,b) return h.getFn()(a,b);
			case 3: function(_,a,b,c) return h.getFn()(a,b,c);
			case 4: function(_,a,b,c,d) return h.getFn()(a,b,c,d);
			case 5: function(_,a,b,c,d,e) return h.getFn()(a,b,c,d,e);
			case 6: function(_,a,b,c,d,e,f) return h.getFn()(a,b,c,d,e,f);
			case 7: function(_,a,b,c,d,e,f,g) return h.getFn()(a,b,c,d,e,f,g);
			case _: throw "TemplateHelper supports a maximum of 7 arguments";
		}
	}

	#if hxdtl
		/**
		A templating engine for `hxdtl.Template` (Haxe Django Templating Language) templates, using "dtl" extensions.

		This is available when the `hxdtl` haxelib is used.
		**/
		public static var hxdtl(get,null):TemplatingEngine;
		static function get_hxdtl() return {
			factory: function ( tplString ):UFTemplate {
				var t = new hxdtl.Template( tplString );
				return function (data:TemplateData) return t.render( data.toObject() );
			},
			type: "hxdtl.Template",
			extensions: ["dtl"]
		}
	#end

	#if hxtemplo
		/**
		A templating engine that creates `templo.Template` (Simn's Haxe port of Templo) objects, and uses "mtt" extensions.

		This is available when the `hxtemplo` haxelib is used.
		**/
		public static var hxtemplo(get,null):TemplatingEngine;
		static function get_hxtemplo() return {
			factory: function ( tplString ):UFTemplate {
				var t = templo.Template.fromString( tplString );
				return function (data:TemplateData) return t.execute( data );
			},
			type: "templo.Template",
			extensions: ["mtt"]
		}
	#end

	#if mustache
		/**
		A templating engine for `Mustache` templates, using "mustache" extensions.

		This is available when the `mustache` haxelib is used.
		**/
		public static var mustache(get,null):TemplatingEngine;
		static function get_mustache() return {
			factory: function ( tplString ):UFTemplate {
				return function (data:TemplateData) return Mustache.render( tplString, data.toObject() );
			},
			type: "Mustache",
			extensions: ["mustache"]
		}
	#end

	#if erazor
		/**
		Similar to `TemplatingEngines.erazorHtml`, but with no HTML escaping.

		Please only use this if you are sure it is safe to trust the data being passed to your templates.
		If you have are exporting user data as HTML, using `erazor` rather than `erazorHtml` will open you to the risk of XSS injection attacks.

		This is available when the `erazor` haxelib is used.
		**/
		public static var erazor(get,null):TemplatingEngine;
		static function get_erazor() return {
			factory: function ( tplString ):UFTemplate {
				var t = new erazor.Template( tplString );
				return function (data:TemplateData) return t.execute( data.toObject() );
			},
			type: "erazor.Template",
			extensions: ["html","erazor"]
		}

		/**
		A templating engine for `Erazor` templates, a Haxe port of the `mvc-razor` templating language.

		Let's you mix Haxe code in with your templates.

		Unlike `TemplatingEngines.erazor`, this engine will automatically escape all data.
		You can use the `@raw()` helper to render data that should not be HTML escaped.
		Helpers and Partials are not escaped - please be careful to make sure your partials escape by default.

		If you wish to use a version that does no HTML escaping by default, use `TemplatingEngines.erazor`.

		Note: this only does runtime erazor templates, currently the macro-powered type checking is not available.

		This is available when the `erazor` haxelib is used.
		**/
		public static var erazorHtml(get,null):TemplatingEngine;
		static function get_erazorHtml() return {
			factory: function ( tplString ):UFTemplate {
				var t = new erazor.HtmlTemplate( tplString );
				return function (data:TemplateData, ?helpers:Map<String,TemplateHelper>) {
					var combinedData = new TemplateData();
					if ( helpers!=null ) {
						for ( helperName in helpers.keys() ) {
							var wrappedHelper = wrapHelperFnWithErazorSafeString( helpers[helperName] );
							combinedData.set( helperName, wrappedHelper );
						}
					}
					combinedData.setObject( data );
					return t.execute( combinedData );
				}
			},
			type: "erazor.HtmlTemplate",
			extensions: ["html","erazor"]
		}

		static function wrapHelperFnWithErazorSafeString( h:TemplateHelper ):Function {
			return switch h.numArgs {
				case 0: function() return new erazor.Output.SafeString( h.getFn()() );
				case 1: function(a) return new erazor.Output.SafeString( h.getFn()(a) );
				case 2: function(a,b) return new erazor.Output.SafeString( h.getFn()(a,b) );
				case 3: function(a,b,c) return new erazor.Output.SafeString( h.getFn()(a,b,c) );
				case 4: function(a,b,c,d) return new erazor.Output.SafeString( h.getFn()(a,b,c,d) );
				case 5: function(a,b,c,d,e) return new erazor.Output.SafeString( h.getFn()(a,b,c,d,e) );
				case 6: function(a,b,c,d,e,f) return new erazor.Output.SafeString( h.getFn()(a,b,c,d,e,f) );
				case 7: function(a,b,c,d,e,f,g) return new erazor.Output.SafeString( h.getFn()(a,b,c,d,e,f,g) );
				case _: throw "TemplateHelper supports a maximum of 7 arguments";
			}
		}
	#end

	#if stipple
		/**
		Stipple is a re-adaptation of the popular [Handlebars](http://handlebarsjs.com/) javascript template framework for the Haxe programming language.

		You can find more about it here: https://bitbucket.org/grumpytoad/stipple

		This is available when compiled with `-D stipple`.
		**/
		public static var stipple(get, null):TemplatingEngine;
		static function get_stipple() return {
			factory: function ( tplString ):UFTemplate {
				var t = new stipple.Template().fromString(tplString);
				return function (data:TemplateData) return t.execute( data.toObject() );
			},
			type: "stipple",
			extensions: ["stipple","html"]
		}
	#end
}

/**
A TemplatingEngine is a simple typedef defining how to use a given templating engine.

It smooths over the differences in various runtime templating systems, requiring the bare minimum to get a template to render.

Please note this is only suitable for engines which have run-time template rendering - engines requiring macros are not supported.

If you require more fine-grained
**/
typedef TemplatingEngine = {
	/** A factory function taking a template String and producing a ready-to-execute `UFTemplate`. **/
	public var factory:String->UFTemplate;

	/**
	A unique name for this templating engine.

	Using the fully qualified class name of the templating system is a good option.

	This is required so that a particular templating engine can be requested at runtime - for example in `ViewResult`.
	**/
	public var type:String;

	/**
	A list of file extensions that this templating engine supports.
	For example `["html", "tpl", "erazor"]` if you support "template.html", "template.tpl" and "template.erazor".
	**/
	public var extensions:Array<String>;
}
