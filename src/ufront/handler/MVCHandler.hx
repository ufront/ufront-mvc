package ufront.handler;

import haxe.PosInfos;
import ufront.log.Message;
import ufront.web.Controller;
import ufront.app.UFInitRequired;
import ufront.app.UFRequestHandler;
import ufront.web.HttpError;
import ufront.app.HttpApplication;
import ufront.app.UfrontApplication;
import tink.CoreApi;
import ufront.web.context.*;
import ufront.web.result.ActionResult;
import ufront.web.session.UFHttpSession;
import ufront.auth.*;
import minject.Injector;
import ufront.web.result.*;
import ufront.web.context.*;
import ufront.core.*;

/**
	Uses a `ufront.web.Controller` to execute a controller for the current request.

	@author Jason O'Neil
**/
class MVCHandler implements UFRequestHandler
{
	/**
		The index controller which is used to match requests to controllers / actions.

		This controller may sub-dispatch to other controllers.

		The controller will be instantiated using the dependency injector for that request.
	**/
	public var indexController(default,null):Class<Controller>;

	public function new( indexController:Class<Controller> ) {
		this.indexController = indexController;
	}

	/** Initializes a module and prepares it to handle requests. */
	public function handleRequest( ctx:HttpContext ):Surprise<Noise,Error> {
		return
			processRequest( ctx ) >>
			function (r:Noise) return executeResult( ctx );
	}

	function processRequest( context:HttpContext ):Surprise<Noise,Error> {
		context.actionContext.handler = this;
		var controller:Controller = context.injector.instantiate( indexController );
		var resultFuture =
			controller.execute() >>
			function(result:ActionResult):Noise {
				context.actionContext.actionResult = result;
				return Noise;
			}
		;
		return resultFuture;
	}

	function executeResult( context:HttpContext ):Surprise<Noise,Error> {
		return
			try
				context.actionContext.actionResult.executeResult( context.actionContext )
			catch ( e:Dynamic ) {
				var p = HttpError.fakePosition( context.actionContext, "executeResult", ["actionContext"] );
				#if debug context.ufError( 'Caught error in DispatchHandler.executeAction while executing ${p.className}.${p.methodName}(${p.customParams.join(",")})' ); #end
				Future.sync( Failure(HttpError.wrap(e)) );
			}
	}

	public function toString() return "ufront.handler.MVCHandler";
}
