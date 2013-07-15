package ufront.web;

/**
	A class describing a Http Cookie.

	This does not actually set a cookie.  Use `setCookie()` on a `HttpResponse` object to set the cookie.

	TODO: document further.
	
	@author Franco Ponticelli
**/
class HttpCookie
{
	public var domain : String;
	public var expires : Date;
	public var name : String;
	public var path : String;
	public var secure : Bool;
	public var value(default, set) : String;
	
	public function new(name : String, value : String, ?expires : Date, ?domain : String, ?path : String, secure = false)
	{
		this.name = name;
		this.value = value;
		this.expires = expires;
		this.domain = domain;
		this.path = path;
		this.secure = secure;
	}
	
	function setName(v : String)
	{
		if (null == v)
			throw "invalid null argument name";
		return name = v;
	}
	
	function set_value(v : String)
	{
		if (null == v)
			throw "invalid null argument value";
		return value = v;
	}
	
	public function toString()
	{
		return name + ": " + description;
	}
	
	public function description()
	{
		var buf = new StringBuf();
		buf.add(value);
		if ( expires != null )
			addPair(buf, "expires", DateTools.format(expires, "%a, %d-%b-%Y %H:%M:%S GMT"));
		addPair(buf, "domain", domain);
		addPair(buf, "path", path);
		if (secure)
			addPair(buf, "secure", true);
		return buf.toString();
	}
	
	static function addPair( buf : StringBuf, name, ?value : String, allowNullValue = false) {
		if (!allowNullValue && null == value)
			return;
		buf.add("; ");
		buf.add(name);
		if (null == value)
			return;
		buf.add("=");
		buf.add(value);
	}
}