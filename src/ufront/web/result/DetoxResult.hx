package ufront.web.result;

#if detox
	import tink.CoreApi;
	import thx.error.NullArgument;
	import ufront.web.context.ActionContext;
	import ufront.core.AsyncTools;
	import ufront.view.TemplateData;
	import ufront.core.AcceptEither;
	import dtx.widget.Widget;
	import dtx.layout.IDetoxLayout;
	import dtx.DOMCollection;
	using Detox;

	/**
	A DetoxResult is an ActionResult that uses a `dtx.DOMCollection` for it's layout, and applies various template data to it using `widget.mapData` (which itself uses `Reflect.setProperty`).

	Once ufront supports client-side apps, the intention is for a DetoxResult to share a layout between requests, just replacing the data in the layout, for smooth one-page apps.

	Currently only server side interaction is supported - it creates the layout, and then populates it with the data.

	Please note that providing the `data` parameter will use Reflection to set the properties on your layout, and so type safety is not guaranteed.
	You can access `layout` to get a typed layout to set your properties on directly for maximum safety.

	```
	// Inline, use TemplateData, not type checked.
	return new DetoxResult( StaffLayout, { title: "Welcome!", view: myViewWidget } );

	// Or, fully type checked
	var layout = new StaffLayout();
	layout.title = "Welcome!";
	layout.view = myViewWidget;
	return new DetoxResult( layout );
	```
	**/
	class DetoxResult<W:Widget> extends ActionResult {

		/** The default HTTP content type to use for responses if none is specified. Default value is `text/html`. **/
		public static var defaultContentType = "text/html";

		/** The default DOCTYPE to print for responses if none is specified. Default value is `<!DOCTYPE html>`. **/
		public static var defaultDocType = "<!DOCTYPE html>";

		/** The layout class used for the current request. Readonly. **/
		public var layoutClass(default,null):Class<W>;

		/** The layout used for the current request. This is either set from the constructor, or instantiated during `this.executeResult()` using the context injector. Readonly. **/
		public var layout(default,null):W;

		/**
		The template data to apply to the layout.
		This is initialized in the constructor.
		If no data is provided, an empty TemplateData collection will be created.

		For type safe access consider setting properties of `layout` directly.
		Each piece of data will be applied using `Reflect.setProperty(layout,key,value)`.

		The data will be applied to the layout during `this.executeResult`.

		Readonly.
		**/
		public var data(default,null):TemplateData;

		/** The HTTP content type to use for this request. If not specified before `executeResult()` is called, then it will be set to `DetoxResult.defaultContentType`. **/
		public var contentType:String;

		/** The DOCTYPE to use for this request. If not specified before `executeResult()` is called, then it will be set to `DetoxResult.defaultDocType`. **/
		public var docType:String;

		/**
		Create a new DetoxResult with the specified layout.

		@param layoutToUse Either a widget that is ready to use, or the class of widget to create. The class must be able to be instantiated via dependency injection. It will be constructed during `this.executeResult()`.
		@param (optional) contentType An initial value for `contentType`.
		@param (optional) docType An initial value for `contentType`.
		@param (optional) data Any initial data to be set on the widget. These will not be applied until `executeResult` is called. If not supplied, an empty TemplateData collection will be created.
		**/
		public function new( layoutToUse:AcceptEither<W,Class<W>>, ?contentType:String, ?docType:String, ?data:TemplateData ) {
			switch layoutToUse.type {
				case Left(l):
					this.layout = l;
					this.layoutClass = Type.getClass( l );
				case Right(cl):
					this.layoutClass = cl;
			}
			this.data = ( data!=null ) ? data : {};
			this.contentType = contentType;
			this.docType = docType;
		}

		/**
		Execute the result.  This will:

		- Instantiate the layout using dependency injection is a layout class rather than a layout object was supplied.
		- Apply the template data to the layout using `layout.mapData()`.
		- Set the HttpResponse content type using either the provided `contentType` or the `defaultContentType`.
		- Write the doctype to the HttpResponse using either the provided `docType` or the `defaultDocType`.
		- Write the html to the output using `layout.html()`.

		This method executes synchronously.
		**/
		override function executeResult( actionContext:ActionContext ) {
			if ( layout==null ) {
				layout = actionContext.httpContext.injector.instantiate( layoutClass );
			}
			layout.mapData( data );

			var dt = (docType!=null) ? docType : defaultDocType;
			actionContext.httpContext.response.contentType = (contentType!=null) ? contentType : defaultContentType;
			actionContext.httpContext.response.write( dt + layout.html() );

			return SurpriseTools.success();
		}
	}
#end
