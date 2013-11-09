package ufront.web.session;

import ufront.web.context.*;

interface UFSessionFactory {
	function create( context:HttpContext ):UFHttpSessionState;
}