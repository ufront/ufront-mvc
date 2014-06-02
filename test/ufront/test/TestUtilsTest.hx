package ufront.test;

import massive.munit.util.Timer;
import massive.munit.Assert;
import massive.munit.async.AsyncFactory;
import ufront.test.TestUtils;
import ufront.web.context.*;
import ufront.web.session.UFHttpSessionState;
import ufront.auth.UFAuthHandler;
import minject.Injector;
using mockatoo.Mockatoo;

class TestUtilsTest 
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
	public function mockHttpContext():Void
	{
		var mock1 = TestUtils.mockHttpContext( "/test/" );
		Assert.isNotNull( mock1 );
		Assert.isType( mock1.request, HttpRequest );
		Assert.isType( mock1.response, HttpResponse );
		Assert.isType( mock1.session, UFHttpSessionState );
		Assert.isType( mock1.auth, UFAuthHandler );
		Assert.areEqual( "/test/", mock1.request.uri );
		Assert.areEqual( "GET", mock1.request.httpMethod );
		Assert.areEqual( 0, [ for (k in mock1.request.params.keys()) k ].length );
		
		var mock2 = TestUtils.mockHttpContext( "/test/2/", "post", ["id"=>"3","page"=>"20"] );
		Assert.areEqual( "/test/2/", mock2.request.uri );
		Assert.areEqual( "POST", mock2.request.httpMethod );
		Assert.areEqual( 2, [ for (k in mock2.request.params.keys()) k ].length );
		Assert.areEqual( "3", mock2.request.params["id"] );
		Assert.areEqual( "20", mock2.request.params["page"] );
		
		var injector = new Injector();
		var request = HttpRequest.mock();
		request.uri.returns( "/test/3/" );
		var response = new HttpResponse();
		var session = new ufront.web.session.VoidSession();
		var auth = new ufront.auth.YesBossAuthHandler();
		var mock3 = TestUtils.mockHttpContext( "/test/3/", injector, request, response, session, auth );
		Assert.areEqual( "/test/3/", mock3.request.uri );
		Assert.areEqual( injector, mock3.injector );
		Assert.areEqual( request, mock3.request );
		Assert.areEqual( response, mock3.response );
		Assert.areEqual( session, mock3.session );
		Assert.areEqual( auth, mock3.auth );
	}
	
	@Test
	public function testRoute():Void
	{
		Assert.isTrue(false);
	}
	
	@Test
	public function assertSuccess():Void
	{
		Assert.isTrue(false);
	}
	
	@Test
	public function assertFailure():Void
	{
		Assert.isTrue(false);
	}
}