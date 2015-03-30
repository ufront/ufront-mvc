package ufront.log;

import utest.Assert;
import ufront.log.BrowserConsoleLogger;
import ufront.log.Message;
import ufront.app.UFLogHandler;
using ufront.test.TestUtils;

class BrowserConsoleLoggerTest {
	public function new() {}

	public function beforeClass():Void {}

	public function afterClass():Void {}

	public function setup():Void {}

	public function teardown():Void {}

	var fakePosInfos = [{
		fileName: "Cls.hx",
		lineNumber: 1,
		className: "Cls",
		methodName: "method",
		customParams: null,
	},{
		fileName: "Cls.hx",
		lineNumber: 2,
		className: "Cls",
		methodName: "method",
		customParams: ["so","good"],
	}];

	public function testFormatMessage():Void {
		var msg1 = { msg:"Haxe", type:Trace, pos:fakePosInfos[0] };
		var msg2 = { msg:"Has", type:Log, pos:fakePosInfos[0] };
		var msg3 = { msg:"Macros", type:Warning, pos:fakePosInfos[0] };
		var msg4 = { msg:"!!11", type:Error, pos:fakePosInfos[1] };

		var result1 = BrowserConsoleLogger.formatMessage( msg1 );
		var result2 = BrowserConsoleLogger.formatMessage( msg2 );
		var result3 = BrowserConsoleLogger.formatMessage( msg3 );
		var result4 = BrowserConsoleLogger.formatMessage( msg4 );

		// Test the types are correct, that the positions are shown,
		// it is URI encoded and that the extra parameters display correctly.
		var expectedMsg1 = StringTools.urlEncode("Cls.method(1): Haxe");
		var expectedMsg2 = StringTools.urlEncode("Cls.method(1): Has");
		var expectedMsg3 = StringTools.urlEncode("Cls.method(1): Macros");
		var expectedMsg4 = StringTools.urlEncode("Cls.method(2): !!11, so, good");
		Assert.equals( 'console.log(decodeURIComponent("$expectedMsg1"))', result1 );
		Assert.equals( 'console.info(decodeURIComponent("$expectedMsg2"))', result2 );
		Assert.equals( 'console.warn(decodeURIComponent("$expectedMsg3"))', result3 );
		Assert.equals( 'console.error(decodeURIComponent("$expectedMsg4"))', result4 );
	}

	public function testLog() {
		var ctx = "/".mockHttpContext();
		var before = '<html><body>Hello!';
		var after = '</body></html>';
		var pageContent = before+after;

		ctx.response.contentType = "text/html";
		ctx.response.write( pageContent );
		ctx.messages.push({ msg: "Hello", type:Trace, pos:fakePosInfos[0] });
		ctx.messages.push({ msg: "World", type:Log, pos:fakePosInfos[0] });

		var appMessages = [];
		appMessages.push({ msg: "Goodbye", type:Warning, pos:fakePosInfos[1] });
		appMessages.push({ msg: "Space", type:Error, pos:fakePosInfos[1] });

		var browserConsoleLogger:UFLogHandler = new BrowserConsoleLogger();
		browserConsoleLogger.log( ctx, appMessages );

		// Let's check if that worked on the server.
		// The client prints directly to the JS console log functions, so it's a bit hard to verify here.
		#if server
			var buffer = ctx.response.getBuffer();
			Assert.equals( before, buffer.substr(0,before.length) );
			Assert.equals( after, buffer.substr(buffer.length-after.length) );
			var scriptOpener = '\n<script type="text/javascript">\n';
			Assert.equals( scriptOpener, buffer.substr(before.length,scriptOpener.length) );
			var numberOfLogs = buffer.split("console.").length - 1;
			var expectedNumber = #if debug 4 #else 2 #end;
			Assert.equals( expectedNumber, numberOfLogs );
		#end

		// Now let's check that it doesn't do anything if we have a different content type.

		var pageContent = "{ 'word': 'Hello!' }";
		ctx.response.clear();
		ctx.response.contentType = "application/json";
		ctx.response.write( pageContent );

		browserConsoleLogger.log( ctx, appMessages );

		Assert.equals( pageContent, ctx.response.getBuffer() );
	}
}
