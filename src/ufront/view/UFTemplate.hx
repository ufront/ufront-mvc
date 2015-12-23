package ufront.view;

import ufront.view.TemplateData;

/**
A type representing a template that is ready to render a template with the given TemplateData.

This is an abstract, and at runtime it will simply use the callback directly.

It was designed this way to be flexible and integrate easily with existing templating systems.

For example, to use haxe's templating engine:

```haxe

// Erazor:
var tpl:UFTemplate = function (data:TemplateData) return new erazor.Template( tplString ).execute( data.toObject() );

// Haxe Templating:
// Note: because haxe.Template uses their own `macros`, which are slightly different to our helpers (they have an extra first argument), we need to wrap the helpers first.
var tpl:UFTemplate = function (data:TemplateData, helpers:TemplateHelper) return new haxe.Template( tplString ).execute( data.toObject(), wrapHelpers(helpers) );
```

Implicit casts are provided to and from the underlying `TemplateData->String` type.
**/
@:callable
abstract UFTemplate( TemplateData->Null<Map<String,TemplateHelper>>->String ) from TemplateData->Null<Map<String,TemplateHelper>>->String to TemplateData->Null<Map<String,TemplateHelper>>->String {

	public function new( cb:TemplateData->Null<Map<String,TemplateHelper>>->String ) this = cb;

	/**
	If a templating engine combines data and helpers in a single object, you can create a UFTemplate from a single `TemplateData->String` function.
	This will combine the `data` and `helpers` objects into a single object, and pass it to the callback.
	**/
	@:from public static function fromSimpleCallback( cb:TemplateData->String ) {
		return new UFTemplate(function(data,helpers) {
			var combinedData = new TemplateData();
			if ( helpers!=null ) {
				for ( helperName in helpers.keys() ) {
					combinedData.set( helperName, helpers[helperName].getFn() );
				}
			}
			combinedData.setObject( data );
			return cb( combinedData );
		});
	}

	/**
	Execute the template with the given data and helpers.

	Please see `TemplateData` and `TemplateHelper` for an explanation of the different data types that can be accepted through the implicit casts.

	`UFTemplate` also has `@:callable` metadata, so you can call it directly: `myTemplate( data, helpers )`.
	**/
	public inline function execute( data:TemplateData, ?helpers:Map<String,TemplateHelper> ):String {
		return this( data, helpers );
	}
}
