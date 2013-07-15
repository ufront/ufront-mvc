package ufront.web.url.filter;
import ufront.web.context.HttpRequest;
import ufront.web.url.UrlDirection;

/**
	Interface for defining new Url filters
**/
interface IUrlFilter 
{
	public function filterIn(url : PartialUrl, request : HttpRequest) : Void;
	public function filterOut(url : VirtualUrl, request : HttpRequest) : Void;
}