package ufront.web.url;

import utest.Assert;
import ufront.web.url.PartialUrl;

class PartialUrlTest {
	var instance:PartialUrl;

	public function new() {}

	public function beforeClass():Void {}

	public function afterClass():Void {}

	public function setup():Void {}

	public function teardown():Void {}

	public function testPartialUrl():Void {
		var u1 = PartialUrl.parse( '/' );
		Assert.equals( 0, u1.segments.length );
		Assert.equals( 0, u1.query.length );
		Assert.isNull( u1.fragment );
		Assert.equals( "/", u1.toString() );

		u1.segments.push( "index.html" );
		Assert.equals( "/index.html", u1.toString() );

		var u2 = PartialUrl.parse( '/some/website/page.html' );
		Assert.equals( 3, u2.segments.length );
		Assert.equals( 0, u2.query.length );
		Assert.isNull( u2.fragment );
		Assert.equals( "some", u2.segments[0] );
		Assert.equals( "website", u2.segments[1] );
		Assert.equals( "page.html", u2.segments[2] );
		Assert.equals( "/some/website/page.html", u2.toString() );

		u2.segments[0] = "my";
		Assert.equals( "/my/website/page.html", u2.toString() );

		var u3 = PartialUrl.parse( '/index.php?a=1&b=2&c=Jason%20%26%20Anna' );
		Assert.equals( 1, u3.segments.length );
		Assert.equals( 3, u3.query.length );
		Assert.isNull( u3.fragment );
		Assert.equals( "1", u3.query[0].value );
		Assert.equals( "2", u3.query[1].value );
		Assert.equals( "Jason%20%26%20Anna", u3.query[2].value );
		Assert.isTrue( u3.query[0].encoded );
		Assert.isTrue( u3.query[1].encoded );
		Assert.isTrue( u3.query[2].encoded );
		Assert.equals( "/index.php?a=1&b=2&c=Jason%20%26%20Anna", u3.toString() );

		u3.query.push({ name:"d", value:"Michael & Monica", encoded:false });
		Assert.equals( "/index.php?a=1&b=2&c=Jason%20%26%20Anna&d=Michael%20%26%20Monica", u3.toString() );

		var u4 = PartialUrl.parse( "/index.php?language=haxe&language=js&language=php" );
		Assert.equals( 1, u4.segments.length );
		Assert.equals( 3, u4.query.length );
		Assert.isNull( u4.fragment );
		Assert.equals( "haxe", u4.query[0].value );
		Assert.equals( "js", u4.query[1].value );
		Assert.equals( "php", u4.query[2].value );
		Assert.equals( "/index.php?language=haxe&language=js&language=php", u4.toString() );

		u4.query.push({ name:"framework", value:"Ufront", encoded:false });
		u4.query.push({ name:"framework", value:"OpenFL", encoded:false });
		Assert.equals( 5, u4.query.length );
		Assert.equals( "/index.php?language=haxe&language=js&language=php&framework=Ufront&framework=OpenFL", u4.toString() );

		u4.query.push({ name:"language", value:"c++", encoded:false });
		Assert.equals( 6, u4.query.length );
		Assert.equals( "/index.php?language=haxe&language=js&language=php&framework=Ufront&framework=OpenFL&language=c%2B%2B", u4.toString() );

		var u5 = PartialUrl.parse("/#");
		Assert.equals( 0, u5.segments.length );
		Assert.equals( 0, u5.query.length );
		Assert.equals( "", u5.fragment );
		Assert.equals( "/#", u5.toString() );

		u5.fragment = null;
		Assert.equals( "/", u5.toString() );

		var u6 = PartialUrl.parse("/index.html#content");
		Assert.equals( 1, u6.segments.length );
		Assert.equals( 0, u6.query.length );
		Assert.equals( "content", u6.fragment );
		Assert.equals( "/index.html#content", u6.toString() );

		u6.fragment = "menu";
		Assert.equals( "/index.html#menu", u6.toString() );
	}
}
