package ufront.view;

import ufront.view.TemplateData;

/**
A type representing a template that is ready to render a template with the given TemplateData.

This is an abstract, and at runtime it will simply use the callback directly.

It was designed this way to be flexible and integrate easily with existing templating systems.

For example, to use haxe's templating engine:

```
var tpl:UFTemplate = function (data) new haxe.Template( myTemplate ).execute( data.toObject() );
tpl.execute([ 'name'=>'Jason', 'age'=>26, helper=>someHelper ]);
```

Implicit casts are provided to and from the underlying `TemplateData->String` type.
**/
abstract UFTemplate( TemplateData->String ) from TemplateData->String to TemplateData->String {

	public function new( cb:TemplateData->String ) this = cb;

	/**
	Execute the template with the given data.

	Please see `TemplateData` for an explanation of the different data types that can be accepted through the implicit casts.
	**/
	public inline function execute( data:TemplateData ):String {
		// Haxe 3.0.1 won't allow me to call this() directly, it gives `Field this cannot be accessed for reading`.
		var cb = this;
		return cb(data);
	}
}
