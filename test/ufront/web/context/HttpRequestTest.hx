package ufront.web.context;

import utest.Assert;
import ufront.web.context.HttpRequest;
import ufront.test.MockHttpRequest;
import ufront.core.*;

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
		var instance = new MockHttpRequest();
		instance.setPost( post );
		instance.setQuery( query );
		instance.setCookies( cookies );
		Assert.equals( "PostVal", instance.params["post"] );
		Assert.equals( "QueryVal", instance.params["query"] );
		Assert.equals( "CookieVal", instance.params["cookies"] );
		Assert.same( "C,Q,P1,P2", instance.params.getAll("letter").join(",") );
		Assert.equals( "P2", instance.params["letter"] );
	}

	public function testIsMultiPart():Void {
		var clientHeaders = new CaseInsensitiveMultiValueMap();
		clientHeaders.set( "Content-Type", "application/x-www-form-urlencoded; charset=UTF-8" );
		var instance = new MockHttpRequest();
		instance.setClientHeaders( clientHeaders );
		Assert.isFalse( instance.isMultipart() );

		var clientHeaders = new CaseInsensitiveMultiValueMap();
		clientHeaders.set( "Content-Type", "multipart/form-data; boundary=something" );
		var instance = new MockHttpRequest();
		instance.setClientHeaders( clientHeaders );
		Assert.isTrue( instance.isMultipart() );
	}
}
