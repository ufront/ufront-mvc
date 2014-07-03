package ufront.handler;

import haxe.PosInfos;
import ufront.log.Message;
import ufront.web.Controller;
import ufront.app.UFInitRequired;
import ufront.app.UFRequestHandler;
import ufront.web.HttpError;
import ufront.app.HttpApplication;
import tink.CoreApi;
import ufront.web.context.*;
import ufront.web.result.ActionResult;
import ufront.web.session.UFHttpSessionState;
import ufront.auth.*;
import minject.Injector;
import ufront.web.result.*;
import ufront.web.context.*;
import ufront.core.*;

/**
	Uses a `ufront.web.Controller` to execute a controller for the current request.

	@author Jason O'Neil
**/
class MVCHandler implements UFRequestHandler implements UFInitRequired
{
	/**
		An injector for things that should be available to DispatchHandler, your controllers, actions and results.
	
		This extends `HttpApplication.injector`, so all mappings available in the application injector will be available here.

		UfrontApplication also adds the following mappings by default:

		- A mapClass rule for every class that extends `ufront.web.Controller`
		- A mapSingleton rule for every class that extends `ufront.api.UFApi`
		
		We will create a child injector for each dispatch request that also maps a `ufront.web.context.HttpContext` instance and related auth, session, request and response values.
	**/
	public var injector(default,null):Injector;

	/**
		The index controller which is used to match requests to controllers / actions.

		This controller may sub-dispatch to other controllers.

		The controller will be instantiated using the dependency injector for that request.
	**/
	public var indexController:Class<Controller>;

	public function new() {
		injector = new Injector();
		injector.mapValue( Injector, injector );
	}

	public function init( application:HttpApplication ):Surprise<Noise,Error> {
		injector.parentInjector = application.injector;
		return Sync.success();
	}

	/** Disposes of the resources (other than memory) that are used by the module. */
	public function dispose( app:HttpApplication ):Surprise<Noise,Error> {
		injector = null;
		return Sync.success();
	}

	/** Initializes a module and prepares it to handle requests. */
	public function handleRequest( ctx:HttpContext ):Surprise<Noise,Error> {
		return 
			processRequest( ctx ) >>
			function (r:Noise) return executeResult( ctx );
	}

	function setupRequestInjector( context:HttpContext ) {
		// Set up the injector 
		var requestInjector = injector.createChildInjector();
		requestInjector.mapValue( HttpContext, context );
		requestInjector.mapValue( HttpRequest, context.request );
		requestInjector.mapValue( HttpResponse, context.response );
		requestInjector.mapValue( UFHttpSessionState, context.session );
		requestInjector.mapValue( UFAuthHandler, context.auth );
		requestInjector.mapValue( UFAuthUser, context.currentUser );
		requestInjector.mapValue( ActionContext, context.actionContext );
		requestInjector.mapValue( MessageList, new MessageList(context.messages) );
		requestInjector.mapValue( String, context.contentDirectory, "contentDirectory" );
		requestInjector.mapValue( String, context.request.scriptDirectory, "scriptDirectory" );
		requestInjector.mapValue( String, context.sessionID, "sessionID" );
		requestInjector.mapValue( String, context.currentUserID, "currentUserID" );

		// Map the specific implementations for auth and session
		if ( context.session!=null ) 
			requestInjector.mapValue( Type.getClass( context.session ), context.session );
		if ( context.auth!=null ) 
			requestInjector.mapValue( Type.getClass( context.auth ), context.auth );

		// Expose this injector to the HttpContext
		context.injector = requestInjector;
		
		return requestInjector;
	}

	function processRequest( context:HttpContext ):Surprise<Noise,Error> {
		var actionContext = new ActionContext( context );
		setupRequestInjector( context );
		actionContext.handler = this;

		// Create the controller, inject into it, execute it...
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
