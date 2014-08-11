package ufront.web.context;

import utest.Assert;
import ufront.web.context.HttpRequest;
import ufront.core.MultiValueMap;
using mockatoo.Mockatoo;

class HttpRequestTest {
	public function new() {}

	public function beforeClass():Void {}

	public function afterClass():Void {}

	public function setup():Void {}

	public function teardown():Void {}

	public function testParams():Void {
		var post:MultiValueMap<String> = ["post"=>["PostVal"],"letter"=>["P1","P2"]];
		var query:MultiValueMap<String> = ["query"=>"QueryVal","letter"=>"Q"];
		var cookies:MultiValueMap<String> = ["cookies"=>"CookieVal","letter"=>"C"];
		var instance = HttpRequest.mock();
		instance.post.returns( post );
		instance.query.returns( query );
		instance.cookies.returns( cookies );
		instance.params.callsRealMethod();
		Assert.equals( "PostVal", instance.params["post"] );
		Assert.equals( "QueryVal", instance.params["query"] );
		Assert.equals( "CookieVal", instance.params["cookies"] );
		Assert.same( "C,Q,P1,P2", instance.params.getAll("letter").join(",") );
		Assert.equals( "P2", instance.params["letter"] );
	}

	public function testIsMultiPart():Void {
		var clientHeaders:MultiValueMap<String> = [ "Content-Type"=>"application/x-www-form-urlencoded; charset=UTF-8" ];
		var instance = HttpRequest.mock();
		instance.clientHeaders.returns( clientHeaders );
		instance.isMultipart().callsRealMethod();
		Assert.isFalse( instance.isMultipart() );

		var clientHeaders:MultiValueMap<String> = [ "Content-Type"=>"multipart/form-data; boundary=something" ];
		var instance = HttpRequest.mock();
		instance.clientHeaders.returns( clientHeaders );
		instance.isMultipart().callsRealMethod();
		Assert.isTrue( instance.isMultipart() );
	}
}
