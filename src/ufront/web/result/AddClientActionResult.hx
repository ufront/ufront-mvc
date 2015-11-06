package ufront.web.result;

import ufront.web.context.*;
import ufront.core.ClassRef;
import ufront.web.client.UFClientAction;
import ufront.app.ClientJsApplication;
import ufront.core.AsyncTools;
import haxe.Serializer;
using tink.CoreApi;

/**
An `AddClientActionResult` result wraps another `ActionResult`, and if it is a `text/html` response, it will insert some Javascript to trigger the given `UFClientAction` on the client.

It is easiest to use this through static extension:

```haxe
using ufront.web.result.AddClientActionResult;

public function showHomepage() {
  return
  new ViewResult({ title: "Home" })
    .addClientAction( SetupParalaxScrolling )
    .addClientAction( NewNotification, ["New Email"] );
}
```

The actions are sent to the client as JS calls: `ufExecuteSerializedAction( $className, $serializedData )`.
The data will be serialized on the server and unserialized on the client, and will generate an error if the types on the server are different to the types on the client, or if a different serialization error occurs.
**/
class AddClientActionResult<R:ActionResult,T> extends CallJavascriptResult<R> implements WrappedResult<R> {

	// Static helpers

	/** Wrap an `ActionResult` in a `AddClientActionResult`. **/
	public static function addClientAction<R:ActionResult,T>( originalResult:R, clientAction:ClassRef<UFClientAction<T>>, ?data:T ) {
		return new AddClientActionResult( originalResult, clientAction, data );
	}

	// Member

	public var action:ClassRef<UFClientAction<T>>;
	public var actionData:T;

	public function new( originalResult:R, clientAction:ClassRef<UFClientAction<T>>, ?data:T ) {
		super( originalResult );
		this.action = clientAction;
		this.actionData = data;
	}

	/**
	Execute the result.

	This will execute the original result, and then attempt to trigger the action to be executed.

	On the server, it will trigger the action by adding inline JS to execute the actions just before the body tag.
	The data will be serialized using standard Haxe serialization, and called using `ClientJsApplication.ufExecuteSerializedAction()`.

	On the client, this will call `ClientJsApplication.ufExecuteAction()` directly.
	Please note that currently this will execute immediately after the action result has finished executing, so possibly before middleware or `HttpResponse.flush()` have completed.
	In future this may be changed to execute after the request has finished completely.
	**/
	override public function executeResult( actionContext:ActionContext ):Surprise<Noise,Error> {
		return originalResult.executeResult( actionContext ) >> function(n:Noise) {
			#if server
				var response = actionContext.httpContext.response;
				if( response.contentType=="text/html" ) {
					var className = this.action.toString();
					var serializedData = Serializer.run( actionData );
					var fnCall = 'ufExecuteSerializedAction( "$className", "$serializedData" )';
					var script = '<script type="text/javascript">$fnCall</script>';
					var newContent = CallJavascriptResult.insertScriptsBeforeBodyTag( response.getBuffer(), [script] );
					response.clearContent();
					response.write( newContent );
				}
			#elseif client
				ClientJsApplication.ufExecuteAction( this.action, actionData );
			#end
			return Noise;
		};
	}
}
