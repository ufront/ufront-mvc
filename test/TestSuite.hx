import massive.munit.TestSuite;

import ufront.core.FuturoidTest;
import ufront.core.AcceptEitherTest;
import ufront.core.MultiValueMapTest;
import ufront.core.SyncTest;
import ufront.app.UfrontApplicationTest;
import ufront.app.HttpApplicationTest;
import ufront.handler.ErrorPageHandlerTest;
import ufront.handler.RemotingHandlerTest;
import ufront.handler.MVCHandlerTest;
import ufront.handler.DispatchHandlerTest;
import ufront.log.FileLoggerTest;
import ufront.log.MessageTest;
import ufront.log.RemotingLoggerTest;
import ufront.log.BrowserConsoleLoggerTest;
import ufront.web.HttpErrorTest;
import ufront.web.DispatchControllerTest;
import ufront.web.context.HttpResponseTest;
import ufront.web.context.ActionContextTest;
import ufront.web.context.HttpRequestTest;
import ufront.web.context.HttpContextTest;
import ufront.web.DefaultUfrontConfigurationTest;
import ufront.web.HttpCookieTest;
import ufront.web.ControllerMacrosTest;
import ufront.web.UserAgentTest;
import ufront.web.session.InlineSessionMiddlewareTest;
import ufront.web.session.VoidSessionTest;
import ufront.web.session.FileSessionTest;
import ufront.web.result.DetoxResultTest;
import ufront.web.result.ViewResultTest;
import ufront.web.result.ContentResultTest;
import ufront.web.result.RedirectResultTest;
import ufront.web.result.FileResultTest;
import ufront.web.result.JsonResultTest;
import ufront.web.result.BytesResultTest;
import ufront.web.result.EmptyResultTest;
import ufront.web.result.FilePathResultTest;
import ufront.web.result.ActionResultTest;
import ufront.web.url.PartialUrlTest;
import ufront.web.url.filter.DirectoryUrlFilterTest;
import ufront.web.url.filter.SegmentToParamUrlFilterTest;
import ufront.web.url.filter.QueryStringUrlFilterTest;
import ufront.web.url.filter.PathInfoUrlFilterTest;
import ufront.web.url.VirtualUrlTest;
import ufront.web.ControllerTest;
import ufront.web.upload.TmpFileUploadSyncTest;
import ufront.web.upload.TmpFileUploadMiddlewareTest;
import ufront.web.DispatchTest;
import ufront.web.DefaultControllerTest;
import ufront.web.UfrontConfigurationTest;
import ufront.view.UFViewEngineTest;
import ufront.view.FileViewEngineTest;
import ufront.view.TemplateDataTest;
import ufront.view.TemplatingEnginesTest;
import ufront.view.UFTemplateTest;
import ufront.api.ApiMacrosTest;
import ufront.api.UFApiTest;
import ufront.api.UFApiContextTest;
import ufront.cache.MemoryCacheTest;
import ufront.sys.SysUtilTest;
import ufront.test.TestUtilsTest;
import ufront.auth.YesBossAuthHandlerTest;
import haxe.remoting.RemotingUtilTest;
import haxe.remoting.HttpAsyncConnectionWithTracesTest;
import haxe.remoting.HttpConnectionWithTracesTest;

/**
 * Auto generated Test Suite for MassiveUnit.
 * Refer to munit command line tool for more information (haxelib run munit)
 */

class TestSuite extends massive.munit.TestSuite
{		

	public function new()
	{
		super();

		add(ufront.core.FuturoidTest);
		add(ufront.core.AcceptEitherTest);
		add(ufront.core.MultiValueMapTest);
		add(ufront.core.SyncTest);
		add(ufront.app.UfrontApplicationTest);
		add(ufront.app.HttpApplicationTest);
		add(ufront.handler.ErrorPageHandlerTest);
		add(ufront.handler.RemotingHandlerTest);
		add(ufront.handler.MVCHandlerTest);
		add(ufront.handler.DispatchHandlerTest);
		add(ufront.log.FileLoggerTest);
		add(ufront.log.MessageTest);
		add(ufront.log.RemotingLoggerTest);
		add(ufront.log.BrowserConsoleLoggerTest);
		add(ufront.web.HttpErrorTest);
		add(ufront.web.DispatchControllerTest);
		add(ufront.web.context.HttpResponseTest);
		add(ufront.web.context.ActionContextTest);
		add(ufront.web.context.HttpRequestTest);
		add(ufront.web.context.HttpContextTest);
		add(ufront.web.DefaultUfrontConfigurationTest);
		add(ufront.web.HttpCookieTest);
		add(ufront.web.ControllerMacrosTest);
		add(ufront.web.UserAgentTest);
		add(ufront.web.session.InlineSessionMiddlewareTest);
		add(ufront.web.session.VoidSessionTest);
		add(ufront.web.session.FileSessionTest);
		add(ufront.web.result.DetoxResultTest);
		add(ufront.web.result.ViewResultTest);
		add(ufront.web.result.ContentResultTest);
		add(ufront.web.result.RedirectResultTest);
		add(ufront.web.result.FileResultTest);
		add(ufront.web.result.JsonResultTest);
		add(ufront.web.result.BytesResultTest);
		add(ufront.web.result.EmptyResultTest);
		add(ufront.web.result.FilePathResultTest);
		add(ufront.web.result.ActionResultTest);
		add(ufront.web.url.PartialUrlTest);
		add(ufront.web.url.filter.DirectoryUrlFilterTest);
		add(ufront.web.url.filter.SegmentToParamUrlFilterTest);
		add(ufront.web.url.filter.QueryStringUrlFilterTest);
		add(ufront.web.url.filter.PathInfoUrlFilterTest);
		add(ufront.web.url.VirtualUrlTest);
		add(ufront.web.ControllerTest);
		add(ufront.web.upload.TmpFileUploadSyncTest);
		add(ufront.web.upload.TmpFileUploadMiddlewareTest);
		add(ufront.web.DispatchTest);
		add(ufront.web.DefaultControllerTest);
		add(ufront.web.UfrontConfigurationTest);
		add(ufront.view.UFViewEngineTest);
		add(ufront.view.FileViewEngineTest);
		add(ufront.view.TemplateDataTest);
		add(ufront.view.TemplatingEnginesTest);
		add(ufront.view.UFTemplateTest);
		add(ufront.api.ApiMacrosTest);
		add(ufront.api.UFApiTest);
		add(ufront.api.UFApiContextTest);
		add(ufront.cache.MemoryCacheTest);
		add(ufront.sys.SysUtilTest);
		add(ufront.test.TestUtilsTest);
		add(ufront.auth.YesBossAuthHandlerTest);
		add(haxe.remoting.RemotingUtilTest);
		add(haxe.remoting.HttpAsyncConnectionWithTracesTest);
		add(haxe.remoting.HttpConnectionWithTracesTest);
	}
}
