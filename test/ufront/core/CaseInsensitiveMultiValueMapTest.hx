package ufront.core;
import haxe.ds.StringMap;

import utest.Assert;
import ufront.core.MultiValueMap;
import ufront.core.CaseInsensitiveMultiValueMap;

class MultiValueMapTest {
	public function new() {}

	public function beforeClass():Void {}

	public function afterClass():Void {}

	public function setup():Void {}

	public function testCaseSensitivity():Void {
		var mvm1 = new MultiValueMap();
		var mvm2 = new CaseInsensitiveMultiValueMap();

		mvm1.add( 'X-Haxe-Remoting', 1 );
		mvm1.add( 'X-HAXE-REMOTING', 2 );
		mvm1.add( 'x-haxe-remoting', 3 );

		mvm2.add( 'X-Haxe-Remoting', 1 );
		mvm2.add( 'X-HAXE-REMOTING', 2 );
		mvm2.add( 'x-haxe-remoting', 3 );

		Assert.equals( 1, mvm1.getAll('X-Haxe-Remoting').length );
		Assert.equals( 1, mvm1.getAll('X-HAXE-REMOTING').length );
		Assert.equals( 1, mvm1.getAll('x-haxe-remoting').length );

		Assert.equals( 3, mvm1.getAll('X-Haxe-Remoting').length );
		Assert.equals( 3, mvm1.getAll('X-HAXE-REMOTING').length );
		Assert.equals( 3, mvm1.getAll('x-haxe-remoting').length );

		Assert.isFalse( mvm1.exists('x-haxe-REMOTING') );
		Assert.isTrue( mvm2.exists('x-haxe-REMOTING') );
	}
}
