package ufront.web.context;

import utest.Assert;
import ufront.web.context.HttpResponse;
import haxe.ds.StringMap;
import thx.collection.HashList;
import haxe.io.Bytes;

class HttpResponseTest 
{
	var instance:HttpResponse; 
	
	public function new() 
	{
		
	}
	
	public function beforeClass():Void {}
	
	public function afterClass():Void {}
	
	public function setup():Void {}
	
	public function teardown():Void {}
	
	public function testNew() {
		var response = new HttpResponse();
		Assert.equals( "text/html", response.contentType );
		Assert.equals( "utf-8", response.charset );
		Assert.equals( 200, response.status );
		Assert.is( response.getBuffer(), String );
		Assert.is( response.getCookies(), StringMap );
		Assert.is( response.getHeaders(), HashList );
	}
	
	public function testFlush() {
		var response = new HttpResponseMock();
		response.write( "hello" );
		Assert.equals( 0, response.flushCalled );
		response.flush();
		Assert.equals( 1, response.flushCalled );
		response.flush();
		Assert.equals( 1, response.flushCalled );
		
		var response = new HttpResponseMock();
		response.write( "hello" );
		response.preventFlush();
		response.flush();
		Assert.equals( 0, response.flushCalled );
	}
	
	public function testClear() {
		var response = new HttpResponseMock();
		response.write( "hello" );
		response.setCookie( new HttpCookie("cookiename","cookievalue") );
		response.setHeader( "headername", "headervalue" );
		
		Assert.equals( "hello", response.getBuffer() );
		Assert.equals( true, response.getCookies().exists("cookiename") );
		Assert.equals( true, response.getHeaders().exists("headername") );
		
		response.clear();
		
		Assert.equals( "", response.getBuffer() );
		Assert.equals( false, response.getCookies().exists("cookiename") );
		Assert.equals( false, response.getHeaders().exists("headername") );
	}
	
	public function testWrite() {
		var response = new HttpResponseMock();
		response.write( "hello" );
		Assert.equals( "hello", response.getBuffer() );
		response.writeChar( "!".charCodeAt(0) );
		Assert.equals( "hello!", response.getBuffer() );
		response.clearContent();
		
		var bytes:Bytes = Bytes.ofString( "My String" );
		response.writeBytes( bytes, 3, 6 );
		Assert.equals( "String", response.getBuffer() );
	}
	
	public function testHeaders() {
		var response = new HttpResponseMock();
		response.setHeader( "headername", "headervalue" );
		Assert.equals( true, response.getHeaders().exists("headername") );
		Assert.equals( "headervalue", response.getHeaders().get("headername") );
		response.clearHeaders();
		Assert.equals( false, response.getHeaders().exists("headername") );
	}
	
	public function testCookies() {
		var response = new HttpResponseMock();
		response.setCookie( new HttpCookie("cookiename","cookievalue") );
		Assert.equals( true, response.getCookies().exists("cookiename") );
		response.clearCookies();
		Assert.equals( false, response.getCookies().exists("cookiename") );
	}
	
	public function testRedirects() {
		var response = new HttpResponseMock();
		
		response.redirect( "http://haxe.org" );
		
		Assert.isTrue( response.isRedirect() );
		Assert.isFalse( response.isPermanentRedirect() );
		Assert.equals( "http://haxe.org", response.redirectLocation );
		Assert.equals( 302, response.status );
		
		response.clear();
		
		Assert.isFalse( response.isRedirect() );
		Assert.isFalse( response.isPermanentRedirect() );
		Assert.equals( null, response.redirectLocation );
		Assert.equals( 200, response.status );
		
		response.permanentRedirect( "http://ufront.net" );
		
		Assert.isTrue( response.isRedirect() );
		Assert.isTrue( response.isPermanentRedirect() );
		Assert.equals( "http://ufront.net", response.redirectLocation );
		Assert.equals( 301, response.status );
		
		response.redirectLocation = "http://github.com/";
		Assert.equals( "http://github.com/", response.getHeaders().get("Location") );
	}
	
	public function testContentType() {
		var response = new HttpResponseMock();
		response.contentType = "text/plain";
		Assert.equals( "text/plain", response.getHeaders().get("Content-type") );
		response.contentType = null;
		Assert.equals( "text/html", response.getHeaders().get("Content-type") );
	}
}

class HttpResponseMock extends HttpResponse {
	public var flushCalled:Int = 0;
	override public function flush() {
		if (_flushed) return;
		_flushed = true;
		flushCalled++;
	}
}