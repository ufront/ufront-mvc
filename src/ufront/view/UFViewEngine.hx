package ufront.view;

#if macro 
	import haxe.macro.Context;
#end 
import ufront.view.TemplatingEngines;
import ufront.core.Sync;
import haxe.ds.Option;
using haxe.io.Path;
using tink.CoreApi;
using Lambda;

/**
	The base class for view engines.

	Each view engine is responsible for getting access to the raw templates, and, using a pluggable system, preparing templates ready to execute.

	In detail:

	- adding support for different templating engines.  
	  The UFViewEngine never parses or executes the template, we leave this to the templating engine.  
	  But we can plug different templating engines in with `addTemplatingEngine()`
	- adding helpers that are available to all templates.  
	  These are untyped functions that are made available to the templates and may help with formatting etc.
	- given a view path, finding the correct template, feeding it to the correct templating engine, and returning a ready to execute `ufront.view.UFTemplate`
	- any caching, such as keeping the templates loaded, parsed and ready to execute between multiple requests etc.

	Example implementations may be "FileViewEngine" (load from files on hard drive), "DatabaseViewEngine" (load templates from DB) or "MacroViewEngine" (import views at macro time so we have them ready to go in our code.
**/
class UFViewEngine {

	#if macro

		/**
			This method is required at macro time, and is used by `ufront.web.result.ViewResult.check` to check that all required templates are available.

			At this point in time each `UFViewEngine` class only needs to guarantee that the template is available, the required infrastructure to check that it parses, compiles or has the correct variables is not available.
		**/
		public function checkTemplate( path:String, ?templatingEngine:TemplatingEngine ):Outcome<Null<String>,Error> {
			Context.error( "UFViewEngine.checkTemplate() not implemented yet", Context.currentPos() );
			return null;
		}

	#end

	var engines:Array<TemplatingEngine>;
	var cache:Map<String,Pair<String,UFTemplate>>;

	public function new( ?cachingEnabled=true ) {
		if ( cachingEnabled ) cache = new Map();
	}

	/** 
		Fetch a template for the given path.
		
		Behaviour:

		- **If caching is enabled, and a cache for this request exists, use it**

		- **If a templating engine is specified, and the path has an extension:**
		  The exact path will used, with the given templating engine, regardless of whether the extensions match or not.
		
		- **If a templating engine is specified, and the path does not have an extension:**
		  For each extension that this templating engine supports, look for an available template.
		  The first match will be used.

		- **If no templating engine is specified, and the path has an extension:**
		  Go through the available templating engines, in the order they were added. 
		  If the engine supports our extension, check for a matching template.
		  The first match will be used.

		- **If no templating engine is specified, and the path does not have an extension:**
		  Go through the available templating engines, in the order they were added.
		  For each extension that engine supports, check for a matching template.
		  The first match will be used.

		In each case, if no match is found, this will fail with the appropriate error.

		Once the template is found, the appropriate engine will be used to generate a UFTemplate (ready to execute) from that template.

		If there is an error parsing or initializing a template, this will return a failure.
		
		If a template was initialized successfully, it will be added to the cache.

		Please note, `ufront.view.UFViewEngine` is an abstract implementation that never checks for templates, it always fails.  Please use the appropriate subclass if you want your templates to work.

		This operation is asynchronous (a `tink.core.Surprise`), and should return a Failure if the view is not found or could not be parsed.
	**/
	public function getTemplate( path:String, ?templatingEngine:TemplatingEngine ):Surprise<UFTemplate,Error> {

		if ( cache!=null && cache.exists(path) ) {
			var cached = cache[path];
			if ( templatingEngine==null || templatingEngine.type==cached.a )
				return Future.sync( Success(cached.b) );
		}
		
		var tplStrReady:FutureTrigger<Outcome<String,Error>> = Future.trigger();
		var ext = path.extension();
		var finalPath:String = null;

		if ( templatingEngine!=null && ext!="" ) {
			// We have the engine and the exact path, so read the file
			finalPath = path;
			getTemplateString( finalPath ).handle( function (result) switch result {
				case Failure(err): tplStrReady.trigger( Failure(err) );
				case Success(Some(tpl)): tplStrReady.trigger( Success(tpl) );
				case Success(None): tplStrReady.trigger( Failure(new Error('Template $path not found')) );
			});
		}
		else if ( templatingEngine!=null && ext=="" ) {
			// We have the engine, but not the exact path. Use each available extension.
			var exts = templatingEngine.extensions.copy();
			function testNextExtension() {
				if ( exts.length>0 ) {
					var ext = exts.shift();
					finalPath = path.withExtension(ext);
					getTemplateString( finalPath ).handle( function (result) switch result {
						case Failure(err): tplStrReady.trigger( Failure(err) );
						case Success(Some(tpl)): tplStrReady.trigger( Success(tpl) );
						case Success(None): testNextExtension();
					});
				}
				else tplStrReady.trigger( Failure(new Error('No template found for $path with extensions ${templatingEngine.extensions}')) );
			}
			testNextExtension();
		}
		else if ( templatingEngine==null && ext!="" ) {
			var tplEngines = engines.copy();
			function testNextEngine() {
				if ( tplEngines.length>0 ) {
					var engine = tplEngines.shift();
					if ( engine.extensions.has(ext) ) {
						finalPath = path;
						getTemplateString( finalPath ).handle( function (result) switch result {
							case Failure(err): tplStrReady.trigger( Failure(err) );
							case Success(Some(tpl)): 
								templatingEngine = engine;
								tplStrReady.trigger( Success(tpl) );
							case Success(None): tplStrReady.trigger( Failure(new Error('Template $path not found')) );
						});
					} else testNextEngine();
				}
				else tplStrReady.trigger( Failure(new Error('No templating engine found for $path (None support extension $ext)')) );
			}
			testNextEngine();
		}
		else if ( templatingEngine==null && ext=="" ) {
			var tplEngines = engines.copy();
			
			var engine:TemplatingEngine = null;
			var extensions:Array<String> = [];
			var extensionsUsed:Array<String> = [];
			var ext:String = null;
			
			function testNextEngineOrExtension() {
				if ( extensions.length==0 && tplEngines.length==0 ) {
					tplStrReady.trigger( Failure(new Error('No template found for $path with extensions $extensionsUsed')) );
					return;
				}
				else if ( extensions.length==0 ) {
					engine = tplEngines.shift();
					extensions = engine.extensions.copy();
					ext = extensions.shift();
				}
				else ext = extensions.shift();

				extensionsUsed.push( ext );

				finalPath = path.withExtension(ext);
				getTemplateString( finalPath ).handle( function (result) switch result {
					case Failure(err): tplStrReady.trigger( Failure(err) );
					case Success(Some(tpl)):
						templatingEngine = engine;
						tplStrReady.trigger( Success(tpl) );
					case Success(None): testNextEngineOrExtension();
				});
				return;
			}
		}

		// Once the tplStrReady is loaded, transform a successfully loaded template string 
		// into a ready to execute template using the factory.  If there's an error parsing
		// the template, return the failure.
		// Return this mapped future
		return
			tplStrReady.asFuture() >> 
			function (tplStr) {
				try {
					var tpl:UFTemplate = templatingEngine.factory(tplStr);
					cache[path] = new Pair( templatingEngine.type, tpl );
					return Success( tpl );
				}
				catch ( e:Dynamic ) {
					return Failure( Error.withData('Failed to pass template $finalPath using ${templatingEngine.type}', e) );
				}
			}
	}

	/**
		Abstract method to fetch the template string for an exact path.

		This must be overridden by a subclass to be useful, in `UFViewEngine` it will always return a Failure.
	**/
	public function getTemplateString( path:String ):Surprise<Option<String>,Error> {
		return Future.sync( Failure(new Error('Attempting to fetch template $path with UFViewEngine.  This is an abstract class, you must use one of the ViewEngine implementations.')) );
	}

	/**
		Add support for a templating engine.

		A factory function must be given, which, given a string, can prepare a UFTemplate.

		The "class" of the template must be specified, which is simply an identifier that allows your controllers to request a custom templating engine.  
		The class itself is not referenced, it's name is only used as an identifier.  
		For example, if your template factory returns a `haxe.Template`, you should specify the class as `haxe.Template`.

		If an extension is specified, any views found with that extension will use this templating engine.
		If multiple templating engines use the same extension, the first templating engine added will be the first used.
		If no extension is supplied, this templating engine will match any view.  
		Templating engines with a matching view will have precedence over templating engines with no view.
	**/
	public inline function addTemplatingEngine( engine:TemplatingEngine ) {
		engines.push( engine );
	}
}