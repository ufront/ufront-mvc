package ufront.web.url.filter;

import utest.Assert;
import ufront.web.url.filter.DirectoryUrlFilter;

class DirectoryUrlFilterTest {
	var instance:DirectoryUrlFilter;

	public function new() {}

	public function beforeClass():Void {}

	public function afterClass():Void {}

	public function setup():Void {}

	public function teardown():Void {}

	public function testFilterIn():Void {
		// Basic case
		var f1 = new DirectoryUrlFilter( "/path/to/app/" );
		var u1 = PartialUrl.parse( "/path/to/app/blog/2015/March/34/Hello.html" );
		f1.filterIn( u1 );
		Assert.equals( "/blog/2015/March/34/Hello.html", u1.toString() );

		// Blank case
		var f2 = new DirectoryUrlFilter( "" );
		var u2 = PartialUrl.parse( "/blog/2015/March/34/Hello.html" );
		f2.filterIn( u2 );
		Assert.equals( "/blog/2015/March/34/Hello.html", u2.toString() );

		// Leading and trailing slashes.
		var f3 = new DirectoryUrlFilter( "path/to/app" );
		var u3 = PartialUrl.parse( "/path/to/app/blog/2015/March/34/Hello.html" );
		f3.filterIn( u3 );
		Assert.equals( "/blog/2015/March/34/Hello.html", u3.toString() );
	}

	public function testFilterOut():Void {

		// Basic case
		var f1 = new DirectoryUrlFilter( "/path/to/app/" );
		var u1 = VirtualUrl.parse( "/blog/2015/March/34/Hello.html" );
		f1.filterOut( u1 );
		Assert.equals( "/path/to/app/blog/2015/March/34/Hello.html", u1.toString() );

		// Blank case
		var f2 = new DirectoryUrlFilter( "" );
		var u2 = VirtualUrl.parse( "/blog/2015/March/34/Hello.html" );
		f2.filterOut( u2 );
		Assert.equals( "/blog/2015/March/34/Hello.html", u2.toString() );

		// Physical URL
		var f3 = new DirectoryUrlFilter( "/path/to/app/" );
		var u3 = VirtualUrl.parse( "~/js/jquery.js" );
		f3.filterOut( u3 );
		Assert.equals( "/path/to/app/js/jquery.js", u3.toString() );
	}
}
