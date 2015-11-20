package ufront.view;

import utest.Assert;
import ufront.view.TemplatingEngines;

class TemplatingEnginesTest {
	var instance:TemplatingEngines;

	public function new() {}

	public function beforeClass():Void {}

	public function afterClass():Void {}

	public function setup():Void {}

	public function teardown():Void {}

	public function testTemplatingEngines():Void {

		var templates = [
			"haxe.Template" => {
				simple: "My name is ::name:: and I am ::age::",
				loop: "What do I eat? ::foreach fruit::I eat ::__current__::. ::end::",
				addHelper: "I can add ::x:: and ::y::: $$add(::x::,::y::)",
				printHelper: "Did you know $$print(Jason,::siblings::)",
			},
			"erazor.Template" => {
				simple: "My name is @name and I am @age",
				loop: "What do I eat? @for(fruitType in fruit){I eat @fruitType. }",
				addHelper: "I can add @x and @y: @add(x,y)",
				printHelper: "Did you know @print('Jason',siblings)",
			},
		];

		var tplEngines = [TemplatingEngines.haxe, TemplatingEngines.erazor];
		for ( tplEngine in tplEngines ) {
			var templates = templates[tplEngine.type];
			function check( template, data, helpers, expectedResult, ?pos:haxe.PosInfos) {
				var tpl = tplEngine.factory( template );
				var result = tpl.execute( data, helpers );
				Assert.equals( expectedResult, result, '${tplEngine.type} failed to transform "$template" to become "$expectedResult", but got "$result"', pos );
			}

			check( templates.simple, { name:"Jason", age:28 }, null, "My name is Jason and I am 28" );

			check( templates.loop, { fruit:[] }, null, "What do I eat? " );
			check( templates.loop, { fruit:["apples","oranges"] }, null, "What do I eat? I eat apples. I eat oranges. " );

			var additionHelper = function(x:Int,y:Int):Int return x+y;
			check( templates.addHelper, { x:10, y:25 }, ["add"=>additionHelper], "I can add 10 and 25: 35" );

			var printHelper = function(name:String,siblings:Array<String>):String return '$name has ${siblings.length} siblings: ${siblings.join(", ")}';
			check( templates.printHelper, { siblings: ["Aaron","Clare"] }, ["print"=>printHelper], "Did you know Jason has 2 siblings: Aaron, Clare" );
		}

	}
}
