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
		Assert.equals("value", cookie.description());

		cookie.expires = Date.fromString("2001-01-01");
		Assert.equals("value; expires=Mon, 01-Jan-2001 00:00:00 GMT", cookie.description());

		cookie.domain = "example.com";
		Assert.equals("value; expires=Mon, 01-Jan-2001 00:00:00 GMT; domain=example.com", cookie.description());

		cookie.path = "/path";
		Assert.equals("value; expires=Mon, 01-Jan-2001 00:00:00 GMT; domain=example.com; path=/path", cookie.description());

		cookie.secure = true;
		Assert.equals("value; expires=Mon, 01-Jan-2001 00:00:00 GMT; domain=example.com; path=/path; secure", cookie.description());
	}
}