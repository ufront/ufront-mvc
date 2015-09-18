package ufront.web.client;

import ufront.web.context.HttpContext;

/**
UFClientAction is a Javascript action that will run on the client's web browser.

### Use cases for Client Actions.

Examples of what actions are appropriate for:

- Initialising some Javascript UI on page load.
- Setting up client-side form validation.
- Having an action run every 30 seconds to check for new notifications to show the user.

Examples of what actions are inappropriate for:

- Rendering an entire page. We recommend using a normal request / response cycle for this, so that if a client has Javascript disabled the page is still usable.
- Anything which should affect the browser's history state. If the user would expect the back button to undo your action, you should probably use a request / response cycle instead.

### Triggering client actions.

Actions can be triggered during a server request or from the client, even from 3rd party code.

See `TriggerActionResult.triggerAction()` for how to trigger actions from a HTTP request.
See `ClientJsApplication.executeAction()` for how to trigger actions on the client.

### Instantiation

The following process describes how actions are registered and executed on the client:

- Actions are registered with `ClientJsApplication.registerAction()`.
  This maps the action to the client application's injector as a singleton.
  (All actions in `UfrontClientConfiguration.clientActions` are registered when the app starts).
- When `ClientJsApplication.triggerAction()` is called:
	- We use the application injector to fetch the singleton for the action.
	  This means it'll be created with dependency injection, and the same action instance will be re-used each time the action is triggered.
	- We will call `action.execute( ClientJsApplication.currentContext, data )`.

### Macro transformations.

A build macro is applied to all classes that implement `UFClientAction`.
This removes every field from the class on the server.
This is so that the class can exist on the server (so you can trigger client-side actions), while writing client specific code without conditional compilation.
**/
@:autoBuild( ClientActionMacros.emptyServer() )
interface UFClientAction<T> {
	#if client
		/**
		Execute the current action with the given data.
		**/
		public function execute( context:HttpContext, ?data:Null<T> ):Void;
	#end
}
