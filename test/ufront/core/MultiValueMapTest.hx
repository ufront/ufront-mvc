package ufront.core;
import haxe.ds.StringMap;

import utest.Assert;
import ufront.core.MultiValueMap;

class MultiValueMapTest
{
	var emptyMap:MultiValueMap<Int>;
	var stringMap:MultiValueMap<String>;

	public function new() {}

	public function beforeClass():Void {}

	public function afterClass():Void {}

	public function setup():Void {
		emptyMap = new MultiValueMap();
		stringMap = new MultiValueMap();
		stringMap.add( "project", "Haxe" );
		stringMap.add( "project", "Ufront" );
		stringMap.add( "type", "web framework" );
	}

	public function teardown():Void {

	}

	public function testKeys():Void {
		var keys = [ for (k in stringMap.keys()) k ];
		Assert.equals( 2, keys.length );
		Assert.isTrue( keys.indexOf("project") > -1 );
		Assert.isTrue( keys.indexOf("type") > -1 );
	}

	public function testExists():Void {
		Assert.isTrue( stringMap.exists("project") );
		Assert.isTrue( stringMap.exists("type") );
		Assert.isFalse( stringMap.exists("celebrity") );
		Assert.isFalse( emptyMap.exists("celebrity") );
	}

	public function testIterator():Void {
		var values = [ for (v in stringMap) v ];
		Assert.equals( 3, values.length );
		Assert.isTrue( values.indexOf("Haxe") > -1 );
		Assert.isTrue( values.indexOf("Ufront") > -1 );
		Assert.isTrue( values.indexOf("web framework") > -1 );
	}

	public function testGet():Void {
		Assert.equals( "Ufront", stringMap.get("project") );
		Assert.equals( "web framework", stringMap.get("type") );
		Assert.isNull( stringMap.get("celebrity") );
		Assert.equals( "Ufront", stringMap["project"] );
	}

	public function testGetAll():Void {
		Assert.equals( 2, stringMap.getAll("project").length );
		Assert.equals( "Haxe", stringMap.getAll("project")[0] );
		Assert.equals( "Ufront", stringMap.getAll("project")[1] );
		Assert.equals( 1, stringMap.getAll("type").length );
		Assert.equals( "web framework", stringMap.getAll("type")[0] );
		Assert.equals( 0, stringMap.getAll("celebrity").length );
	}

	public function testSet():Void {
		// Test set when it did not exist previously
		emptyMap.set( "value", 100 );
		Assert.equals( 100, emptyMap.get("value") );
		stringMap["celebrity"] = "SpongeBob";
		Assert.equals( "SpongeBob", stringMap.get("celebrity") );

		// Test set (overwriting existing value)
		emptyMap["value"] = 200;
		Assert.equals( 200, emptyMap.get("value") );
		Assert.equals( 2, stringMap.getAll("project").length );
		stringMap.set("project", "ufront-mvc");
		Assert.equals( 1, stringMap.getAll("project").length );

		// Test stripping the "[]" from the name
		emptyMap["value[]"] = 300;
		Assert.equals( 300, emptyMap.get("value") );
	}

	public function testAdd():Void {
		Assert.equals( 0, emptyMap.getAll("value").length );
		emptyMap.add( "value", 100 );
		Assert.equals( 1, emptyMap.getAll("value").length );
		Assert.equals( 100, emptyMap.getAll("value")[0] );
		emptyMap.add( "value", 200 );
		Assert.equals( 2, emptyMap.getAll("value").length );
		Assert.equals( 100, emptyMap.getAll("value")[0] );
		Assert.equals( 200, emptyMap.getAll("value")[1] );
		Assert.equals( 200, emptyMap.get("value") );
		emptyMap.add( "value[]", 300 );
		Assert.equals( 3, emptyMap.getAll("value").length );
		Assert.equals( 100, emptyMap.getAll("value")[0] );
		Assert.equals( 200, emptyMap.getAll("value")[1] );
		Assert.equals( 300, emptyMap.getAll("value")[2] );
		Assert.equals( 300, emptyMap.get("value") );
	}

	public function testRemove():Void {
		Assert.equals( 2, stringMap.getAll("project").length );
		stringMap.remove( "project" );
		Assert.equals( 0, stringMap.getAll("project").length );
	}

	public function testClone():Void {
		var clonedMap = stringMap.clone();
		Assert.equals( 2, clonedMap.getAll("project").length );
		Assert.equals( 1, clonedMap.getAll("type").length );
		Assert.equals( "Ufront", clonedMap.get("project") );
		Assert.equals( "Haxe", clonedMap.getAll("project")[0] );

		// Check they are different objects
		clonedMap.add( "project", "Autoform" );
		Assert.equals( 2, stringMap.getAll("project").length );
		Assert.equals( 3, clonedMap.getAll("project").length );
	}

	public function testToStringMap():Void {
		var s1 = stringMap.toStringMap();
		var s2:StringMap<String> = stringMap;
		var s3:Map<String,String> = stringMap;
		Assert.equals( "Ufront", s1.get("project") );
		Assert.equals( "Ufront", s2.get("project") );
		Assert.equals( "Ufront", s3.get("project") );
		Assert.equals( "web framework", s1.get("type") );
		Assert.equals( "web framework", s2.get("type") );
		Assert.equals( "web framework", s3.get("type") );
		Assert.equals( 2, [ for (k in s1.keys()) k ].length );
		Assert.equals( 2, [ for (k in s2.keys()) k ].length );
		Assert.equals( 2, [ for (k in s3.keys()) k ].length );

		// Check changes do not affect original
		s1.set( "project", "Dart" );
		Assert.equals( "Dart", s1.get("project") );
		Assert.equals( "Ufront", stringMap.get("project") );
	}

	public function testFromStringMap():Void {
		var sm = [ "project"=>"Ufront", "type"=>"web framework" ];
		var map:Map<String,String> = sm;
		var mvm1 = MultiValueMap.fromStringMap( sm );
		var mvm2:MultiValueMap<String> = sm;
		var mvm3:MultiValueMap<String> = map;
		Assert.equals( "Ufront", mvm1.get("project") );
		Assert.equals( "Ufront", mvm2.get("project") );
		Assert.equals( "Ufront", mvm3.get("project") );
		Assert.equals( "web framework", mvm1.get("type") );
		Assert.equals( "web framework", mvm2.get("type") );
		Assert.equals( "web framework", mvm3.get("type") );
		Assert.equals( 2, [ for (k in mvm1.keys()) k ].length );
		Assert.equals( 2, [ for (k in mvm2.keys()) k ].length );
		Assert.equals( 2, [ for (k in mvm3.keys()) k ].length );
		mvm1.add( "project","Dart" );
		Assert.equals( 2, mvm1.getAll("project").length );
		Assert.equals( "Dart", mvm1.get("project") );
	}

	public function testCombine():Void {
		var mvm1:MultiValueMap<String> = [ "value"=>["100","200"] ];
		var mvm2:MultiValueMap<String> = [ "project"=>"Dart", "value"=>"300", "author"=>"Jason" ];
		var combined = MultiValueMap.combine( [stringMap, mvm1, mvm2] );

		Assert.isTrue( combined.exists("project") );
		Assert.equals( 3, combined.getAll("project").length );
		Assert.equals( "Dart", combined.get("project") );

		Assert.isTrue( combined.exists("type") );
		Assert.equals( 1, combined.getAll("type").length );
		Assert.equals( "web framework", combined.get("type") );

		Assert.isTrue( combined.exists("value") );
		Assert.equals( 3, combined.getAll("value").length );
		Assert.equals( "300", combined.get("value") );
		Assert.equals( "100", combined.getAll("value")[0] );
		Assert.equals( "200", combined.getAll("value")[1] );
		Assert.equals( "300", combined.getAll("value")[2] );

		Assert.isTrue( combined.exists("author") );
		Assert.equals( "Jason", combined.get("author") );
		Assert.equals( 1, combined.getAll("author").length );
	}

	public function testStraightCasts():Void {
		var sm1:StringMap<Array<String>> = stringMap;
		var sm2:Map<String,Array<String>> = stringMap;
		Assert.equals( 2, sm1.get("project").length );
		Assert.equals( 2, sm2.get("project").length );

		var map1:Map<String,Array<Int>> = [ "value"=>[0,20] ];
		var map2:StringMap<Array<Int>> = map1;
		emptyMap = map1;
		Assert.equals( 20, emptyMap.get("value") );
		Assert.equals( 2, emptyMap.getAll("value").length );
		Assert.equals( 0, emptyMap.getAll("value")[0] );
		emptyMap = map2;
		Assert.equals( 20, emptyMap.get("value") );
		Assert.equals( 2, emptyMap.getAll("value").length );
		Assert.equals( 0, emptyMap.getAll("value")[0] );
	}

	public function testToString():Void {
	}
}
