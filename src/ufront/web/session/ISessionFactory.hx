package ufront.web.session;

import ufront.web.context.*;

interface ISessionFactory {
	function create( context:HttpContext ):IHttpSessionState;
}