package ufront.core;

import massive.munit.util.Timer;
import massive.munit.Assert;
import massive.munit.async.AsyncFactory;
import ufront.core.AcceptEither;

class AcceptEitherTest 
{
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
	public function testLeftFromCast():Void
	{
		var val:AcceptEither<String,Int> = "Hello";
		switch val.type {
			case Left(str): Assert.areEqual( "Hello", str );
			default: Assert.fail( "Wrong type" );
		}
	}
	
	@Test
	public function testRightFromCast():Void
	{
		var val:AcceptEither<String,Int> = 3;
		switch val.type {
			case Right(int): Assert.areEqual( 3, int );
			default: Assert.fail( "Wrong type" );
		}
	}
	
	@Test
	public function testValue():Void
	{
		var v1:AcceptEither<String,Int> = 3;
		Assert.areEqual( 3, v1.value );
		var v1:AcceptEither<String,Int> = "Hello";
		Assert.areEqual( "Hello", v1.value );
	}
}