package ufront.web.result;

#if macro
	import haxe.macro.Expr;
#end
import haxe.PosInfos;
import ufront.view.TemplateData;
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
using thx.Strings;
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

__What about file extensions__

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
	Global values that should be made available to every view result.
	**/
	public static var globalValues:TemplateData = {};

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
	public var helpers:TemplateData;

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
		this.helpers = {};
		this.templateSource = (viewPath!=null) ? FromEngine(viewPath,templatingEngine) : Unknown;
		this.layoutSource = Unknown;
		this.finalOutputTrigger = Future.trigger();
		this.finalOutput = finalOutputTrigger;
	}

	/**
	Specify a layout to wrap this view.

	@param layoutPath
	@param templatingEngine (optional) A templating engine to use with this layout. If none is specified, the first templating engine matching the layoutPath's extension will be used.
	**/
	public function withLayout( layoutPath:String, ?templatingEngine:TemplatingEngine ):ViewResult {
		this.layoutSource = FromEngine( layoutPath, templatingEngine );
		return this;
	}

	/** Prevent a default layout from wrapping this view - this view will appear standalone, not wrapped by a layout. **/
	public function withoutLayout():ViewResult {
		this.layoutSource = None;
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
			this.templateSource = FromString( template, templatingEngine );

		if (layout!=null)
			this.layoutSource = FromString( layout, templatingEngine );

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

	/**
	Execute the given view, wrap it in a layout, and write it to the response.

	In detail:

	- Figure out which template and which layout to use. (See the documentation at the top of this class for more details.)
	- Load the template and layout.
	- Once loaded, execute the view template with all of our data (a combination of `globalValues`, `helpers` and `data`).
	- If a layout is used, execute the layout with the same data, inserting our view into the `viewContent` variable of the layout.
	- Write the final output to the `ufront.web.context.HttpResponse` with a `text/html` content type.
	**/
	override function executeResult( actionContext:ActionContext ) {

		if ( layoutSource.match(Unknown) )
			layoutSource = inferLayoutFromContext( actionContext );
		if ( templateSource.match(Unknown) )
			templateSource = inferViewPathFromContext( actionContext );

		var viewFolder = getViewFolder( actionContext );
		templateSource = addViewFolderToPath( templateSource, viewFolder );
		layoutSource = addViewFolderToPath( layoutSource, viewFolder );

		// Get the viewEngine from the injector.
		var viewEngine =
			try actionContext.httpContext.injector.getInstance( UFViewEngine )
			catch (e:Dynamic) {
				var msg = "Failed to find a UFViewEngine in ViewResult.executeResult(), please make sure that one is made available in your application's injector";
				return SurpriseTools.asSurpriseError( null, msg );
			};

		// Begin to load the templates (as Futures).
		var templateReady = loadTemplateFromSource( templateSource, viewEngine );
		var layoutReady = loadTemplateFromSource( layoutSource, viewEngine );


		return FutureTools
			.when( templateReady, layoutReady )
			.map(function( viewTemplate:Outcome<Null<UFTemplate>,Error>, layoutTemplate:Outcome<Null<UFTemplate>,Error> ) {
				var combinedData = getCombinedData( [globalValues,helpers,data], actionContext );
				try {
					// Execute the view, and then the layout (inserting the `viewContent`).
					var viewOut = executeTemplate( "view", viewTemplate, combinedData ).sure();
					var finalOut =
						if ( layoutTemplate.match(Success(null)) ) viewOut
						else executeTemplate( "layout", layoutTemplate, combinedData.set('viewContent',viewOut) ).sure();

					// Write to the response
					actionContext.httpContext.response.contentType = "text/html";
					actionContext.httpContext.response.write( finalOut );
					this.finalOutputTrigger.trigger( finalOut );

					return Success( Noise );
				}
				catch (e:Error) return Failure( e );
			});
	}

	static function getCombinedData( dataSets:Array<TemplateData>, actionContext:ActionContext ):TemplateData {
		var combinedData = TemplateData.fromMany( dataSets );
		var controller = Std.instance( actionContext.controller, Controller );
		if ( controller!=null && combinedData.exists('baseUri')==false )
			combinedData.set( 'baseUri', controller.baseUri );
		return combinedData;
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

		return FromEngine( viewPath, null );
	}

	static function inferLayoutFromContext( actionContext:ActionContext ):TemplateSource {
		var layoutPath:String = null;

		// Check for @layout("...") metadata that specifies the layout on the controller.
		var controllerCls = Type.getClass( actionContext.controller );
		var classMeta = Meta.getType( controllerCls );
		if ( classMeta.layout!=null && classMeta.layout.length>0 ) {
			layoutPath = ""+classMeta.layout[0];
		}
		else {
			// If there was no metadata, see if a "defaultLayout" string was injected by the app configuration.
			try {
				layoutPath = actionContext.httpContext.injector.getInstance( String, "defaultLayout" );
				if ( layoutPath.startsWith("/")==false ) {
					layoutPath = '/$layoutPath';
				}
			} catch (e:Dynamic) {}
		}

		return (layoutPath!=null) ? FromEngine(layoutPath,null) : None;
	}

	static function addViewFolderToPath( layoutSource:TemplateSource, viewFolder:String ):TemplateSource {
		return switch layoutSource {
			case FromEngine(path,engine):
				// Usually, a view will go inside a viewFolder - for example all views in HomeController will go inside `/$viewDir/home/`.
				// If a viewPath begins with a leading slash though, it is treated as "absolute", or at least, relative to the global viewDirectory, not the controller's viewFolder.
				// So if it is "absolute", drop the leading slash because it's only absolute relative to the viewDirectory.
				// If it does not begin with a leading slash, prepend the viewFolder.
				path = path.startsWith("/") ? path.substr(1) : '$viewFolder/$path';
				FromEngine( path, engine );
			case _: layoutSource;
		}
	}

	static function loadTemplateFromSource( source:TemplateSource, engine:UFViewEngine ):Surprise<Null<UFTemplate>,Error> {
		return switch source {
			case FromString(str,templatingEngine):
				try Future.sync( Success(templatingEngine.factory(str)) )
				catch (e:Dynamic) {
					var engine = 'Templating Engine: "${templatingEngine.type}"';
					var template = 'String template: "${str}"';
					Future.sync( error('Failed to parse template.','$engine\n$template') );
				}
			case FromEngine(path,templatingEngine): engine.getTemplate( path, templatingEngine );
			case None, Unknown: Future.sync( Success(null) );
		}
	}

	static function executeTemplate( section:String, tplOutcome:Outcome<Null<UFTemplate>,Error>, combinedData:TemplateData ):Outcome<String,Error> {
		switch tplOutcome {
			case Success( tpl ):
				try return Success( tpl.execute(combinedData) )
				catch (e:Dynamic) return error( 'Unable to execute $section template', e );
			case Failure( err ):
				return error( 'Unable to load $section template', err );
		}
	}

	static function error<T>( reason:String, data:Dynamic, ?pos ):Outcome<T,Error> {
		return Failure( HttpError.internalServerError(reason,data,pos) );
	}
}

enum TemplateSource {
	FromString( str:String, ?templatingEngine:TemplatingEngine );
	FromEngine( path:String, ?templatingEngine:TemplatingEngine );
	None;
	Unknown;
}
