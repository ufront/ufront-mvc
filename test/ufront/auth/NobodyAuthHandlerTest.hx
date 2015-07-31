package ufront.auth;

import utest.Assert;
import ufront.auth.NobodyAuthHandler;
import ufront.auth.YesBossAuthHandler;
import ufront.auth.YesBossAuthHandlerTest;
import ufront.auth.AuthError;
import ufront.auth.*;
import tink.core.Error;
using ufront.test.TestUtils;

class NobodyAuthHandlerTest {

	public function new() { }

	public function beforeClass():Void {}

	public function afterClass():Void {}

	public function setup():Void {}

	public function teardown():Void {}

	public function testNobody():Void {
		var nobodyAuth:UFAuthHandler = new NobodyAuthHandler();
		Assert.isFalse( nobodyAuth.isLoggedIn() );

		try {
			nobodyAuth.requireLogin();
			Assert.fail( 'Expected error to be thrown' );
		}
		catch (e:TypedError<Dynamic>) {
			Assert.same( e.data, ANotLoggedIn );
			Assert.is( e.data, AuthError );
		}
		catch (e:Dynamic) Assert.fail( 'Wrong error type' );

		Assert.isFalse( nobodyAuth.isLoggedInAs(new BossUser()) );

		var boss = new BossUser();
		try {
			nobodyAuth.requireLoginAs(boss);
			Assert.fail( 'Expected error to be thrown' );
		}
		catch (e:TypedError<Dynamic>) {
			Assert.is( e.data, AuthError );
			Assert.equals( ""+e.data, ""+ANotLoggedInAs(boss) );
		}
		catch (e:Dynamic) Assert.fail( 'Wrong error type' );

		Assert.isFalse( nobodyAuth.hasPermission(HaveCake) );
		Assert.isFalse( nobodyAuth.hasPermissions([HaveCake,EatCake] ) );

		try {
			nobodyAuth.requirePermission(EatCake);
			Assert.fail( 'Expected error to be thrown' );
		}
		catch (e:TypedError<Dynamic>) {
			Assert.is( e.data, AuthError );
			Assert.same( e.data, ANoPermission(EatCake) );
		}
		catch (e:Dynamic) Assert.fail( 'Wrong error type' );


		try {
			nobodyAuth.requirePermissions([HaveCake,EatCake]);
			Assert.fail( 'Expected error to be thrown' );
		}
		catch (e:TypedError<Dynamic>)  {
			Assert.is( e.data, AuthError );
			Assert.same( e.data, ANoPermission(HaveCake) );
		}
		catch (e:Dynamic) Assert.fail( 'Wrong error type' );

		Assert.equals( null, nobodyAuth.currentUser );
	}
}
