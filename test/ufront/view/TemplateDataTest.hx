package ufront.view;

import massive.munit.util.Timer;
import massive.munit.Assert;
import massive.munit.async.AsyncFactory;
import ufront.view.TemplateData;
import haxe.ds.StringMap;

class TemplateDataTest 
{
	var instance:TemplateData; 
	
	public function new() 
	{
		
	}
	
	@BeforeClass
	public function beforeClass():Void
	{
	}
	
	@AfterClass
	public function afterClass():Void
	{
	}
	
	@Before
	public function setup():Void
	{
	}
	
	@After
	public function tearDown():Void
	{
	}
	
	@Test
	public function toObject():Void
	{
		var data:TemplateData = { name: "jason", age: 26 };

		var obj = data.toObject();
		Assert.areEqual( "jason", obj.name );
	}

	@Test
	public function toMap():Void
	{
		var data:TemplateData = { name: "jason", age: 26 };

		var map = data.toMap();
		Assert.areEqual( "jason", map["name"] );

		var map2:Map<String,Dynamic> = data;
		Assert.areEqual( 26, map2["age"] );
	}

	@Test
	public function toStringMap():Void
	{
		var data:TemplateData = { name: "jason", age: 26 };

		var map = data.toStringMap();
		Assert.areEqual( "jason", map["name"] );

		var map2:StringMap<Dynamic> = data;
		Assert.areEqual( 26, map2.get("age") );
	}

	@Test
	public function get():Void
	{
		var data:TemplateData = { name: "jason", age: 26 };
		Assert.areEqual( "jason", data.get("name") );
		Assert.areEqual( "jason", data["name"] );
		Assert.areEqual( 26, data.get("age") );
		Assert.areEqual( null, data.get("language") );
	}

	@Test
	public function set():Void
	{
		var data:TemplateData = { name: "jason", age: 26 };
		Assert.areEqual( 2, Reflect.fields(data).length );

		data.set( 'language', 'Haxe' );
		Assert.areEqual( 3, Reflect.fields(data).length );
		Assert.areEqual( "Haxe", data.get("language") );

		data['name'] = "Franco";
		Assert.areEqual( 3, Reflect.fields(data).length );
		Assert.areEqual( "Franco", data.get("name") );
	}

	@Test
	public function setMap():Void
	{
		var data:TemplateData = { name: "jason", age: 26 };
		data.setMap([ "name" => "Franco", "language" => "Haxe" ]);
		Assert.areEqual( 3, Reflect.fields(data).length );
		Assert.areEqual( "Franco", data["name"] );
		Assert.areEqual( 26, data["age"] );
		Assert.areEqual( "Haxe", data["language"] );
	}

	@Test
	public function setObject():Void
	{
		var data:TemplateData = { name: "jason", age: 26 };
		data.setObject({ name: "jason", language: "Haxe" });
		Assert.areEqual( 3, Reflect.fields(data).length );
		Assert.areEqual( "jason", data["name"] );
		Assert.areEqual( 26, data["age"] );
		Assert.areEqual( "Haxe", data["language"] );
	}

	@Test
	public function fromObject():Void
	{
		var emptyData:TemplateData = {};
		Assert.areEqual( 0, Reflect.fields(emptyData).length );

		var data1 = TemplateData.fromObject({ "name": "jason" });
		Assert.areEqual( 1, Reflect.fields(data1).length );
		Assert.areEqual( "jason", data1["name"] );

		var data2 = TemplateData.fromObject({ name: "jason", age: 26 });
		Assert.areEqual( 2, Reflect.fields(data2).length );
		Assert.areEqual( "jason", data2["name"] );
		Assert.areEqual( 26, data2["age"] );

		var data3 = TemplateData.fromObject({ language: "Haxe", targets: ["neko","php","js"] });
		Assert.areEqual( 2, Reflect.fields(data3).length );
		Assert.areEqual( "Haxe", data3["language"] );
		Assert.areEqual( 3, data3["targets"].length );
		Assert.areEqual( "php", data3["targets"][1] );

		// Test implicit cast
		var data4:TemplateData = { language: "Haxe", targets: ["neko","php","js"] };
		Assert.areEqual( 2, Reflect.fields(data4).length );
		Assert.areEqual( "Haxe", data4["language"] );
		Assert.areEqual( 3, data4["targets"].length );
		Assert.areEqual( "php", data4["targets"][1] );
	}

	@Test
	public function fromMap():Void
	{
		var map = [ "name" => "jason", "language" => "Haxe" ];
		var data1 = TemplateData.fromMap(map);
		Assert.areEqual( 2, Reflect.fields(data1).length );
		Assert.areEqual( "jason", data1["name"] );
		Assert.areEqual( "Haxe", data1["language"] );

		var data2:TemplateData = map;
		Assert.areEqual( 2, Reflect.fields(data2).length );
		Assert.areEqual( "jason", data2["name"] );
		Assert.areEqual( "Haxe", data2["language"] );
	}

	@Test
	public function fromStringMap():Void
	{
		var stringMap:StringMap<String> = [ "name" => "jason", "language" => "Haxe" ];
		var data:TemplateData = stringMap;
		Assert.areEqual( 2, Reflect.fields(data).length );
		Assert.areEqual( "jason", data["name"] );
		Assert.areEqual( "Haxe", data["language"] );
	}

	@Test
	public function fromMany():Void
	{
		var emptyData:TemplateData = [];
		Assert.areEqual( 0, Reflect.fields(emptyData).length );

		var dataObj:TemplateData = { name: "jason", age: 26 };
		var dataMap:TemplateData = [ "name"=>"Franco", "language"=>"Haxe" ];

		var combined = TemplateData.fromMany([ dataObj, dataMap ]);
		Assert.areEqual( 3, Reflect.fields(combined).length );
		Assert.areEqual( "Franco", combined["name"] );
		Assert.areEqual( 26, combined["age"] );
		Assert.areEqual( "Haxe", combined["language"] );

		var combined1:TemplateData = [ dataObj, dataMap ];
		Assert.areEqual( 3, Reflect.fields(combined1).length );
		Assert.areEqual( "Franco", combined1["name"] );
		Assert.areEqual( 26, combined1["age"] );
		Assert.areEqual( "Haxe", combined1["language"] );

		var combined2:TemplateData = [ dataObj, dataMap, { greatGuy: true } ];
		Assert.areEqual( 4, Reflect.fields(combined2).length );
		Assert.areEqual( true, combined2["greatGuy"] );

		var combined3:TemplateData = [ dataObj, dataMap, ["greatGuy"=>true] ];
		Assert.areEqual( 4, Reflect.fields(combined3).length );
		Assert.areEqual( true, combined3["greatGuy"] );

		var combined4:TemplateData = [ dataObj, dataMap, ["greatGuy"=>true] ];
		Assert.areEqual( 4, Reflect.fields(combined4).length );
		Assert.areEqual( true, combined4["greatGuy"] );
	}
}
