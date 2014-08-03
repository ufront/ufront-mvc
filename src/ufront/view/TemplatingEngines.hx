package ufront.view;

#if mustache import mustache.Mustache; #end
using tink.CoreApi;

/**
	This class provides some shortcut definitions to TemplatingEngines.

	These shortcuts are added for your convenience.
	They don't include the actual template libraries, rather, they return a typedef that let's our UFViewEngine know how to use the templating library so you can add it easily.

	The static variables for each library are surrounded in conditionals, so they will only be included if you have that library included in your current build.

	Templating engines currently provided:

	- `haxe` - provided in the Standard Library, no extra haxelibs needed.
	- `hxdtl` - Django Templating Library for Haxe.  Available if `hxdtl` haxelib is included.
	- `hxtemplo` - Simn's port of the `templo` templating language.  Available if `hxtemplo` haxelib is included.
	- `mustache` - Mustache "Logic-less" templates.  Available if `mustache` haxelib is included.
	- `erazor` - A powerful templating language that lets you switch between templates and haxe-code effortlessly.  Based on `mvc-razor`.  Available if `erazor` haxelib is included.

	If you would like to add support for another library, please send a pull request!
**/
class TemplatingEngines {

	/**
		A templating engine for `haxe.Template` templates, using "html" and "tpl" extensions.

		This is available through the standard library.
	**/
	public static var haxe(get,null):TemplatingEngine;
	static function get_haxe() return {
		factory: function ( tplString ):UFTemplate {
			var t = new haxe.Template( tplString );
			return function (data:TemplateData) return t.execute( data.toObject() );
		},
		type: "haxe.Template",
		extensions: ["html", "tpl"]
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
			A templating engine for `Erazor` templates, a Haxe port of the `mvc-razor` templating language.  Let's you mix Haxe code in with your templates.

			Note: this only does runtime erazor templates, currently the macro-powered type checking is not available.
		**/
		public static var erazor(get,null):TemplatingEngine;
		static function get_erazor() return {
			factory: function ( tplString ):UFTemplate {
				var t = new erazor.Template( tplString );
				return function (data:TemplateData) return t.execute( data.toObject() );
			},
			type: "erazor.Template",
			extensions: ["erazor","html"]
		}
	#end

}

/**
	A summary of the information required for adding a templating engine to `ufront.view.UFViewEngine`
**/
typedef TemplatingEngine = {
	/** A factory function for producing a working template given a string input **/
	factory:String->UFTemplate,

	/** The class that is produced by the factory.  This is used so that a `ufront.web.result.ViewResult` can request a particular TemplatingEngine. **/
	type: String,

	/** A list of file extensions that this templating engine supports.  For example `["html", "tpl", "erazor"]` **/
	extensions: Array<String>
}
