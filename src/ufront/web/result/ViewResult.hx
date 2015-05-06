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
import ufront.core.Sync;
import haxe.rtti.Meta;
using tink.CoreApi;
using thx.core.Strings;
using haxe.io.Path;
using StringTools;

/**
A ViewResult loads a view from a templating engine, optionally wraps it in a layout, and writes the result to the HttpResponse with a `text/html` content type.

### Choosing a view

There's a fair bit of magic to how ufront chooses a template for the ViewResult.

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

If you visit `/dashboard/`, it is going to use a template at "/view/admin/dashboard.html" by default.
If you visit `/camera/`, it is going to use a template at "/view/admin/takePhoto.html" by default.

__How does it know to look there?__

1. "/view/" is your viewPath, set in `UfrontConfiguration.viewPath`
2. "admin/" is guessed based on the name "AdminController".  We lower-case the first letter, and ignore the "Controller" part of the name.  Another example is "BlogPostController" or just "BlogPost" looking for views in "/blogPost/".
3. "dashboard.html" and "takePhoto.html" are guessed based on the action name / method name.  If the name begins with "do" followed by an uppercase letter, we ignore the "do" letters.  We also make sure the first letter is lower-case.

__How do we change it?__

Well you can use metadata.

To change the default folder that views in this controller are found in, use the `@viewFolder` metadata:

```haxe
@viewFolder("/admin-templates/")
class AdminController extends Controller {
	...
}
```

You can also set a default layout for every action on the controller:

```haxe
@viewFolder("/admin-templates/")
@layout("layout.html") // Will look in `view/admin-templates/layout.html`
// By contrast, `@layout("/layout.html")` will look in "/view/layout.html" - notice the leading slash.
class AdminController extends Controller {
	...
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
		Global values that should be made available to every view result.
	**/
	public static var globalValues:TemplateData = {};

	//
	// Member Variables
	//

	/**
		The path to the view.

		If not specified when `executeResult` is called, it will be inferred from the Http Context.
		If an extension is not specified, any extensions that match the given templating engines will be used.
		See `executeResult` for details on this selection process.
	**/
	public var viewPath:Null<String>;

	/**
		A specific templating engine to use for this request.
		This is helpful if you have views with file extensions shared by more than one view engine (eg: *.html).
		Specifying an engine explicitly when a viewPath has been set will force that view to be rendered with a specific engine.
		Specifying an engine when no view path is set, or a view path without an extension, will search for views with an extension matching thos supported by this templating engine.
	**/
	public var templatingEngine:Null<TemplatingEngine>;

	/**
		The data to pass to the template during `executeResult`.
		This will be combined with the `helpers` and `globalData` before being passed to the templates `execute` function.
		This is set during the constructor, and you can add to it using the `setVar` and `setVars` helper methods.
	**/
	public var data:TemplateData;

	/**
		The layout to wrap around this view.

		A layout is another `ufront.view.UFTemplate` which takes the parameter "viewContent".
		The result of the current view will be inserted into the "viewContent" field of the layout.

		All of the same data mappings and helpers will be available to the layout when it renders.

		If no layout is specified, then we will see if there is a default one for the application.
		(You can set a default layout for a `UfrontApplication` using the `UfrontConfiguration.defaultLayout` configuration property).

		If you call `viewResult.withoutLayout()` then no layout will wrap the current view, even if a default layout is specified.
	**/
	public var layout:Null<Option<Pair<String,TemplatingEngine>>>;

	/**
		Any helpers (dynamic functions) to pass to the template when it is executed.
	**/
	public var helpers:TemplateData;
	
	/** An explicit string to use as the template, rather than loading the template through our UFViewEngine. **/
	var templateFromString:UFTemplate;
	/** An explicit string to use as the layout template, rather than loading the layout through our UFViewEngine. **/
	var layoutFromString:UFTemplate;

	// TODO: refactor execute to use these values instead of a mix of viewPath, templateFromString, layoutFromString, layout etc.
	public var templateSource(default,null):TemplateSource;
	public var layoutSource(default,null):TemplateSource;
	public var finalOutput(default,null):String;

	//
	// Member Functions
	//

	/**
		Create a new ViewResult, with the specified data.

		You can optionally specify a custom `viewPath` or a specific `templatingEngine`.

		If `viewPath` is not specified, the `actionContext` will be used to choose a view during `executeResult`.
		See the documentation on `executeResult` for details.
	**/
	public function new( ?data:TemplateData, ?viewPath:String, ?templatingEngine:TemplatingEngine ) {
		this.viewPath = viewPath;
		this.templatingEngine = templatingEngine;
		this.data = (data!=null) ? data : {};
		this.helpers = {};
		this.layout = null;
	}

	/**
		Specify a layout to wrap this view.

		@param layoutPath
		@param ?templatingEngine A templating engine to use with this layout. If none is specified, the first templating engine matching the layoutPath's extension will be used. (If layoutPath is not specified, this parameter will have no effect).
	**/
	public function withLayout( layoutPath:String, ?templatingEngine:TemplatingEngine ):ViewResult {
		this.layout = Some( new Pair(layoutPath, templatingEngine) );
		return this;
	}

	/**
		Prevent a default layout from wrapping this view - this view will appear unwrapped.
	**/
	public function withoutLayout():ViewResult {
		this.layout = None;
		return this;
	}
	
	/**
		Use a static string as the templates, rather than loading from a UFViewEngine.

		If `template` or `layout` is not supplied or null, the usual rules will apply for loading a view using the UFViewEngine.
		
		@param template The template string for the main view template.
		@param layout The template string for the layout.
		@param templatingEngine The templating engine to render the given templates with.
		@return ViewResult (to allow method chaining).
	**/
	public function usingTemplateString( template:String, ?layout:String, ?templatingEngine:TemplatingEngine ):ViewResult {
		if (templatingEngine==null)
			templatingEngine = TemplatingEngines.haxe;
		
			if (template!=null) {
				this.templateFromString = templatingEngine.factory( template );
				this.templateSource = FromString( template );
			}
			else this.templateFromString = null;
		
			if (layout!=null) {
				this.layoutFromString = templatingEngine.factory( layout );
				this.layoutSource = FromString( layout );
			}
			else this.layoutFromString = null;
		
		return this;
	}

	/** Add a key=>value pair to our TemplateData **/
	public function setVar( key:String, val:Dynamic ):ViewResult {
		this.data[key] = val;
		return this;
	}

	/** Add an object or map with key=>value pairs to our TemplateData **/
	public function setVars( ?map:Map<String,Dynamic>, ?obj:{} ):ViewResult {
		if (obj!=null) this.data.setObject( obj );
		if (map!=null) this.data.setMap( map );
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
		return internalExecuteResult(actionContext);
	}
	
	private function internalExecuteResult( actionContext:ActionContext ) {
		// Get the viewEngine
		var viewEngine = try actionContext.httpContext.injector.getInstance( UFViewEngine ) catch (e:Dynamic) null;
		if (viewEngine==null) return Sync.httpError( "Failed to find a UFViewEngine in ViewResult.executeResult(), please make sure that one is made available in your application's injector" );

		// Combine the data and the helpers
		var combinedData = TemplateData.fromMany( [globalValues, helpers, data] );
		var controller = Std.instance( actionContext.controller, Controller );
		if ( controller!=null && combinedData.exists('baseUri')==false )
			combinedData.set( 'baseUri', controller.baseUri );

		// Get the view folder, either from @viewFolder("...") meta or from the controller name.
		var controllerCls = Type.getClass( actionContext.controller );
		var viewFolderMeta = Meta.getType( controllerCls ).viewFolder;
		var viewFolder:String;
		if ( viewFolderMeta!=null && viewFolderMeta.length>0 ) {
			viewFolder = ""+viewFolderMeta[0];
			viewFolder = viewFolder.removeTrailingSlashes();
		}
		else {
			// Get the class name
			var controllerName = Type.getClassName( Type.getClass(actionContext.controller) ).split( "." ).pop();
			// Lowercase the first letter
			controllerName = controllerName.charAt(0).toLowerCase() + controllerName.substr(1);
			// Strip off the word Controller
			if ( controllerName.endsWith("Controller") )
				controllerName = controllerName.substr( 0, controllerName.length-10 );
			viewFolder = controllerName;
		}

		// Get the view path
		if ( viewPath==null ) {
			// Was the viewPath specified by @template("...") metadata on the action method?
			var fieldsMeta = Meta.getFields( controllerCls );
			var actionFieldMeta:Dynamic<Array<Dynamic>> = Reflect.field( fieldsMeta, actionContext.action );
			if ( actionFieldMeta!=null && actionFieldMeta.template!=null && actionFieldMeta.template.length>0 ) {
				viewPath = ""+actionFieldMeta.template[0];
			}
		}
		if ( viewPath==null ) {
			// Otherwise, if viewPath is still null, use the action name to guess a reasonable template.
			var action = actionContext.action;
			var startsWithDo = action.startsWith("do");
			var thirdCharUpperCase = action.charAt(2)==action.charAt(2).toUpperCase();
			if ( startsWithDo && thirdCharUpperCase )
				action = action.substr(2);
			viewPath = action.charAt(0).toLowerCase() + action.substr(1);
		}

		// Figure out which layout to use.
		var layoutPath:String = null;
		if ( layout==null ) {
			// See if there is a controller-wide defaultLayout set in the controller's @layout("...") metadata.
			var classMeta = Meta.getType( controllerCls );
			if ( classMeta.layout!=null && classMeta.layout.length>0 ) {
				layoutPath = ""+classMeta.layout[0];
			}
		}
		if ( layout==null && layoutPath==null ) {
			// See if there is a site-wide defaultLayout set in the dependency injector.
			try {
				layoutPath = actionContext.httpContext.injector.getInstance( String, "defaultLayout" );
				if ( layoutPath.startsWith("/")==false ) {
					layoutPath = '/$layoutPath';
				}
			} catch (e:Dynamic) {}
		}
		
		// If a viewPath (or layoutPath) has a leading slash, it does not go inside our view folder.
		// So if it is "absolute", drop the leading slash because it's only absolute relative to the view folder.
		// And if not, append it to the viewFolder.
		viewPath = viewPath.startsWith("/") ? viewPath.substr(1) : '$viewFolder/$viewPath';
		layoutPath = (layoutPath!=null && layoutPath.startsWith("/")) ? layoutPath.substr(1) : '$viewFolder/$layoutPath';

		// Get the layout future
		var layoutReady:Surprise<Null<UFTemplate>,Error>;
		if ( layoutFromString!=null ) {
			layoutReady = Future.sync( Success(layoutFromString) );
		}
		else {
			if ( layout==null )
				layout = (layoutPath!=null) ? Some(new Pair(layoutPath,null)) : None;

			switch layout {
				case Some( layoutData ):
					layoutSource = FromEngine( layoutData.a );
					layoutReady = viewEngine.getTemplate( layoutData.a, layoutData.b );
				case None, null:
					layoutSource = None;
					layoutReady = Future.sync( Success(null) );
			}
		}

		// Get the template future
		var templateReady:Surprise<UFTemplate,Error>;
		if ( templateFromString!=null ) {
			templateReady = Future.sync( Success(templateFromString) );
		}
		else {
			templateSource = FromEngine( viewPath );
			templateReady = viewEngine.getTemplate( viewPath, templatingEngine );
		}

		// Once both futures have loaded, combine them, and then map them, executing the future templates
		// and writing them to the output, and then completing the Future once done, or returning a Failure
		// if there was an error.
		var done =
			(templateReady && layoutReady) >>
			function ( pair:Pair<Outcome<UFTemplate,Error>, Outcome<Null<UFTemplate>,Error>> ) {

				var template:UFTemplate = null;
				var layout:Null<UFTemplate> = null;

				// Extract template
				switch pair.a {
					case Success( tpl ): template = tpl;
					case Failure( err ): return error( "Unable to load view template", err );
				}

				// Extract layout, possibly null
				switch pair.b {
					case Success( tpl ): layout = tpl;
					case Failure( err ): return error( "Unable to load layout template", err );
				}

				// Try execute the template
				var viewOut:String = null;
				try
					viewOut = template.execute( combinedData )
				catch ( e:Dynamic )
					return error( "Unable to execute view template", e );

				// Try execute the layout around the view, if there is a layout.  Otherwise just use the view.
				var finalOut:String = null;
				if ( layout==null ) {
					finalOut = viewOut;
				}
				else {
					combinedData.set( "viewContent", viewOut );
					try
						finalOut = layout.execute( combinedData )
					catch
						( e:Dynamic ) return error( "Unable to execute layout template", e );
				}

				// Write to the response
				actionContext.httpContext.response.contentType = "text/html";
				actionContext.httpContext.response.write( finalOut );
				this.finalOutput = finalOut;

				return Success( Noise );
			}

		return done;
	}

	function error( reason:String, data:Dynamic, ?pos:haxe.PosInfos ) {
		return Failure( HttpError.internalServerError(reason,data,pos) );
	}
}

enum TemplateSource {
	FromString( str:String );
	FromEngine( path:String );
	None;
}
