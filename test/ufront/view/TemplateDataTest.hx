package ufront.view;

import utest.Assert;
import ufront.view.TemplateData;
import haxe.ds.StringMap;

class TemplateDataTest 
{
	var instance:TemplateData; 
	
	public function new() 
	{
		
	}
	
	public function beforeClass():Void {}
	
	public function afterClass():Void {}
	
	public function setup():Void {}
	
	public function teardown():Void {}
	
	public function toObject():Void {
		var data:TemplateData = { name: "jason", age: 26 };

		var obj = data.toObject();
		Assert.equals( "jason", obj.name );
	}

	public function toMap():Void {
		var data:TemplateData = { name: "jason", age: 26 };

		var map = data.toMap();
		Assert.equals( "jason", map["name"] );

		var map2:Map<String,Dynamic> = data;
		Assert.equals( 26, map2["age"] );
	}

	public function toStringMap():Void {
		var data:TemplateData = { name: "jason", age: 26 };

		var map = data.toStringMap();
		Assert.equals( "jason", map["name"] );

		var map2:StringMap<Dynamic> = data;
		Assert.equals( 26, map2.get("age") );
	}

	public function get():Void {
		var data:TemplateData = { name: "jason", age: 26 };
		Assert.equals( "jason", data.get("name") );
		Assert.equals( "jason", data["name"] );
		Assert.equals( 26, data.get("age") );
		Assert.equals( null, data.get("language") );
	}

	public function set():Void {
		var data:TemplateData = { name: "jason", age: 26 };
		Assert.equals( 2, Reflect.fields(data).length );

		data.set( 'language', 'Haxe' );
		Assert.equals( 3, Reflect.fields(data).length );
		Assert.equals( "Haxe", data.get("language") );

		data['name'] = "Franco";
		Assert.equals( 3, Reflect.fields(data).length );
		Assert.equals( "Franco", data.get("name") );
	}

	public function setMap():Void {
		var data:TemplateData = { name: "jason", age: 26 };
		data.setMap([ "name" => "Franco", "language" => "Haxe" ]);
		Assert.equals( 3, Reflect.fields(data).length );
		Assert.equals( "Franco", data["name"] );
		Assert.equals( 26, data["age"] );
		Assert.equals( "Haxe", data["language"] );
	}

	public function setObject():Void {
		var data:TemplateData = { name: "jason", age: 26 };
		data.setObject({ name: "jason", language: "Haxe" });
		Assert.equals( 3, Reflect.fields(data).length );
		Assert.equals( "jason", data["name"] );
		Assert.equals( 26, data["age"] );
		Assert.equals( "Haxe", data["language"] );
	}

	public function fromObject():Void {
		var emptyData:TemplateData = {};
		Assert.equals( 0, Reflect.fields(emptyData).length );

		var data1 = TemplateData.fromObject({ "name": "jason" });
		Assert.equals( 1, Reflect.fields(data1).length );
		Assert.equals( "jason", data1["name"] );

		var data2 = TemplateData.fromObject({ name: "jason", age: 26 });
		Assert.equals( 2, Reflect.fields(data2).length );
		Assert.equals( "jason", data2["name"] );
		Assert.equals( 26, data2["age"] );

		var data3 = TemplateData.fromObject({ language: "Haxe", targets: ["neko","php","js"] });
		Assert.equals( 2, Reflect.fields(data3).length );
		Assert.equals( "Haxe", data3["language"] );
		Assert.equals( 3, data3["targets"].length );
		Assert.equals( "php", data3["targets"][1] );

		// Test implicit cast
		var data4:TemplateData = { language: "Haxe", targets: ["neko","php","js"] };
		Assert.equals( 2, Reflect.fields(data4).length );
		Assert.equals( "Haxe", data4["language"] );
		Assert.equals( 3, data4["targets"].length );
		Assert.equals( "php", data4["targets"][1] );
	}

	public function fromMap():Void {
		var map = [ "name" => "jason", "language" => "Haxe" ];
		var data1 = TemplateData.fromMap(map);
		Assert.equals( 2, Reflect.fields(data1).length );
		Assert.equals( "jason", data1["name"] );
		Assert.equals( "Haxe", data1["language"] );

		var data2:TemplateData = map;
		Assert.equals( 2, Reflect.fields(data2).length );
		Assert.equals( "jason", data2["name"] );
		Assert.equals( "Haxe", data2["language"] );
	}

	public function fromStringMap():Void {
		var stringMap:StringMap<String> = [ "name" => "jason", "language" => "Haxe" ];
		var data:TemplateData = stringMap;
		Assert.equals( 2, Reflect.fields(data).length );
		Assert.equals( "jason", data["name"] );
		Assert.equals( "Haxe", data["language"] );
	}

	public function fromMany():Void {
		var emptyData:TemplateData = [];
		Assert.equals( 0, Reflect.fields(emptyData).length );

		var dataObj:TemplateData = { name: "jason", age: 26 };
		var dataMap:TemplateData = [ "name"=>"Franco", "language"=>"Haxe" ];

		var combined = TemplateData.fromMany([ dataObj, dataMap ]);
		Assert.equals( 3, Reflect.fields(combined).length );
		Assert.equals( "Franco", combined["name"] );
		Assert.equals( 26, combined["age"] );
		Assert.equals( "Haxe", combined["language"] );

		var combined1:TemplateData = [ dataObj, dataMap ];
		Assert.equals( 3, Reflect.fields(combined1).length );
		Assert.equals( "Franco", combined1["name"] );
		Assert.equals( 26, combined1["age"] );
		Assert.equals( "Haxe", combined1["language"] );

		var combined2:TemplateData = [ dataObj, dataMap, { greatGuy: true } ];
		Assert.equals( 4, Reflect.fields(combined2).length );
		Assert.equals( true, combined2["greatGuy"] );

		var combined3:TemplateData = [ dataObj, dataMap, ["greatGuy"=>true] ];
		Assert.equals( 4, Reflect.fields(combined3).length );
		Assert.equals( true, combined3["greatGuy"] );

		var combined4:TemplateData = [ dataObj, dataMap, ["greatGuy"=>true] ];
		Assert.equals( 4, Reflect.fields(combined4).length );
		Assert.equals( true, combined4["greatGuy"] );
	}
}
