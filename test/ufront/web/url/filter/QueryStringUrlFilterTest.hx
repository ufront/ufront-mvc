package ufront.web.url.filter;

import utest.Assert;
import ufront.web.url.filter.QueryStringUrlFilter;
import ufront.web.url.*;
using ufront.test.TestUtils;

class QueryStringUrlFilterTest {
	var instance:QueryStringUrlFilter;

	public function new() {}

	public function beforeClass():Void {}

	public function afterClass():Void {}

	public function setup():Void {}

	public function teardown():Void {}

	public function testFilterIn():Void {
		// Basic case
		var f1 = new QueryStringUrlFilter( "q", "index.n", true );
		var u1 = PartialUrl.parse( "index.n?q=/hello/world/" );
		f1.filterIn( u1 );
		Assert.equals( "/hello/world/", u1.toString() );

		// Check it does not interfere with other parts.
		var u2 = PartialUrl.parse( "index.n?q=/hello/world/index.html&source=google#content" );
		f1.filterIn( u2 );
		Assert.equals( "/hello/world/index.html?source=google#content", u2.toString() );
	}

	public function testFilterOut():Void {
		// Basic case
		var f1 = new QueryStringUrlFilter( "q", "index.n", true );
		var u1 = VirtualUrl.parse( "/hello/world/" );
		f1.filterOut( u1 );
		Assert.equals( "/index.n?q=/hello/world/", u1.toString() );

		// Check it does not interfere with other parts.
		var u2 = VirtualUrl.parse( "/hello/world/index.html?source=google#content" );
		f1.filterOut( u2 );
		Assert.equals( "/index.n?source=google&q=/hello/world/index.html#content", u2.toString() );

		// Test `useCleanRoot`
		var filterClean = new QueryStringUrlFilter( "q", "index.php", true );
		var filterNotClean = new QueryStringUrlFilter( "q", "index.php", false );
		var u3 = VirtualUrl.parse( "/" );
		var u4 = VirtualUrl.parse( "/" );
		filterClean.filterOut( u3 );
		filterNotClean.filterOut( u4 );
		Assert.equals( "/", u3.toString() );
		Assert.equals( "/index.php?q=/", u4.toString() );

		// Test a "physical" URL.
		var u5 = VirtualUrl.parse( "~/js/jquery.js" );
		f1.filterOut( u5 );
		Assert.equals( "/js/jquery.js", u5.toString() );
	}
}
