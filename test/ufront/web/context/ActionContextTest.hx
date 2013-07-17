package ufront.web.context;

import massive.munit.util.Timer;
import massive.munit.Assert;
import massive.munit.async.AsyncFactory;
import ufront.web.context.ActionContext;

class ActionContextTest 
{
	var instance:ActionContext; 
	
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
	public function testExample():Void
	{
		Assert.isTrue(false);
	}
}