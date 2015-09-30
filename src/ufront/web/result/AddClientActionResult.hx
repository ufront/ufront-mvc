package ufront.web.result;

import ufront.web.context.*;
import ufront.core.AsyncTools;
using tink.CoreApi;

/**
An `AddClientActionResult` result wraps another `ActionResult`, and if it is a `text/html` response, it will insert some Javascript to trigger the given `UFClientAction` on the client.

It is easiest to use this through static extension:

```haxe
using ufront.web.result.TriggerClientAction;

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

	public var originalResult:R;
	public var action:ClassRef<UFClientAction<T>>;
	public var actionData:T;

	public function new( originalResult:T, clientAction:ClassRef<UFClientAction<T>>, ?data:T ) {
		this.originalResult = originalResult;
		this.action = clientAction;
		this.actionData = data;
	}

	/**
	Execute the result.

	This will execute the original result, and then attempt to add the JS to execute the actions just before the body tag.
	If the action data is

	Currently on the client we add the JS snippet in the same way, but in future we may execute the action directly once the request has completed.
	**/
	override public function executeResult( actionContext:ActionContext ):Surprise<Noise,Error> {
		return originalResult.executeResult( actionContext ) >> function(n:Noise) {
			var response = actionContext.httpContext.response;
			if( response.contentType=="text/html" ) {
				var className = this.action.toString();
				var serializedData = haxe.Serialized.run( actionData );
				var fnCall = 'ufExecuteSerializedAction( "$className", "$serializedData" )';
				var script = '<script type="text/javascript">$fnCall</script>';
				var newContent = CallJavascriptResult.insertScriptsBeforeBodyTag( response.getBuffer(), [script] );
				response.clearContent();
				response.write( newContent );
			}
			return Noise;
		};
	}
}
