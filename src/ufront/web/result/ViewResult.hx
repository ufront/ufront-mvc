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
import ufront.web.context.ActionContext;
import ufront.core.Sync;
using tink.CoreApi;
using Strings;

/**
	A ViewResult loads a view from a templating engine, optionally wraps it in a layout, and writes the result to the HttpResponse with a `text/html` content type.

	### Choosing a view

	When a ViewResult is created you can optionally set a viewPath.

	If you don't set a viewPath, it will be inferred from the context.

	For example, if you are in the controller "HomeController" and the action "doIndex()", it will look for a view called "home/index.*" in your view directory.

	There is some small magic here - the word "Controller" is dropped from the end of the controller name.
	The "do" prefix is dropped from the start of the action name.
	The first letter is made lower case if it isn't already.
	It will also match a template with any extension supported by the templating engines.

	If a viewPath is specified, a view will be loaded from that path.
	If the viewPath does not include an extension, any view matching one of the extensions supported by our templating engines will be used.
	You can optionally specify a TemplatingEngine to use also.
	See `UFViewEngine.getTemplate()` for a detailed description of how a template is chosen.

	### Setting data

	When you create the view, you can specify some data to execute the template with:

	```haxe
	ViewResult.create({ name: "jason", age: 26 });
	```

	You can add to this data using `setVar` and `setVars`.

	You can also specify some global data that will always be included for your app:

	```
	ViewResult.globalValues["copyright"] = "&copy; 2014 Haxe Foundation, all rights reserved.";
	```

	Helpers (dynamic functions) can be included in your ViewResult also.

	### Wrapping your view with a layout

	Usually you will want to wrap your view for a specific page or action with a layout that has the branding of your site.

	A layout is another `ufront.view.UFTemplate` which takes the parameter "viewContent".
	The result of the current view will be inserted into the "viewContent" field of the layout.
	All of the same data mappings and helpers will be available to the layout when it renders.

	You can set a default layout to be used with all ViewResults using the static method `setDefaultLayout()`.
	You can se a layout for an individual result using `withLayout()`.
	Finally you can choose not to use a layout, even if a default is specified, by using `withoutLayout()`

	### Where does it get the views from?

	Short answer: by default, it gets them from the filesystem in the "view/" folder relative to the script directory.

	Ufront supports different view engines. (See `ufront.view.UFViewEngine`).
	For example, you could have a view engine that loads templates from a database, rather than from the FileSystem.

	ViewResult will use dependency injection to get the correct UFViewEngine it should be using.
	You can set this by setting `viewEngine` on your `ufront.web.UfrontConfiguration` when you start your ufront app.
	By default, it is configured to use the `ufront.view.FileViewEngine`, loading views from the "view/" directory relative to your script directory (www/).

	### What if I want a different templating engine?

	We use a `UFViewEngine` to load our templates, and these support multiple templating engines.
	You can view some available engines in `ufront.view.TemplatingEngines`, and it will be fairly easy to create a new templating engine if needed.
	You can use `ufront.app.UfrontApplication.addTemplatingEngine()` to add a new engine, which will then be available to your view results.
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
	// Macros
	//

	/**
		A shortcut to `new ViewResult()`.

		At some point in the future this may be replaced with a macro used to verify that the template exists and is parsable.

		For now this has no effect different to the normal constructor.
	**/
	public static function create( ?data:TemplateData, ?viewPath:String, ?templatingEngine:TemplatingEngine ):ViewResult {
		return new ViewResult( data, viewPath, templatingEngine );
	}

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
		Execute the given view (and layout, if applicable), writing to the response.

		- Load the selected view template, and if applicable, the view layout or default view layout.
		- Once loaded, execute the view template with our given data
		- If a layout is used, execute the layout with the same data, inserting our view into the `viewContent` variable of the layout
		- Write the final output to the `ufront.web.context.HttpResponse`

		If `viewPath` was not specified or was null, we will infer the viewPath from the actionContext.
		The following rules apply:

		- If `viewPath` was not specified or is null, the `actionContext` will be used to determine a view based on the controller / action used for the request.
		- For example if you are in a controller called `PostsController` and you are in an action called `viewPost`, the inferred `viewPath` will be `posts/viewPost`.
		- This will match a template with that path, using whichever extension your templating engines support, and using the first template to match, for example `post/viewPost.html`.

		Some small transformations that occur while inferring the view path:

		__On the controller:__

		- The package is discarded, only the section after the final "." is kept
		- The first letter of your controller name will be made lowercase.
		- If your controller name ends with "Controller", it will not be included in the view.

		__On the action:__:

 		- If the action name begins with "do", it will be removed
		- The first letter of your action name will be made lowercase.

		The data passed to the template will be the combination of `globalValues`, `helpers` and `data`, with the latter taking precedence over the former.

		The result of executing the template will be written to the response, with a content type of "text/html".
	**/
	override function executeResult( actionContext:ActionContext ) {

		// Get the viewEngine
		var viewEngine = try actionContext.httpContext.injector.getInstance( UFViewEngine ) catch (e:Dynamic) null;
		if (viewEngine==null) return Sync.httpError( "Failed to find a UFViewEngine in ViewResult.executeResult(), please make sure that one is made available in your application's injector" );

		// Combine the data and the helpers
		var combinedData = TemplateData.fromMany( [globalValues, helpers, data] );

		// Figure out the viewPath if it was not supplied.
		if ( viewPath==null ) {
			var controller = Type.getClassName( Type.getClass(actionContext.controller) ).split( "." ).pop().lcfirst();
			if ( controller.endsWith("Controller") )
				controller = controller.substr( 0, controller.length-10 );
			var action = actionContext.action;
			if ( action.startsWith("do") )
				action = action.substr(2);
			action = action.lcfirst();
			viewPath = '$controller/$action';
		}

		// Get the layout future
		var layoutReady:Surprise<Null<UFTemplate>,Error>;
		if ( layout==null ) {
			// See if there is a default layout.
			layout =
				try {
					var defaultLayoutPath = actionContext.httpContext.injector.getInstance( String, "defaultLayout" );
					Some( new Pair(defaultLayoutPath,null) );
				}
				catch (e:Dynamic) None;
		}
		layoutReady = switch layout {
			case Some( layoutData ): viewEngine.getTemplate( layoutData.a, layoutData.b );
			default: Future.sync( Success(null) );
		}

		// Get the template future
		var templateReady = viewEngine.getTemplate( viewPath, templatingEngine );

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

				return Success( Noise );
			}

		return done;
	}

	function error( reason:String, data:Dynamic ) {
		return Failure( HttpError.internalServerError(reason,data) );
	}
}
