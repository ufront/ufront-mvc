package ufront.web;

import utest.Assert;
import ufront.web.HttpCookie;

class HttpCookieTest {
	var instance:HttpCookie;

	public function new() {}

	public function beforeClass():Void {}

	public function afterClass():Void {}

	public function setup():Void {}

	public function teardown():Void {}

	public function testDescription() {
		
		var cookie = new HttpCookie("name", "value");
		Assert.equals("name", cookie.name);
		Assert.equals("value", cookie.description);

		cookie.expires = Date.fromTime( 3600*1000 ); // 1AM local time on Jan 1st 1970, GMT.
		Assert.equals("value; expires=Thu, 01-Jan-1970 01:00:00 GMT", cookie.description);

		cookie.domain = "example.com";
		Assert.equals("value; expires=Thu, 01-Jan-1970 01:00:00 GMT; domain=example.com", cookie.description);

		cookie.path = "/path";
		Assert.equals("value; expires=Thu, 01-Jan-1970 01:00:00 GMT; domain=example.com; path=/path", cookie.description);

		cookie.secure = true;
		Assert.equals("value; expires=Thu, 01-Jan-1970 01:00:00 GMT; domain=example.com; path=/path; secure", cookie.description);
	}
}
