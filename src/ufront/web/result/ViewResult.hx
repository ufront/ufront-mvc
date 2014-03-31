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
	ViewResult

	- TODO - document properly, there is a fair bit to notice here
**/
class ViewResult extends ActionResult {

	//
	// Statics
	//

	public static var globalValues:TemplateData = {};

	//
	// Macros
	//

	/**
		A shortcut to `new ViewResult()`.  

		At some point in the future it may be replaced with a macro used to verify that the template exists and is parsable.

		For now it has no effect different to the normal constructor.
	**/
	public static function create( ?data:TemplateData, ?viewPath:String, ?templatingEngine:TemplatingEngine, ?pos:PosInfos ):ViewResult {
		return new ViewResult( data, viewPath, templatingEngine, pos );
	}
	
	// public macro function check():Expr {
	// 	return macro null;
	// }

	//
	// Member Variables
	//

	public var viewPath:String;
	public var templatingEngine:TemplatingEngine;
	public var data:TemplateData;
	public var layout:Null<Option<Pair<String,TemplatingEngine>>>;
	public var helpers:TemplateData;
	
	//
	// Member Functions
	//

	/**
		Create a new ViewResult, with the specified data. 

		You can optionally specify a custom `viewPath` or a specific `templatingEngine`.

		If `viewPath` is not specified, the call site of this constructor will be used to infer the `viewPath`.
		This will usually be the action on one of your controllers which calls `new ViewResult`.
		For example if you are in a controller called `PostsController` and you are in an action called `viewPost`, the inferred `viewPath` will be `posts/viewPost`.
		This will match a template with that path, using whichever extension your templating engines support, and using the first template to match.
		
		Some small transformations: 

		- On the controller:
			- The package is discarded, only the section after the final "." is kept
			- The first letter of your controller name will be made lowercase. 
			- If your controller name ends with "Controller", it will not be included in the view.
		- On the action:
 			- If the action name begins with "do", it will be removed
			- The first letter of your action name will be made lowercase.
	**/
	public function new( ?data:TemplateData, ?viewPath:String, ?templatingEngine:TemplatingEngine, ?pos:PosInfos ) {
		
		this.viewPath = viewPath;
		this.templatingEngine = templatingEngine;
		this.data = (data!=null) ? data : {};
		this.helpers = {};
		this.layout = null;

		if ( viewPath==null ) {
			var ct = pos.className.split(".").pop().lcfirst();
			if ( ct.endsWith("Controller") ) 
				ct = ct.substr( 0, ct.length-10 );
			var action = pos.methodName.startsWith("do") ? pos.methodName.substr(2).lcfirst() : pos.methodName.lcfirst();
			this.viewPath = '$ct/$action';
		}
	}

	/**
		Specify a layout to wrap this view.

		A layout is another `ufront.view.UFTemplate` which takes the parameter "viewContent".  The result of the current view will be inserted into the "viewContent" field of the layout.

		All of the same data mappings and helpers will be available to the layout when it renders.

		If no layout is specified, a default layout is looked for using the application's injector.  If not default layout is found, the view is not wrapped.

		If you call `viewResult.withoutLayout()` then no layout will wrap the current view, even if a default layout is specified.
		
		Default layouts can be set through the `ufront.app.HttpApplication.injector`.
		You must map a `String` with id "defaultLayout" which holds the path to the default layout.
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

	/** Add a key=>value pair to our TemplateData **/
	public function setVars( ?obj:{}, ?map:Map<String,Dynamic> ):ViewResult {
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
	**/
	override function executeResult( actionContext:ActionContext ) {
		
		// Get the viewEngine
		var viewEngine = try actionContext.httpContext.injector.getInstance( UFViewEngine ) catch (e:Dynamic) null;
		if (viewEngine==null) return Sync.httpError( "Failed to find a UFViewEngine in ViewResult.executeResult(), please make sure that one is made available in your application's injector" );

		// Combine the data and the helpers
		var combinedData = TemplateData.fromMany( [globalHelpers, helpers, data] );

		// Get the layout future
		var layoutReady:Surprise<Null<UFTemplate>,Error>;
		if ( layout==null ) {
			var layoutPath = try actionContext.httpContext.injector.getInstance( String, "defaultLayout" ) catch (e:Dynamic) null;
			layout = Some( new Pair(layoutPath,null) );
		}
		if ( layout!=null ) {
			layoutReady = switch layout {
				case Some( layoutData ): viewEngine.getTemplate( layoutData.a, layoutData.b );
				case None: Future.sync( Success(null) );
			}
		}
		else layoutReady = Future.sync( Success(null) );

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
				actionContext.response.contentType = "text/html";
				actionContext.response.write( finalOut );

				return Success( Noise );
			}
		
		return done;
	}

	function error( reason:String, data:Dynamic ) {
		return Failure( HttpError.internalServerError(reason,data) );
	}
}