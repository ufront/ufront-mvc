package ufront.web.url;

import utest.Assert;
import ufront.web.url.VirtualUrl;

class VirtualUrlTest {
	var instance:VirtualUrl;

	public function new() {}

	public function beforeClass():Void {}

	public function afterClass():Void {}

	public function setup():Void {}

	public function teardown():Void {}

	public function testVirtualUrl():Void {
		var u1 = VirtualUrl.parse( 'home' );
		Assert.equals( 1, u1.segments.length );
		Assert.equals( "home", u1.segments[0] );
		Assert.equals( "/home", u1.toString() );
		Assert.isFalse( u1.isPhysical );

		var u2 = VirtualUrl.parse( '/home' );
		Assert.equals( 1, u2.segments.length );
		Assert.equals( "home", u2.segments[0] );
		Assert.isFalse( u2.isPhysical );
		Assert.equals( "/home", u2.toString() );

		var u3 = VirtualUrl.parse( '~/home' );
		Assert.equals( 1, u3.segments.length );
		Assert.equals( "home", u3.segments[0] );
		Assert.isTrue( u3.isPhysical );
		Assert.equals( "/home", u3.toString() );

		var u3 = VirtualUrl.parse( '/home', true );
		Assert.equals( 1, u3.segments.length );
		Assert.equals( "home", u3.segments[0] );
		Assert.isTrue( u3.isPhysical );
		Assert.equals( "/home", u3.toString() );
	}
}
