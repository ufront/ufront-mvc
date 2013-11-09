package ufront.auth;

import ufront.web.context.*;

interface UFAuthFactory {
	function create( context:HttpContext ):UFAuthHandler<UFAuthUser>;
}