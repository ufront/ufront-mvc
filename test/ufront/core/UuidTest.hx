package ufront.core;

import utest.Assert;
import tink.CoreApi;
using ufront.core.Uuid;

class UuidTest {
	public function new() {}

	public function beforeClass():Void {}

	public function afterClass():Void {}

	public function setup():Void {}

	public function teardown():Void {}

	public function testIsValid():Void {
		Assert.isTrue( Uuid.isValid('61E0A715-59E2-4EEE-93E0-8EA99C4AFF32') );
		Assert.isTrue( Uuid.isValid('B2D1BCE0-9D79-499F-9850-F52CB9A0A428') );
		Assert.isTrue( Uuid.isValid('2A7A64F7-7ACA-46FF-830A-39ADC63C600D') );
		Assert.isTrue( Uuid.isValid('40A9A3E3-AA86-447B-98E6-74E77D28D43D') );
		Assert.isTrue( Uuid.isValid('5515C9CA-EEB2-40FB-9E20-4CD920DFEB86') );
	}

	public function testCreate():Void {
		for ( i in 0...10 ) {
			Assert.isTrue( Uuid.isValid(Uuid.create()) );
		}
	}
}
