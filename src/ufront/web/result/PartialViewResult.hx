package ufront.web.result;

#if client
	import ufront.view.TemplateData;
	import ufront.view.TemplatingEngines;
	import ufront.web.context.ActionContext;
	import js.ufront.web.context.HttpResponse.replaceChildren;
	import js.Browser.*;
	import js.html.*;
#end

/**
A PartialViewResult is similar to a `ViewResult`, but on the client side it checks checks for partial sections of the view to update, rather than reloading the entire DOM.

On the server side, this performs identically to ViewResult.

On the client side, this will:

- Pick the relevant view and layout in the same way as ViewResult.
- Execute the layout and the template to get a full HTML response.
- Check the body for a `data-layout` attribute. If the attribute has changed with the new request, then the entire body will be replaced.
- Otherwise, check for elements with a `data-partial` attribute, and replace the old children of each partial element with the new children.

### Example

Imagine this template:

```html
<html>
<body data-layout="site-page">
    <div class="container" />
        <div class="row">
            <div class="col-md-3">
                <ul data-partial="nav">
                    ::for (link in navItems)::
                        <li>::link::</li>
                    ::end::
                </ul>
            </div>
            <div class="col-md-9" data-partial="content">
                ::content::
            </div>
        </div>
    </div>
</body>
</html>
```

When this is executed server-side, it will render the view and the layout as per normal.
When it is executed client-side, it will execute the view and the layout, but only replace the DOM nodes inside the navigation `ul[data-partial=nav]` and the `div[data-partial=content]`.

If the template and layout that is rendered has a different `body[data-layout]` attribute, then the entire view will be re-rendered.

If some of the partial sections in the old body are not in the new body, the sections in the old body will be emptied.
If some of the partial sections in the new body are not in the old body, they will be ignored.

A `partial-loading` CSS class will be added to each partial node when the PartialViewResult is instantiated, and removed when the view has finished executing.
**/
class PartialViewResult extends ViewResult {

	//
	// Statics
	//

	/**
	A shortcut to create a new PartialViewResult.

	This is useful when you are waiting for a Future: `return getFutureContent() >> PartialViewResult.create;`
	**/
	public static function create( data:{} ):ViewResult return new PartialViewResult( data );

	#if client
		/**
		Create a new PartialViewResult, with the specified data.

		The `partial-loading` class will be added to any `[data-partial]` nodes immediately.

		@param data (optional) Some initial template data to set. If not supplied, an empty {} object will be used.
		@param viewPath (optional) A specific view path to use. If not supplied, it will be inferred based on the `ActionContext` in `this.executeResult()`.
		@param templatingEngine (optional) A specific templating engine to use for the view. If not supplied, it will be inferred based on the `viewPath` in `this.executeResult()`.
		**/
		public function new( ?data:TemplateData, ?viewPath:String, ?templatingEngine:TemplatingEngine ) {
			super( data, viewPath, templatingEngine );

			// Add 'partial-loading' class to each partial section.
			var oldPartialNodes = document.querySelectorAll( "[data-partial]" );
			for ( i in 0...oldPartialNodes.length ) {
				var oldPartialNode = Std.instance( oldPartialNodes.item(i), Element );
				oldPartialNode.classList.add( 'partial-loading' );
			}
		}

		override function writeResponse( response:String, combinedData:TemplateData, actionContext:ActionContext ) {
			var res = actionContext.httpContext.response;
			res.contentType = "text/html";

			var newDoc = document.implementation.createHTMLDocument("");
			newDoc.documentElement.innerHTML = response;

			if ( getAttr(document.body,"data-layout")==getAttr(newDoc.body,"data-layout") ) {
				document.title = newDoc.title;
				var oldPartialNodes = document.querySelectorAll( "[data-partial]" );
				for ( i in 0...oldPartialNodes.length ) {
					var oldPartialNode = Std.instance( oldPartialNodes.item(i), Element );
					oldPartialNode.classList.remove( 'partial-loading' );
					var partialName = getAttr( oldPartialNode, "data-partial" );
					var newPartialNode = newDoc.querySelector('[data-partial=$partialName]');
					replaceChildren( newPartialNode, oldPartialNode );
				}
				window.scrollTo( 0, 0 );
				res.preventFlushContent();
			}


		}

		static function getAttr( elm:Element, name:String ):Null<String> {
			if ( elm!=null ) {
				var attributeNode = elm.attributes.getNamedItem( name );
				return (attributeNode!=null) ? attributeNode.value : null;
			}
			return null;
		}
	#end
}
