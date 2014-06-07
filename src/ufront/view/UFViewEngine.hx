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

	Each view engine is responsible for getting access to the raw templates, and, using a pluggable system, preparing templates so they are ready to execute.

	In detail:

	- adding support for different templating engines.  
	  The UFViewEngine never parses or executes the template, we leave this to the templating engine.  
	  But we can plug different templating engines in with `addTemplatingEngine()`.

	- given a view path, finding the correct template, feeding it to the correct templating engine, and returning a ready to execute `ufront.view.UFTemplate`

	- any caching, such as keeping the templates loaded, parsed and ready to execute between multiple requests etc.
	
	The `UFViewEngine` base class does not provide the `getTemplateString()` implementation.  
	Each View Engine implementation must provide this.  
	Example implementations may be `ufront.view.FileViewEngine` (load from files on hard drive), "DatabaseViewEngine" (load templates from DB) or "MacroViewEngine" (import views at macro time so we have them ready to go in our code.
	This `UFViewEngine` base class does provide a `getTemplate()` which will wrap each implementations `getTemplateString()` method and provide appropriate searching, caching and instantiating of templates.  
	See the documentation on the `getTemplate` method for more details.
**/
class UFViewEngine {

	var engines:Array<TemplatingEngine>;
	var cache:Map<String,Pair<String,UFTemplate>>;

	/**
		Create a new view engine.

		@param cachingEnabled Should we cache templates in memory so they are ready to re-execute? Default=true.
	**/
	function new( ?cachingEnabled=true ) {
		if ( cachingEnabled ) cache = new Map();
		engines = [];
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
		  For each extension that the engine supports, check for a matching template.
		  The first match will be used.

		In each case, if no match is found, this will fail with the appropriate error.

		Once the template is found, the appropriate engine will be used to generate a UFTemplate (ready to execute) from that template.

		If there is an error parsing or initializing a template, this will return a failure.
		
		If a template was initialized successfully, it will be added to the cache.

		Please note, `ufront.view.UFViewEngine` is an abstract implementation that never checks for templates, it always fails.  Please use the appropriate implementation class if you want your templates to work.

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
			testNextEngineOrExtension();
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

		The return type is:
		
		```
		- A Future (so async platforms are supported)
		- An Outcome (success or failure)
			- Failure means an error occured while checking if the file exists, or while trying to read it.
			- Success returns an Option, letting you know:
				- Some - the template exists, and here are it's contents as a String, or
				- None - no file existed at that path..
		```
	**/
	public function getTemplateString( path:String ):Surprise<Option<String>,Error> {
		return Future.sync( Failure(new Error('Attempting to fetch template $path with UFViewEngine.  This is an abstract class, you must use one of the ViewEngine implementations.')) );
	}

	/**
		Add support for a templating engine.
		
		A supplied `ufront.view.TemplatingEngine` which given a template string, will prepare a ready-to-execute UFTemplate.  
		See `ufront.view.TemplatingEngines` for a list of templating engines that are available and ready to use.

		If the engine specifies one or more file extensions, any views found with those extension will use this templating engine.  
		If multiple templating engines use the same extension, the first templating engine added will be the used to process the template.  
		If no extension is specified for this engine, then the engine will be used for any view regardless of the extension.  
	**/
	public inline function addTemplatingEngine( engine:TemplatingEngine ) {
		engines.push( engine );
	}
}