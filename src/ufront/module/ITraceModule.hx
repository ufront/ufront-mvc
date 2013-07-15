package ufront.module;

import haxe.PosInfos;
import ufront.application.HttpApplication;
import ufront.module.IHttpModule;

/**
	An interface defining a trace module.

	MvcApplication (ufront-mvc-classic) and UfrontApplication (ufront-mvc) will use every available trace module when `trace()` is called.
**/
interface ITraceModule extends IHttpModule {
	public function trace(msg : Dynamic, ?pos : PosInfos) : Void;
}