package ufront.web.result;

#if macro
	import haxe.macro.Expr;
#end
import haxe.PosInfos;
import ufront.view.TemplateData;
import ufront.view.TemplateHelper;
import ufront.view.TemplatingEngines;
import ufront.view.UFViewEngine;
import ufront.view.UFTemplate;
import haxe.ds.Option;
import ufront.web.HttpError;
import ufront.web.Controller;
import ufront.web.context.ActionContext;
import ufront.core.AsyncTools;
import haxe.rtti.Meta;
using tink.CoreApi;
using haxe.io.Path;
using StringTools;

/**
A ViewResult loads a view from a `UFViewEngine`, executes it with the correcct `TemplatingEngine`, optionally wraps it in a layout, and writes the result to the `HttpResponse`.

It is designed to work with different templating engines, to be intelligent with guessing the correct view, and to work seamlessly on asynchronous platforms.

It writes the final output to the client `HttpResponse` with a `text/html` content type.

### Choosing a view

A ViewResult will attempt to guess which view to use, based on the current `ActionContext`, that is, based on which controller you are in and which method was executed for the request.
It feels a bit like magic, but it's not: let's step through how it works.

__Let's look at an example:__

```haxe
class AdminController extends Controller {
  @:route("/dashboard/")
  function doDashboard() {
    return new ViewResult();
  }

  @:route("/camera/")
  function takePhoto() {
    return new ViewResult();
  }
}
```

- If you visit `/dashboard/`, it is going to use a template at `/view/admin/dashboard.html` by default.
- If you visit `/camera/`, it is going to use a template at `/view/admin/takePhoto.html` by default.

__How does it know to look there?__

1. `/view/` is your viewPath, set in `UfrontConfiguration.viewPath`
2. `admin/` is guessed based on the name `AdminController`.
   We lower-case the first letter, and ignore the "Controller" part of the name.
   Another example is `BlogPostController` or just `BlogPost` looking for views in "/blogPost/".
3. `dashboard.html` and `takePhoto.html` are guessed based on the action name / method name.
   If the name begins with "do" followed by an uppercase letter, we ignore the "do" letters.
   So `function doDefault()` will look for a view called `default.html`.
   We also make sure the first letter is lower-case.

__How do we change it?__

Well you can use metadata.

To change the default folder that views in this controller are found in, use the `@viewFolder` metadata:

```haxe
@viewFolder("/admin-templates/")
class AdminController extends Controller {
  // Views will be in the `view/admin-templates/` folder.
}
```

You can also set a default layout for every action on the controller:

```haxe
@viewFolder("/admin-templates/")
@layout("layout.html") // Will look in `view/admin-templates/layout.html`
class AdminController extends Controller {
  // Views will be in the `view/admin-templates/` folder.
  // Layout will be "layout.html".
}

// If you would prefer to use a layout that isn't inside the controller's `viewFolder`, add a leading slash to `@layout`:
@viewFolder("/admin-templates/")
@layout("/layout.html")
class AdminController extends Controller {
  // Views will be in the `view/admin-templates/` folder.
  // Layout will be `view/layout.html`.
}

```

If you want to change the template used for one of our actions, you can use the `@template` metadata:

```haxe
@:route("/camera/")
@template("camera.html") // Will look in `view/admin-templates/camera.html`
@layout("cameraLayout.html") // Will look in `view/admin-templates/cameraLayout.html`
function takePhoto() {
  return new ViewResult();
}
```

To specify a template to use manually in your code:

```
return new ViewResult({}, "myView.html");
return new ViewResult({}, "myView.html").withLayout("layout.html");
return new ViewResult({}, "myView.html").withoutLayout();
```

This gives you a fair amount of flexibility:

1. Do nothing, and let Ufront guess.
2. Be more specific, and use metadata, which is still nice and clean.
3. Be very specific and flexible, specifying it in your code.

__What about file extensions?__

I've used ".html" views in all these examples, but you could leave this out.

If the viewPath does not include an extension, any view matching one of the extensions supported by our templating engines will be used.
You can optionally specify a TemplatingEngine to use also.
See `UFViewEngine.getTemplate()` for a detailed description of how a template is chosen.

### Setting data

When you create the view, you can specify some data to execute the template with:

```haxe
new ViewResult({ name: "jason", age: 26 });
```

You can add to this data using `ViewResult.setVar()` and `ViewResult.setVars()`.

You can also specify some global data that will always be included for your app:

```
ViewResult.globalValues["copyright"] = "&copy; 2014 Haxe Foundation, all rights reserved.";
```

Helpers (dynamic functions) can be included in your ViewResult also.

### Wrapping your view with a layout

Most websites will have a layout that is used on almost all of your pages, and then individual views for each different kind of page.

In Ufront, a layout is just another `ufront.view.UFTemplate` which has a variable called "viewContent".
The result of the current view will be inserted into the "viewContent" field of the layout.
All of the same data mappings and helpers will be available to the layout when it renders.

You can set a default layout to be used with all ViewResults using the static method `ViewResult.setDefaultLayout()`, or by injecting a String named "defaultLayout" into the app's dependency injector.
You can set a default layout for a controller using `@layout("layout.html")` style metadata.
You can set a layout for an individual result using `ViewResult.withLayout()`.
Finally if you have a default layout, but want to NOT use a layout, you can use `ViewResult.withoutLayout()`

### Where does it get the views from?

Short answer: by default, it gets them from the filesystem in the "view/" folder relative to the script directory.

Long answer:

Ufront supports different view engines. (See `UFViewEngine`).
For example, you could have a view engine that loads templates from a database, rather than from the FileSystem.
Or one that loads them over HTTP from a server somewhere.

ViewResult will use dependency injection to get the correct UFViewEngine four our app.
You can set this by setting `UfrontConfiguration.viewEngine` when you start your Ufront app.
By default, it is configured to use the `FileViewEngine`, loading views from the "view/" directory relative to your script directory, so "www/view/".

### What if I want a different templating engine?

We use a `UFViewEngine` to load our templates, and these support multiple templating engines.
You can view some available engines in `TemplatingEngines`, and it will be fairly easy to create a new templating engine if needed.
You can use `UfrontApplication.addTemplatingEngine()` to add a new engine, which will then be available to your view results.

### Partial URLs

We will use `ContentResult.replaceVirtualLinks` to replace virtual URIs in HTML `src`, `href` and `action` attributes.

```html
<!-- So this template: -->
<a href="~/login/">Login</a>
<!-- Might become (depending on how your app is set up): -->
<a href="/path/to/app/index.php?q=/login/">Login</a>
```
**/
class ViewResult extends ActionResult {

	//
	// Statics
	//

	/**
	A shortcut to create a new ViewResult.

	This is useful when you are waiting for a Future: `return getFutureContent() >> ViewResult.create;`
	**/
	public static function create( data:{} ):ViewResult return new ViewResult( data );

	/**
	Global values that should be made available to every ViewResult.
	**/
	public static var globalValues:TemplateData = {};

	/**
	Global helpers that should be made available to every ViewResult.
	**/
	public static var globalHelpers:Map<String,TemplateHelper> = new Map();

	/**
	Global partials that should be made available to every ViewResult.
	**/
	public static var globalPartials:Map<String,TemplateSource> = new Map();

	//
	// Member Variables
	//

	/**
	The data to pass to the template during `executeResult`.
	This will be combined with the `helpers` and `globalData` before being passed to the templates `execute` function.
	This is set during the constructor, and you can add to it using the `setVar` and `setVars` helper methods.
	**/
	public var data:TemplateData;

	/**
	Any helpers (dynamic functions) to pass to the template when it is executed.
	**/
	public var helpers:Map<String,TemplateHelper>;

	/**
	Any partials that are to be made available during rendering.

	They will be loaded during `renderResult()` and executed as required.
	**/
	public var partials:Map<String,TemplateSource>;

	/**
	The default folder to assume the templates are in.

	Any template that is to be loaded from an engine, and whose path does not begin with a '/', (so is not absolute), will be searched for inside `viewFolder`.

	If `viewFolder` is null when `executeResult()` is called, it will be set based on the controller's `@viewFolder` metadata, or based on the controller's name.
	**/
	public var viewFolder:Null<String>;

	/** The source used for loading a view template. Set in the constructor or with `this.usingTemplateString()`, or inferred during `this.executeResult()`. **/
	public var templateSource(default,null):TemplateSource;

	/** The source used for loading a layout template. Set in `this.withLayout()`, `this.withoutLayout()` `this.usingTemplateString()`, or inferred during `this.executeResult()`. **/
	public var layoutSource(default,null):TemplateSource;

	/** A `Future` that will eventually hold the final compiled output for the `ViewResult`. **/
	public var finalOutput(default,null):Future<String>;

	var finalOutputTrigger:FutureTrigger<String>;

	//
	// Member Functions
	//

	/**
	Create a new ViewResult, with the specified data.

	@param data (optional) Some initial template data to set. If not supplied, an empty {} object will be used.
	@param viewPath (optional) A specific view path to use. If not supplied, it will be inferred based on the `ActionContext` in `this.executeResult()`.
	@param templatingEngine (optional) A specific templating engine to use for the view. If not supplied, it will be inferred based on the `viewPath` in `this.executeResult()`.
	**/
	public function new( ?data:TemplateData, ?viewPath:String, ?templatingEngine:TemplatingEngine ) {
		this.data = (data!=null) ? data : {};
		this.helpers = new Map();
		this.partials = new Map();
		this.templateSource = (viewPath!=null) ? TFromEngine(viewPath,templatingEngine) : TUnknown;
		this.layoutSource = TUnknown;
		this.finalOutputTrigger = Future.trigger();
		this.finalOutput = finalOutputTrigger;
	}

	/**
	Specify a layout to wrap this view.

	@param layoutPath
	@param templatingEngine (optional) A templating engine to use with this layout. If none is specified, the first templating engine matching the layoutPath's extension will be used.
	**/
	public function withLayout( layoutPath:String, ?templatingEngine:TemplatingEngine ):ViewResult {
		this.layoutSource = TFromEngine( layoutPath, templatingEngine );
		return this;
	}

	/** Prevent a default layout from wrapping this view - this view will appear standalone, not wrapped by a layout. **/
	public function withoutLayout():ViewResult {
		this.layoutSource = TNone;
		return this;
	}

	/**
	Use a static string as the templates, rather than loading from a UFViewEngine.

	If `template` or `layout` is not supplied or null, the usual rules will apply for loading a view using the UFViewEngine.

	@param template The template string for the view.
	@param layout (optional) The template string for the layout. If not supplied, the layout will be unaffected.
	@param templatingEngine (optional) The templating engine to render the given view and layout with. If not specified, `TemplatingEngine.haxe` will be used.
	**/
	public function usingTemplateString( template:String, ?layout:String, ?templatingEngine:TemplatingEngine ):ViewResult {
		if (templatingEngine==null)
			templatingEngine = TemplatingEngines.haxe;

		if (template!=null)
			this.templateSource = TFromString( template, templatingEngine );

		if (layout!=null)
			this.layoutSource = TFromString( layout, templatingEngine );

		return this;
	}

	/** Add a `key=>value` pair to our TemplateData **/
	public function setVar( key:String, val:Dynamic ):ViewResult {
		this.data[key] = val;
		return this;
	}

	/** Add an object or map with key=>value pairs to our TemplateData **/
	public function setVars( ?map:Map<String,Dynamic>, ?obj:{} ):ViewResult {
		if (map!=null) this.data.setMap( map );
		if (obj!=null) this.data.setObject( obj );
		return this;
	}

	/** Add a helper to be used in rendering the result. **/
	public function addHelper( name:String, helper:TemplateHelper ):ViewResult {
		helpers[name] = helper;
		return this;
	}

	/** Add multiple helpers to be used in rendering the result. **/
	public function addHelpers( helpers:Map<String,TemplateHelper> ):ViewResult {
		for ( name in helpers.keys() ) {
			addHelper( name, helpers[name] );
		}
		return this;
	}

	/** Add a partial template file to be available while rendering the result. **/
	public function addPartial( name:String, partialPath:String, ?templatingEngine:TemplatingEngine ):ViewResult {
		partials[name] = TFromEngine( partialPath, templatingEngine );
		return this;
	}

	/** Add a partial template string to be available while rendering the result. **/
	public function addPartialString( name:String, partialTemplate:String, templatingEngine:TemplatingEngine ):ViewResult {
		partials[name] = TFromString( partialTemplate, templatingEngine );
		return this;
	}

	/** Add multiple partial template files to be available while rendering the result. **/
	public function addPartials( partials:Map<String,String>, ?templatingEngine:TemplatingEngine ):ViewResult {
		for ( name in partials.keys() ) {
			addPartial( name, partials[name], templatingEngine );
		}
		return this;
	}

	/** Add multiple partial template strings to be available while rendering the result. **/
	public function addPartialStrings( partials:Map<String,String>, templatingEngine:TemplatingEngine ):ViewResult {
		for ( name in partials.keys() ) {
			addPartialString( name, partials[name], templatingEngine );
		}
		return this;
	}

	/**
	Execute the given ViewResult and write the response to the output.

	- If the layout or view has not been set, figure out which one to use. (See the documentation at the top of this class for details).
	- If `viewFolder` is null, it will be set based on the controller's `@viewFolder` metadata or based on the controller's name.
	- Run `renderResult()` with a `UFViewEngine` from our injector, and with the controller's `baseUri` property included in the default data.
	- When the final render of the ViewResult is ready, replace any relative relative URLs using `ContentResult.replaceVirtualLinks()`.
	- Write the final response to the client using `writeResponse()`. By default this will output it as `text/html`. You can also override `writeResponse()` in a sub class, as we do in `PartialViewResult`.
	**/
	override function executeResult( actionContext:ActionContext ) {
		if ( layoutSource.match(TUnknown) )
			layoutSource = inferLayoutFromContext( actionContext );
		if ( templateSource.match(TUnknown) )
			templateSource = inferViewPathFromContext( actionContext );
		if ( viewFolder==null )
			viewFolder = getViewFolder( actionContext );
		var viewEngine:UFViewEngine;
		try {
			viewEngine = actionContext.httpContext.injector.getValue( UFViewEngine );
		} catch (e:Dynamic) {
			return SurpriseTools.asSurpriseError( e, "Failed to find a UFViewEngine in ViewResult.executeResult(), please make sure that one is made available in your application's injector" );
		};

		var defaultData = new TemplateData();
		var controller = Std.instance( actionContext.controller, Controller );
		if ( controller!=null )
			defaultData.set( 'baseUri', controller.baseUri );

		return renderResult( viewEngine, defaultData ) >> function(finalOut:String):Noise {
			finalOut = ContentResult.replaceVirtualLinks( actionContext, finalOut );
			writeResponse( finalOut, actionContext );
			this.finalOutputTrigger.trigger( finalOut );
			return Noise;
		}
	}

	/**
	Render the current ViewResult and get the resulting String.

	The view and layout templates will both be loaded from the given `UFViewEngine`.
	They will be executed with:

	- partials from `ViewResult.globalPartials` and `this.partials`
	- helpers from `ViewResult.globalHelpers` and `this.helpers`
	- data from `this.defaultData`, `ViewResult.globalData` and `this.data`

	with the latter taking precedence over the former.

	The view will be rendered first, and then it's output will be available in the layout as the `viewContent` variable.

	This can be used separately from `executeResult()` if you want to render a ViewResult outside of a regular HTTP context.
	For example, if you wished to render a view and a layout to send a HTML email from the command line.
	**/
	public function renderResult( viewEngine:UFViewEngine, ?defaultData:TemplateData ):Surprise<String,Error> {
		if ( layoutSource.match(TUnknown) )
			return SurpriseTools.asSurpriseError( null, 'No layout template source was set on the ViewResult' );
		if ( templateSource.match(TUnknown) )
			return SurpriseTools.asSurpriseError( null, 'No view template source was set on the ViewResult' );
		if ( defaultData==null )
			defaultData = {}
		if ( viewFolder!=null ) {
			templateSource = addViewFolderToPath( templateSource, viewFolder );
			layoutSource = addViewFolderToPath( layoutSource, viewFolder );
		}
		var templateReady = loadTemplateFromSource( templateSource, viewEngine );
		var layoutReady = loadTemplateFromSource( layoutSource, viewEngine );
		var partialsReady = loadPartialTemplates( [globalPartials,partials], viewEngine );

		return FutureTools
			.when( templateReady, layoutReady, partialsReady )
			.map(function( viewTemplate:Outcome<Null<UFTemplate>,Error>, layoutTemplate:Outcome<Null<UFTemplate>,Error>, partialTemplates:Outcome<Map<String,UFTemplate>,Error> ) {
				try {
					var combinedData = TemplateData.fromMany([ defaultData, globalValues, data ]);
					var combinedHelpers = getCombinedMap([ globalHelpers, helpers ]);
					addHelpersForPartials( partialTemplates.sure(), combinedData, combinedHelpers );

					// Execute the view, and then the layout (inserting the `viewContent`).
					var viewOut = executeTemplate( "view", viewTemplate, combinedData, combinedHelpers ).sure();
					if ( layoutTemplate.match(Success(null)) ) {
						return Success( viewOut );
					}
					else {
						var layoutOut = executeTemplate( "layout", layoutTemplate, combinedData.set('viewContent',viewOut), combinedHelpers ).sure();
						return Success( layoutOut );
					}
				}
				catch (e:Error) return Failure( e );
			});
	}

	function writeResponse( response:String, actionContext:ActionContext ) {
		actionContext.httpContext.response.contentType = "text/html";
		actionContext.httpContext.response.write( response );
	}

	static function getCombinedMap<T>( mapSets:Array<Map<String,T>> ):Map<String,T> {
		var combinedMaps = new Map();
		for ( set in mapSets ) {
			for ( key in set.keys() ) {
				combinedMaps[key] = set[key];
			}
		}
		return combinedMaps;
	}

	static function getViewFolder( actionContext:ActionContext ):String {
		var controllerCls = Type.getClass( actionContext.controller );
		var viewFolderMeta = Meta.getType( controllerCls ).viewFolder;
		var viewFolder:String;
		if ( viewFolderMeta!=null && viewFolderMeta.length>0 ) {
			viewFolder = ""+viewFolderMeta[0];
			viewFolder = viewFolder.removeTrailingSlashes();
		}
		else {
			// Get the class name without the package, lowercase the first letter, and drop the "Controller" suffix.
			var controllerName = Type.getClassName( Type.getClass(actionContext.controller) ).split( "." ).pop();
			controllerName = controllerName.charAt(0).toLowerCase() + controllerName.substr(1);
			if ( controllerName.endsWith("Controller") )
				controllerName = controllerName.substr( 0, controllerName.length-10 );
			viewFolder = controllerName;
		}
		return viewFolder;
	}

	static function inferViewPathFromContext( actionContext:ActionContext ):TemplateSource {
		var viewPath:String;

		// Check for @template("...") metadata that specifies the view path on the action method.
		var controllerCls = Type.getClass( actionContext.controller );
		var fieldsMeta = Meta.getFields( controllerCls );
		var actionFieldMeta:Dynamic<Array<Dynamic>> = Reflect.field( fieldsMeta, actionContext.action );
		if ( actionFieldMeta!=null && actionFieldMeta.template!=null && actionFieldMeta.template.length>0 ) {
			viewPath = ""+actionFieldMeta.template[0];
		}
 		else {
			// If there was no metadata, use the action name to guess a reasonable view path.
			var action = actionContext.action;
			var startsWithDo = action.startsWith("do");
			var thirdCharUpperCase = action.length>2 && action.charAt(2)==action.charAt(2).toUpperCase();
			if ( startsWithDo && thirdCharUpperCase )
				action = action.substr(2);
			viewPath = action.charAt(0).toLowerCase() + action.substr(1);
		}

		return TFromEngine( viewPath, null );
	}

	static function inferLayoutFromContext( actionContext:ActionContext ):TemplateSource {
		var layoutPath:String = null;

		// Check for @layout("...") metadata that specifies the layout on the controller.
		var controllerCls = Type.getClass( actionContext.controller );
		var classMeta = Meta.getType( controllerCls );
		var fieldsMeta = Meta.getFields( controllerCls );
		var actionFieldMeta:Dynamic<Array<Dynamic>> = Reflect.field( fieldsMeta, actionContext.action );
		if ( actionFieldMeta!=null && actionFieldMeta.layout!=null && actionFieldMeta.layout.length>0 ) {
			layoutPath = ""+actionFieldMeta.layout[0];
		}
		else if ( classMeta.layout!=null && classMeta.layout.length>0 ) {
			layoutPath = ""+classMeta.layout[0];
		}
		else {
			// If there was no metadata, see if a "defaultLayout" string was injected by the app configuration.
			try {
				layoutPath = actionContext.httpContext.injector.getValue( String, "defaultLayout" );
				if ( layoutPath!=null && layoutPath.startsWith("/")==false ) {
					layoutPath = '/$layoutPath';
				}
			} catch (e:Dynamic) {}
		}

		return (layoutPath!=null) ? TFromEngine(layoutPath,null) : TNone;
	}

	static function addViewFolderToPath( layoutSource:TemplateSource, viewFolder:String ):TemplateSource {
		return switch layoutSource {
			case TFromEngine(path,engine):
				// Usually, a view will go inside a viewFolder - for example all views in HomeController will go inside `/$viewDir/home/`.
				// If a viewPath begins with a leading slash though, it is treated as "absolute", or at least, relative to the global viewDirectory, not the controller's viewFolder.
				// So if it is "absolute", drop the leading slash because it's only absolute relative to the viewDirectory.
				// If it does not begin with a leading slash, prepend the viewFolder.
				path = path.startsWith("/") ? path.substr(1) : '$viewFolder/$path';
				TFromEngine( path, engine );
			case _: layoutSource;
		}
	}

	static function loadTemplateFromSource( source:TemplateSource, engine:UFViewEngine ):Surprise<Null<UFTemplate>,Error> {
		return switch source {
			case TFromString(str,templatingEngine):
				try Future.sync( Success(templatingEngine.factory(str)) )
				catch (e:Dynamic) {
					var engine = 'Templating Engine: "${templatingEngine.type}"';
					var template = 'String template: "${str}"';
					Future.sync( error('Failed to parse template.','$engine\n$template') );
				}
			case TFromEngine(path,templatingEngine): engine.getTemplate( path, templatingEngine );
			case TNone, TUnknown: Future.sync( Success(null) );
		}
	}

	static function loadPartialTemplates( partialSources:Array<Map<String,TemplateSource>>, engine:UFViewEngine ):Surprise<Map<String,UFTemplate>,Error> {
		var allPartialSources = getCombinedMap( partialSources );
		var allPartialTemplates = new Map();
		var partialErrors = new Map();
		var allPartialFutures = [];
		for ( name in allPartialSources.keys() ) {
			var source = allPartialSources[name];
			var surprise = loadTemplateFromSource( source, engine );
			surprise.handle(function(outcome) switch outcome {
				case Success(tpl) if (tpl!=null): allPartialTemplates[name] = tpl;
				case Success(_): partialErrors[name] = HttpError.internalServerError('Partial $name must be either TFromString or TFromEngine, was $source');
				case Failure(err): partialErrors[name] = err;
			});
			allPartialFutures.push( surprise );
		}
		return Future.ofMany( allPartialFutures ).map(function(_) {
			var numberOfErrors = Lambda.count(partialErrors);
			return switch numberOfErrors {
				case 0: Success( allPartialTemplates );
				case 1:
					var err = [for (e in partialErrors) e][0];
					Failure( err );
				case _:
					var partialNames = [for (name in partialErrors.keys()) name];
					error( 'Partials $partialNames failed to load: $partialErrors', partialErrors );
			}
		});
	}

	/**
	Create helpers for each partial.
	Add them to the helpers map as we go so they're available to other partials.
	**/
	static function addHelpersForPartials( partialTemplates:Map<String,UFTemplate>, contextData:TemplateData, contextHelpers:Map<String,TemplateHelper> ) {
		for ( name in partialTemplates.keys() ) {
			var partial = partialTemplates[name];
			var partialFn = function( partialData:TemplateData ):String {
				// Each partial can take one object as an argument: this will be added to the TemplateData used to process the partial.
				var combinedPartialData = new TemplateData();
				combinedPartialData.setObject( contextData );
				combinedPartialData.setObject( partialData );
				combinedPartialData.set( "__current__", partialData );
				return executeTemplate( 'Partial[$name]', Success(partial), combinedPartialData, contextHelpers ).sure();
			}
			contextHelpers[name] = partialFn;
		}
	}

	static function executeTemplate( section:String, tplOutcome:Outcome<Null<UFTemplate>,Error>, combinedData:TemplateData, combinedHelpers:Map<String,TemplateHelper> ):Outcome<String,Error> {
		switch tplOutcome {
			case Success( tpl ):
				try return Success( tpl.execute(combinedData,combinedHelpers) )
				catch (e:Dynamic) {
					#if debug
						trace( haxe.CallStack.toString(haxe.CallStack.exceptionStack()) );
					#end
					return error( 'Unable to execute $section template: $e', e );
				}
			case Failure( err ):
				return error( 'Unable to load $section template: $err', err );
		}
	}

	static function error<T>( reason:String, data:Dynamic, ?pos ):Outcome<T,Error> {
		return Failure( HttpError.internalServerError(reason,data,pos) );
	}
}

enum TemplateSource {
	TFromString( str:String, ?templatingEngine:TemplatingEngine );
	TFromEngine( path:String, ?templatingEngine:TemplatingEngine );
	TNone;
	TUnknown;
}
