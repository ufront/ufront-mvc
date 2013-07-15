package ufront.module;

import ufront.application.HttpApplication;

/**
	Interface for a HttpModule, that can be added to `ufront.application.HttpApplication`

	@author Franco Ponticelli
**/
interface IHttpModule
{
	public function init(application : HttpApplication) : Void;
	public function dispose() : Void;
}