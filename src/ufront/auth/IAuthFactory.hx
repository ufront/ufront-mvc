package ufront.auth;

import ufront.web.context.*;

interface IAuthFactory {
	function create( context:HttpContext ):IAuthHandler<IAuthUser>;
}