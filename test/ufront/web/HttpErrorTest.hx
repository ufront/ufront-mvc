package ufront.web;

import utest.Assert;
import ufront.web.HttpError;
import tink.core.Error;

class HttpErrorTest {
	public function new() {}

	public function beforeClass():Void {}

	public function afterClass():Void {}

	public function setup():Void {}

	public function teardown():Void {}

	public function testWrap():Void {
		var error = new Error( ServiceUnavailable, "Not enough sleep" );
		var wrapped1 = HttpError.wrap( error );
		Assert.is( wrapped1, Error );
		Assert.equals( error, wrapped1 );
		Assert.equals( 503, wrapped1.code );
		Assert.equals( "Not enough sleep", wrapped1.message );

		var error2 = "I am a String!";
		var wrapped2 = HttpError.wrap( error2 );
		Assert.is( wrapped2, Error );
		Assert.equals( 500, wrapped2.code );
		Assert.equals( "Internal Server Error", wrapped2.message );
		Assert.equals( "I am a String!", wrapped2.data );
	}

	public function testErrorSetup():Void {
		var e = HttpError.badRequest();
		Assert.equals( 400, e.code );
		Assert.equals( "Bad Request", e.message );

		var e = HttpError.internalServerError();
		Assert.equals( 500, e.code );
		Assert.equals( "Internal Server Error", e.message );
		Assert.equals( null, e.data );

		var e = HttpError.internalServerError("Not Logged In", "Bad Password");
		Assert.equals( 500, e.code );
		Assert.equals( "Not Logged In", e.message );
		Assert.equals( "Bad Password", e.data );

		var e = HttpError.methodNotAllowed();
		Assert.equals( 405, e.code );
		Assert.equals( "Method Not Allowed", e.message );

		var e = HttpError.pageNotFound();
		Assert.equals( 404, e.code );
		Assert.equals( "Page Not Found", e.message );

		var e = HttpError.unauthorized();
		Assert.equals( 401, e.code );
		Assert.equals( "Unauthorized Access", e.message );

		var e = HttpError.unauthorized("NOT ALLOWED");
		Assert.equals( 401, e.code );
		Assert.equals( "NOT ALLOWED", e.message );

		var e = HttpError.unprocessableEntity();
		Assert.equals( 422, e.code );
		Assert.equals( "Unprocessable Entity", e.message );
	}

	public function testFakePosition():Void {
		var p = HttpError.fakePosition( this, "myMethod", [3.14] );
		Assert.equals( "ufront.web.HttpErrorTest", p.className );
		Assert.equals( "myMethod", p.methodName );
		Assert.equals( 3.14, p.customParams[0] );
	}
}
