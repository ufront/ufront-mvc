package ufront.core;
import haxe.ds.StringMap;

import massive.munit.util.Timer;
import massive.munit.Assert;
import massive.munit.async.AsyncFactory;
import ufront.core.MultiValueMap;

class MultiValueMapTest 
{
	var emptyMap:MultiValueMap<Int>;
	var stringMap:MultiValueMap<String>;
    
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
		emptyMap = new MultiValueMap();
		stringMap = new MultiValueMap();
		stringMap.add( "project", "Haxe" );
		stringMap.add( "project", "Ufront" );
		stringMap.add( "type", "web framework" );
	}
	
	@After
	public function tearDown():Void
	{
		
	}
	
	@Test
	public function testKeys():Void
	{
		var keys = [ for (k in stringMap.keys()) k ];
		Assert.areEqual( 2, keys.length );
		Assert.isTrue( keys.indexOf("project") > -1 );
		Assert.isTrue( keys.indexOf("type") > -1 );
	}
	
	@Test
	public function testExists():Void
	{
		Assert.isTrue( stringMap.exists("project") );
		Assert.isTrue( stringMap.exists("type") );
		Assert.isFalse( stringMap.exists("celebrity") );
		Assert.isFalse( emptyMap.exists("celebrity") );
	}
	
	@Test
	public function testIterator():Void
	{
		var values = [ for (v in stringMap) v ];
		Assert.areEqual( 3, values.length );
		Assert.isTrue( values.indexOf("Haxe") > -1 );
		Assert.isTrue( values.indexOf("Ufront") > -1 );
		Assert.isTrue( values.indexOf("web framework") > -1 );
	}
	
	@Test
	public function testGet():Void
	{
		Assert.areEqual( "Ufront", stringMap.get("project") );
		Assert.areEqual( "web framework", stringMap.get("type") );
		Assert.isNull( stringMap.get("celebrity") );
		Assert.areEqual( "Ufront", stringMap["project"] );
	}
	
	@Test
	public function testGetAll():Void
	{
		Assert.areEqual( 2, stringMap.getAll("project").length );
		Assert.areEqual( "Haxe", stringMap.getAll("project")[0] );
		Assert.areEqual( "Ufront", stringMap.getAll("project")[1] );
		Assert.areEqual( 1, stringMap.getAll("type").length );
		Assert.areEqual( "web framework", stringMap.getAll("type")[0] );
		Assert.areEqual( 0, stringMap.getAll("celebrity").length );
	}
	
	@Test
	public function testSet():Void
	{
		// Test set when it did not exist previously
		emptyMap.set( "value", 100 );
		Assert.areEqual( 100, emptyMap.get("value") );
		stringMap["celebrity"] = "SpongeBob";
		Assert.areEqual( "SpongeBob", stringMap.get("celebrity") );
		
		// Test set (overwriting existing value)
		emptyMap["value"] = 200;
		Assert.areEqual( 200, emptyMap.get("value") );
		Assert.areEqual( 2, stringMap.getAll("project").length );
		stringMap.set("project", "ufront-mvc");
		Assert.areEqual( 1, stringMap.getAll("project").length );
		
		// Test stripping the "[]" from the name
		emptyMap["value[]"] = 300;
		Assert.areEqual( 300, emptyMap.get("value") );
	}
	
	@Test
	public function testAdd():Void
	{
		Assert.areEqual( 0, emptyMap.getAll("value").length );
		emptyMap.add( "value", 100 );
		Assert.areEqual( 1, emptyMap.getAll("value").length );
		Assert.areEqual( 100, emptyMap.getAll("value")[0] );
		emptyMap.add( "value", 200 );
		Assert.areEqual( 2, emptyMap.getAll("value").length );
		Assert.areEqual( 100, emptyMap.getAll("value")[0] );
		Assert.areEqual( 200, emptyMap.getAll("value")[1] );
		Assert.areEqual( 200, emptyMap.get("value") );
		emptyMap.add( "value[]", 300 );
		Assert.areEqual( 3, emptyMap.getAll("value").length );
		Assert.areEqual( 100, emptyMap.getAll("value")[0] );
		Assert.areEqual( 200, emptyMap.getAll("value")[1] );
		Assert.areEqual( 300, emptyMap.getAll("value")[2] );
		Assert.areEqual( 300, emptyMap.get("value") );
	}
	
	@Test
	public function testRemove():Void
	{
		Assert.areEqual( 2, stringMap.getAll("project").length );
		stringMap.remove( "project" );
		Assert.areEqual( 0, stringMap.getAll("project").length );
	}
	
	@Test
	public function testToStringMap():Void
	{
		var s1 = stringMap.toStringMap();
		var s2:StringMap<String> = stringMap;
		var s3:Map<String,String> = stringMap;
		Assert.areEqual( "Ufront", s1.get("project") );
		Assert.areEqual( "Ufront", s2.get("project") );
		Assert.areEqual( "Ufront", s3.get("project") );
		Assert.areEqual( "web framework", s1.get("type") );
		Assert.areEqual( "web framework", s2.get("type") );
		Assert.areEqual( "web framework", s3.get("type") );
		Assert.areEqual( 2, [ for (k in s1.keys()) k ].length );
		Assert.areEqual( 2, [ for (k in s2.keys()) k ].length );
		Assert.areEqual( 2, [ for (k in s3.keys()) k ].length );
		
		// Check changes do not affect original
		s1.set( "project", "Dart" );
		Assert.areEqual( "Dart", s1.get("project") );
		Assert.areEqual( "Ufront", stringMap.get("project") );
	}
	
	@Test
	public function testFromStringMap():Void
	{
		var sm = [ "project"=>"Ufront", "type"=>"web framework" ];
		var map:Map<String,String> = sm;
		var mvm1 = MultiValueMap.fromStringMap( sm );
		var mvm2:MultiValueMap<String> = sm;
		var mvm3:MultiValueMap<String> = map;
		Assert.areEqual( "Ufront", mvm1.get("project") );
		Assert.areEqual( "Ufront", mvm2.get("project") );
		Assert.areEqual( "Ufront", mvm3.get("project") );
		Assert.areEqual( "web framework", mvm1.get("type") );
		Assert.areEqual( "web framework", mvm2.get("type") );
		Assert.areEqual( "web framework", mvm3.get("type") );
		Assert.areEqual( 2, [ for (k in mvm1.keys()) k ].length );
		Assert.areEqual( 2, [ for (k in mvm2.keys()) k ].length );
		Assert.areEqual( 2, [ for (k in mvm3.keys()) k ].length );
		mvm1.add( "project","Dart" );
		Assert.areEqual( 2, mvm1.getAll("project").length );
		Assert.areEqual( "Dart", mvm1.get("project") );
	}
	
	@Test
	public function combine():Void
	{
		var mvm1:MultiValueMap<String> = [ "value"=>["100","200"] ];
		var mvm2:MultiValueMap<String> = [ "project"=>"Dart", "value"=>"300", "author"=>"Jason" ];
		var combined = MultiValueMap.combine( [stringMap, mvm1, mvm2] );
		
		Assert.isTrue( combined.exists("project") );
		Assert.areEqual( 3, combined.getAll("project").length );
		Assert.areEqual( "Dart", combined.get("project") );
		
		Assert.isTrue( combined.exists("type") );
		Assert.areEqual( 1, combined.getAll("type").length );
		Assert.areEqual( "web framework", combined.get("type") );
		
		Assert.isTrue( combined.exists("value") );
		Assert.areEqual( 3, combined.getAll("value").length );
		Assert.areEqual( "300", combined.get("value") );
		
		Assert.isTrue( combined.exists("author") );
		Assert.areEqual( "Jason", combined.get("author") );
		Assert.areEqual( 1, combined.getAll("author").length );
	}
	
	@Test
	public function testStraightCasts():Void
	{
		var sm1:StringMap<Array<String>> = stringMap;
		var sm2:Map<String,Array<String>> = stringMap;
		Assert.areEqual( 2, sm1.get("project").length );
		Assert.areEqual( 2, sm2.get("project").length );
		
		var map1:Map<String,Array<Int>> = [ "value"=>[0,20] ];
		var map2:StringMap<Array<Int>> = map1;
		emptyMap = map1;
		Assert.areEqual( 20, emptyMap.get("value") );
		Assert.areEqual( 2, emptyMap.getAll("value").length );
		Assert.areEqual( 0, emptyMap.getAll("value")[0] );
		emptyMap = map2;
		Assert.areEqual( 20, emptyMap.get("value") );
		Assert.areEqual( 2, emptyMap.getAll("value").length );
		Assert.areEqual( 0, emptyMap.getAll("value")[0] );
	}
}