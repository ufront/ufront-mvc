package ufront.web.session;

import utest.Assert;
import ufront.MVC;
import ufront.test.TestUtils.NaturalLanguageTests.*;
import minject.Injector;
using ufront.test.TestUtils;
using tink.CoreApi;
class GenericSessionTest {

	public static function testSessionImplementation( sessionImpl:Class<UFHttpSession>, ?doInjections:Injector->Void ) {
		var testApp = new UfrontApplication({
			sessionImplementation:sessionImpl,
			indexController:MyController,
			disableBrowserTrace: true,
			disableServerTrace: true,
		});
		testApp.addLogHandler( new OriginalTraceLogger() );
		if ( doInjections!=null )
			doInjections( testApp.injector );

		var sessionID:String = null;

		testApp.simulateSession([
			function(_) {
				return
				whenIVisit( "/", testApp.injector )
				.onTheApp( testApp )
				.itShouldLoad()
				.theResponseShouldBe( "Session ID is null" );

			},
			function (prev) {
				return
				whenIVisit( "/start-session/", testApp.injector )
				.followingOnFrom( prev )
				.onTheApp( testApp )
				.itShouldLoad()
				.theResponseShouldBe( "Session is active: true" )
				.andThenCheck(function(ctx) {
					// Note we're using CacheSession.defaultSessionName, regardless of which implementation we're using.
					// I'm happy for this to be an unofficial test that all implementations use the same session name.
					var cookie = ctx.context.response.getCookies().get( CacheSession.defaultSessionName );
					Assert.notNull( cookie );
					if ( cookie!=null ) {
						sessionID = cookie.value;
						Assert.isTrue( Uuid.isValid(sessionID) );
					}
				});
			},
			function(prev) {
				return
				whenIVisit( "/", testApp.injector )
				.followingOnFrom( prev )
				.onTheApp( testApp )
				.itShouldLoad()
				.theResponseShouldBe( 'Session ID is $sessionID' );
			},
			function(prev) {
				return
				whenIVisit( "/set-session-var/", testApp.injector )
				.withTheQueryParams([ "name"=>"Jason", "age"=>"27" ])
				.followingOnFrom( prev )
				.onTheApp( testApp )
				.itShouldLoad()
				.theResponseShouldBe( 'Done' );
			},
			function(prev) {
				return
				whenIVisit( "/increment-session-var/", testApp.injector )
				.followingOnFrom( prev )
				.onTheApp( testApp )
				.itShouldLoad()
				.theResponseShouldBe( 'Happy 28 birthday Jason!' );
			},
			function(prev) {
				return
				whenIVisit( "/set-session-var/", testApp.injector )
				.withTheQueryParams([ "name"=>"Anna", "age"=>"25" ])
				.followingOnFrom( prev )
				.onTheApp( testApp )
				.itShouldLoad()
				.theResponseShouldBe( 'Done' );
			},
			function(prev) {
				return
				whenIVisit( "/increment-session-var/", testApp.injector )
				.followingOnFrom( prev )
				.onTheApp( testApp )
				.itShouldLoad()
				.theResponseShouldBe( 'Happy 26 birthday Anna!' );
			},
			function(prev) {
				return
				whenIVisit( "/regenerate-session-id-and-shout/", testApp.injector )
				.followingOnFrom( prev )
				.onTheApp( testApp )
				.itShouldLoad()
				.theResponseShouldBe( 'Done' );
			},
			function(prev) {
				return
				whenIVisit( "/increment-session-var/", testApp.injector )
				.followingOnFrom( prev )
				.onTheApp( testApp )
				.itShouldLoad()
				.theResponseShouldBe( 'Happy 27 birthday ANNA!' );
			},
			function(prev) {
				return
				whenIVisit( "/close-session/", testApp.injector )
				.followingOnFrom( prev )
				.onTheApp( testApp )
				.itShouldLoad()
				.theResponseShouldBe( 'Done' )
				.andThenCheck(function(ctx) {
					var cookie = ctx.context.response.getCookies().get( CacheSession.defaultSessionName );
					Assert.notNull( cookie );
					if ( cookie!=null ) {
						Assert.isTrue( cookie.expires.getTime()<=Date.now().getTime() );
						Assert.equals( "", cookie.value );
					}
				});
			},
			function(prev) {
				return
				whenIVisit( "/increment-session-var/", testApp.injector )
				.followingOnFrom( prev )
				.onTheApp( testApp )
				.itShouldFail();
			}
		]);
	}

}

class MyController extends Controller {
	@:route("/")
	public function showSessionID() {
		return 'Session ID is '+context.sessionID;
	}

	@:route("/start-session/")
	public function startSession() {
		return context.session.init() >> function(n:Noise) {
			return 'Session is active: '+context.session.isActive();
		}
	}

	@:route("/set-session-var/")
	public function setVar( args:{ name:String, age:Int }) {
		context.session.set( "user", args );
		return 'Done';
	}

	@:route("/increment-session-var/")
	public function incrementVar() {
		ufTrace( context.session.get('name') );
		var user:{name:String,age:Int} = context.session.get( "user" );
		user.age++;
		context.session.triggerCommit();
		return 'Happy ${user.age} birthday ${user.name}!';
	}

	@:route("/regenerate-session-id-and-shout/")
	public function regenerateSession() {
		context.session.regenerateID();
		var user:{name:String,age:Int} = context.session.get( "user" );
		user.name = user.name.toUpperCase();
		context.session.set( "user", user );
		return 'Done';
	}

	@:route("/close-session/")
	public function closeSession() {
		context.session.close();
		return 'Done';
	}
}
