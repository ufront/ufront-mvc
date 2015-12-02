package ufront.web.result;

#if client
	import ufront.view.TemplateData;
	import ufront.view.TemplatingEngines;
	import ufront.web.context.ActionContext;
	import js.ufront.web.context.HttpResponse.replaceNode;
	import js.Browser.*;
	import js.html.*;
#end

/**
A PartialViewResult is similar to a `ViewResult`, but on the client side it checks checks for partial sections of the view to update, rather than reloading the entire DOM.

On the server side, this performs identically to ViewResult.

On the client side, this will:

1. Pick the relevant view and layout in the same way as ViewResult.
2. Execute the layout and the template to get a full HTML response.
3. Check the body for a `data-uf-layout` attribute. If the attribute has changed with the new request (that is, the new layout is different to the old one), then the entire body will be replaced.
4. If the layout has not changed, check for elements with a `data-uf-partial` attribute, and replace the old partial element with the new partial element.

### Transition classes

- An old partial node that is being replaced will have the `uf-partial-outgoing` class.
- A new partial node that is being inserted will initially have the `uf-partial-incoming` class, and it will be removed after 1 millisecond.
- You can use these classes to trigger CSS3 transitions.

If you would like to prevent your old partial nodes from being deleted before the transitions have completed, you can use a `data-uf-transition-timeout` attribute on the partial node, or set a default value in `PartialViewResult.transitionTimeout`.

### When old and new layouts are different

If some of the partial sections in the old body are not in the new body, the sections in the old body will be removed.

If some of the partial sections in the new body are not in the old body, they will be ignored.

### Example

Imagine this template:

```html
<html>
<body data-uf-layout="site-page">
    <div class="container" />
        <div class="row">
            <div class="col-md-3">
                <ul data-uf-partial="nav">
                    ::for (link in navItems)::
                        <li>::link::</li>
                    ::end::
                </ul>
            </div>
            <div class="col-md-9" data-uf-partial="content" data-uf-transition-timeout="1000">
                ::content::
            </div>
        </div>
    </div>
</body>
</html>
```

When this is executed server-side, it will render the view and the layout as per normal.
When it is executed client-side, it will execute the view and the layout, but only replace the DOM nodes for `ul[data-uf-partial=nav]` and `div[data-uf-partial=content]`.

The old `content` partial will be given the `uf-partial-outgoing` class, and will be removed when it's CSS animation is complete, or after 1000 milliseconds, whichever occurs first.
The new `content` will be created with the `uf-partial-incoming` class, and that class will be removed immediately, allowing a CSS transition to occur.

The old `nav` partial will be removed as soon as the new one is ready.

If the template and layout that is rendered has a different `body[data-uf-layout]` attribute, then the entire view will be re-rendered.
**/
class PartialViewResult extends ViewResult {

	//
	// Statics
	//

	/**
	The default transitionTimeout value to be used with `js.ufront.web.context.HttpResponse.replaceNode`.

	This value will be used if no `data-uf-transition-timeout` attribute is present on the given old partial node.

	- If the value is 0 (default), then the old partial nodes will be removed immediately.
	- If the value is greater than 0, then the old partial will be removed either when a `transitionend` event occurs, or after the specified number of milliseconds (whichever occurs first).
	- If the value is less than 0, then the old partial will only be removed when a `transitionend` event occurs. (Warning: this event is not guaranteed to trigger, as it may have already triggered, may be cancelled etc. It is recommended to use a positive value as a timeout).
	**/
	public static var transitionTimeout:Int = 0;

	/**
	A shortcut to create a new PartialViewResult.

	This is useful when you are waiting for a Future: `return getFutureContent() >> PartialViewResult.create;`
	**/
	public static function create( data:{} ):ViewResult return new PartialViewResult( data );

	#if client
		/**
		Create a new PartialViewResult, with the specified data.

		This will call `startLoadingAnimations()` immediately, adding the `uf-partial-outgoing` class to any existing partials.

		@param data (optional) Some initial template data to set. If not supplied, an empty {} object will be used.
		@param viewPath (optional) A specific view path to use. If not supplied, it will be inferred based on the `ActionContext` in `this.executeResult()`.
		@param templatingEngine (optional) A specific templating engine to use for the view. If not supplied, it will be inferred based on the `viewPath` in `this.executeResult()`.
		**/
		public function new( ?data:TemplateData, ?viewPath:String, ?templatingEngine:TemplatingEngine ) {
			super( data, viewPath, templatingEngine );
			startLoadingAnimations();
		}

		override function writeResponse( response:String, actionContext:ActionContext ) {
			var res = actionContext.httpContext.response;
			res.contentType = "text/html";

			var newDoc = document.implementation.createHTMLDocument("");
			newDoc.documentElement.innerHTML = response;

			if ( getAttr(document.body,"data-uf-layout")==getAttr(newDoc.body,"data-uf-layout") ) {
				document.title = newDoc.title;
				var oldPartialNodes = document.querySelectorAll( "[data-uf-partial]" );
				for ( i in 0...oldPartialNodes.length ) {
					var oldPartialNode = Std.instance( oldPartialNodes.item(i), Element );
					var partialName = getAttr( oldPartialNode, "data-uf-partial" );
					var newPartialNode = newDoc.querySelector('[data-uf-partial=$partialName]');

					var timeout = Std.parseInt( getAttr(oldPartialNode, "data-uf-transition-timeout") );
					if ( timeout==null )
						timeout = PartialViewResult.transitionTimeout;

					newPartialNode.classList.add( 'uf-partial-incoming' );
					replaceNode( oldPartialNode, newPartialNode, timeout );
					window.setTimeout(function() {
						newPartialNode.classList.remove( 'uf-partial-incoming' );
					}, 1);
				}
				window.scrollTo( 0, 0 );
				res.preventFlushContent();
			}
			else {
				// If it is a different layout, we leave it to `HttpResponse.flush` to render from scratch.
				super.writeResponse( response, actionContext );
			}
		}

		/**
		Add `uf-partial-outgoing` class to each partial section, allowing you to use CSS to style the transitions.
		**/
		public static function startLoadingAnimations():Void {
			var oldPartialNodes = document.querySelectorAll( "[data-uf-partial]" );
			for ( i in 0...oldPartialNodes.length ) {
				var oldPartialNode = Std.instance( oldPartialNodes.item(i), Element );
				oldPartialNode.classList.add( 'uf-partial-outgoing' );
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
