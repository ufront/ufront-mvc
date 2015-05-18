package ufront.log;

import utest.Assert;
import ufront.log.RemotingLogger;
import ufront.log.Message;
import ufront.app.UFLogHandler;
using ufront.test.TestUtils;
using thx.Objects;

class RemotingLoggerTest {

	public function new() {}

	public function beforeClass():Void {}

	public function afterClass():Void {}

	public function setup():Void {}

	public function teardown():Void {}

	var fakePosInfos:Array<haxe.PosInfos> = [{
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
		customParams: [1,2],
	}];

	@:access(ufront.log.RemotingLogger)
	public function testFormatMessage():Void {
		var msg1 = { msg:null, type:Trace, pos:fakePosInfos[0] };
		var msg2 = { msg:"Hello", type:Log, pos:fakePosInfos[1] };

		var result1 = RemotingLogger.formatMessage( msg1 );
		var result2 = RemotingLogger.formatMessage( msg2 );

		Assert.isTrue( StringTools.startsWith(result1,"hxt") );
		Assert.isTrue( StringTools.startsWith(result2,"hxt") );
		var unserialized1 = haxe.Unserializer.run( result1.substr(3) );
		var unserialized2 = haxe.Unserializer.run( result2.substr(3) );
		Assert.same( msg1, unserialized1 );
		Assert.same( msg2, unserialized2 );
	}

	public function testLog() {
		var ctx = "/".mockHttpContext();
		ctx.request.clientHeaders.set( "X-Ufront-Remoting", "1" );
		ctx.request.clientHeaders.set( "X-Haxe-Remoting", "1" );

		var pageContent = "HXR Remoting Response";
		ctx.response.contentType = "application/x-haxe-remoting";
		ctx.response.write( pageContent );
		ctx.messages.push({ msg: "Hello", type:Trace, pos:fakePosInfos[0] });
		ctx.messages.push({ msg: "World", type:Log, pos:fakePosInfos[0] });

		var appMessages = [];
		appMessages.push({ msg: "Goodbye", type:Warning, pos:fakePosInfos[1] });
		appMessages.push({ msg: "Space", type:Error, pos:fakePosInfos[1] });

		var remotingLogger:UFLogHandler = new RemotingLogger();
		remotingLogger.log( ctx, appMessages );

		// Let's check if that worked
		var buffer = ctx.response.getBuffer();
		Assert.equals( pageContent, buffer.substr(0,pageContent.length) );
		var expectedNumber = #if debug 4 #else 2 #end;
		var numberOfLogs = buffer.split("\nhxt").length - 1;
		Assert.equals( expectedNumber, numberOfLogs );

		// Now let's check that it doesn't do anything if we have a different content type.

		var pageContent = "<html>Hello!</html>";
		ctx.response.clear();
		ctx.response.contentType = "text/html";
		ctx.response.write( pageContent );

		remotingLogger.log( ctx, appMessages );

		Assert.equals( pageContent, ctx.response.getBuffer() );
	}
}
