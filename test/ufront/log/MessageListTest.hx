package ufront.log;

import utest.Assert;
import ufront.log.Message;

class MessageListTest {
	public function new() {}

	public function beforeClass():Void {}

	public function afterClass():Void {}

	public function setup():Void {}

	public function teardown():Void {}

	public function testMessageList():Void {
		var message1 = createMessage( "Hello Theo", Trace );
		var message2 = createMessage( 400, Error );

		var emptyMessageList = new MessageList();
		emptyMessageList.push( message1 );
		emptyMessageList.push( message2 );

		var messageArray1 = [];
		var messageArray2 = [];
		function onMessageFn(m:Message) messageArray2.push(m);
		var messageList = new MessageList( messageArray1, onMessageFn );

		Assert.equals( messageArray1, messageList.messages );
		Assert.equals( onMessageFn, messageList.onMessage );
		messageList.push( message1 );
		Assert.equals( 1, messageArray1.length );
		Assert.equals( 1, messageArray2.length );
		messageList.push( message2 );
		Assert.equals( 2, messageArray1.length );
		Assert.equals( 2, messageArray2.length );
		Assert.equals( "Hello Theo", messageArray1[0].msg );
		Assert.equals( Error, messageArray2[1].type );
	}

	function createMessage( msg:Dynamic, type:MessageType, ?pos:haxe.PosInfos ) {
		return { msg: msg, pos: pos, type: type };
	}
}
