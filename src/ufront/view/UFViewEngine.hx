package ufront.view;

#if macro
	import haxe.macro.Context;
#end
import ufront.view.TemplatingEngines;
import haxe.ds.Option;
using haxe.io.Path;
using tink.CoreApi;
using Lambda;

/**
A `UFViewEngine` is responsible for providing a ready-to-execute `UFTemplate` for a given template path.

This is a base class, and does not actually fetch any templates.
Please use a sub-class, such as `FileViewEngine` or `HttpViewEngine` instead.

Details:

- Each sub-class provides a different implementation of `this.getTemplateString()`.
  For example, fetching it from the file system (as in `FileViewEngine`) or over the network (as in `HttpViewEngine`).
- `UFViewEngine` can optionally cache the `UFTemplate` objects, keeping them ready to execute quickly for future requests.
- `this.addTemplatingEngine()` can be used to add a list of templating engines that you support.
  If you are using a `UfrontApplication`, the templating engines defined in your `UfrontConfiguration.templatingEngines` will be used.
  By default, this means all engines available in `TemplatingEngines.all`.
- When you call `this.getTemplate()`, you specify the path of the template you want, and optionally, the templating engine.
  The path can include the file extension of the template, but it will also work without it - using the extensions available in each templating engine instead.
  The full process for finding a template based on the path and the templating engines is described in the documentation for `this.getTemplate()`.

@TODO: refactor to use an injected UFCache, rather than a map.
**/
class UFViewEngine {

	/**
	Should we enable view caching by default?

	If caching is enabled, the templates will be loaded and parsed, ready to execute, and stored in memory between requests.

	This will only have an effect on platforms that support maintaining static variables between requests, such as NodeJS, Client JS, or Neko when using `Web.cacheModule`.
	On other platforms that do not support caching across requests, templates will only be cached during the same request.

	By default, this is `true` normally, but `false` if being compiled in `-debug` mode.

	To change the default behaviour, you can either change this static variable, or you can pass the `cachingEnabled` parameter to the constructor for each instance.
	**/
	public static var cacheEnabledByDefault = #if debug false #else true #end;

	var engines:Array<TemplatingEngine>;
	var cache:Map<String,Pair<String,UFTemplate>>;

	/**
	Create a new view engine.
	The constructor is private, because this is an abstract class.
	Please use one of the sub-class implementations.

	@param cachingEnabled Should we cache templates between requests? If not supplied, the value of `UFViewEngine.cacheEnabledByDefault` will be used by default.
	**/
	function new( ?cachingEnabled:Null<Bool> ) {
		if ( cachingEnabled==null )
			cachingEnabled = cacheEnabledByDefault;
		if ( cachingEnabled )
			cache = new Map();
		engines = [];
	}

	/**
	Fetch a template for the given path.

	Behaviour:

	- **If caching is enabled, and a cache for this request exists, return the cached `UFTemplate` immediately.**

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

	- In each case, if no match is found, this will fail with the appropriate error.
	- Once the template is found, the appropriate engine will be used to generate a `UFTemplate`, ready to execute.
	- If there is an error parsing or initializing a template, this will return a failure.
	- If a template was initialized successfully, and caching is being used, it will be added to the cache.

	This operation is asynchronous (returing a `Surprise`), and should result in a `Failure` if the view is not found or could not be parsed.
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
						finalPath = haxe.io.Path.normalize(path);
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
		// Return this future
		return
			tplStrReady.asFuture() >>
			function (tplStr) {
				try {
					var tpl:UFTemplate = templatingEngine.factory(tplStr);
					if(cache != null)
						cache[path] = new Pair( templatingEngine.type, tpl );
					return Success( tpl );
				}
				catch ( e:Dynamic ) {
					return Failure( Error.withData('Failed to pass template $finalPath using ${templatingEngine.type}', e) );
				}
			}
	}

	/**
	Fetch the template string for an exact path.

	Each sub-class must provide it's own implementation.
	For example, `HttpViewEngine` will fetch the template string from the network using `haxe.Http`.
	Alternatively, `FileViewEngine` will fetch the template string from the filesystem using `sys.io.File`.
	The default implementation in `UFViewEngine.getTemplateString()` will always return a failure - you must use a subclass.

	The return type is a `Surprise<Option<String>,Error>`.

	- This allows a `UFViewEngine` implementation to work asynchronously.
	- A `Success(Some(s:String))` means that a template was found, and the given template string is supplied.
	- A `Success(None)` means that no template with the specified path was found.
	- A `Failure(e:Error)` will describe an error that occured (for example, if network connectivity failed).
	**/
	public function getTemplateString( path:String ):Surprise<Option<String>,Error> {
		return Future.sync( Failure(new Error('Attempting to fetch template $path with UFViewEngine.  This is an abstract class, you must use one of the ViewEngine implementations.')) );
	}

	/**
	Add support for a templating engine.

	A supplied `TemplatingEngine` will transform a template `String` into a ready-to-execute `UFTemplate`.
	See `TemplatingEngines` for a list of templating engines that are available and ready to use.

	Notes:

	- If the engine specifies one or more file extensions, any views found with those extension will use this templating engine.
	- If multiple templating engines use the same extension, the first templating engine added will be the used to process the template.
	- If no extension is specified for this engine, then the engine will be used for any view regardless of the extension.
	**/
	public inline function addTemplatingEngine( engine:TemplatingEngine ) {
		engines.push( engine );
	}
}
