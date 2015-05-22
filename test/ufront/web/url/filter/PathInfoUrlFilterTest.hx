package ufront.web.url.filter;

import utest.Assert;
import ufront.web.url.filter.PathInfoUrlFilter;

class PathInfoUrlFilterTest {
	var instance:PathInfoUrlFilter;

	public function new() {}

	public function beforeClass():Void {}

	public function afterClass():Void {}

	public function setup():Void {}

	public function teardown():Void {}

	public function testFilterIn():Void {
		// Basic case
		var f1 = new PathInfoUrlFilter( "index.n", true );
		var u1 = PartialUrl.parse( "index.n/hello/world/" );
		f1.filterIn( u1 );
		Assert.equals( "/hello/world/", u1.toString() );

		// Check it does not interfere with other parts.
		var u2 = PartialUrl.parse( "index.n/hello/world/index.html?source=google#content" );
		f1.filterIn( u2 );
		Assert.equals( "/hello/world/index.html?source=google#content", u2.toString() );
	}

	public function testFilterOut():Void {
		// Basic case
		var f1 = new PathInfoUrlFilter( "index.n", true );
		var u1 = VirtualUrl.parse( "/hello/world/" );
		f1.filterOut( u1 );
		Assert.equals( "/index.n/hello/world/", u1.toString() );

		// Check it does not interfere with other parts.
		var u2 = VirtualUrl.parse( "/hello/world/index.html?source=google#content" );
		f1.filterOut( u2 );
		Assert.equals( "/index.n/hello/world/index.html?source=google#content", u2.toString() );

		// Test `useCleanRoot`
		var filterClean = new PathInfoUrlFilter( "index.php", true );
		var filterNotClean = new PathInfoUrlFilter( "index.php", false );
		var u3 = VirtualUrl.parse( "/" );
		var u4 = VirtualUrl.parse( "/" );
		filterClean.filterOut( u3 );
		filterNotClean.filterOut( u4 );
		Assert.equals( "/", u3.toString() );
		Assert.equals( "/index.php", u4.toString() );

		// Test a "physical" URL.
		var u5 = VirtualUrl.parse( "~/js/jquery.js" );
		f1.filterOut( u5 );
		Assert.equals( "/js/jquery.js", u5.toString() );
	}
}
