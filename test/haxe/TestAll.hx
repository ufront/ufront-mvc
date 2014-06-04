package haxe;

import utest.Assert;
import utest.Runner;

class TestAll
{
	public static function addTests( runner:Runner ) {
		haxe.remoting.TestAll.addTests( runner );
	}
}
