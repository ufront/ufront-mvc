package php.ufront.web.context;

import haxe.io.Bytes;
import php.Lib;
import ufront.web.upload.*;
import ufront.web.context.HttpRequest.OnPartCallback;
import ufront.web.context.HttpRequest.OnDataCallback;
import ufront.web.context.HttpRequest.OnEndPartCallback;
import ufront.web.UserAgent;
import ufront.core.MultiValueMap;
import haxe.ds.StringMap;
import ufront.core.Sync;
using tink.CoreApi;
using thx.core.Strings;
using StringTools;

/**
	An implementation of HttpRequest for PHP.

	@author Franco Ponticelli, Jason O'Neil
**/
class HttpRequest extends ufront.web.context.HttpRequest
{
	public function new() {
		_parsed = false;
	}

	override function get_queryString() {
		if ( queryString==null )
			queryString = getServerParam( 'QUERY_STRING' );
		return queryString;
	}

	override function get_postString() {
		if ( httpMethod=="GET" )
			return "";
		if ( postString==null )
		{
			if (untyped __call__("isset", __var__('GLOBALS', 'HTTP_RAW_POST_DATA')))
			{
				postString = untyped __var__('GLOBALS', 'HTTP_RAW_POST_DATA');
			} else {
				postString = untyped __call__("file_get_contents", "php://input");
			}
			if (null == postString)
				postString = "";
		}
		return postString;
	}

	var _parsed:Bool;

	override public function parseMultipart( ?onPart:OnPartCallback, ?onData:OnDataCallback, ?onEndPart:OnEndPartCallback ):Surprise<Noise,Error> {
		if ( !isMultipart() )
			return Sync.success();

		if (_parsed)
			return throw new Error('parseMultipart() can only been called once');

		_parsed = true;

		var post = get_post();
		if( untyped __call__("isset", __php__("$_FILES")) ) {

			var parts:Array<String> = untyped __call__("new _hx_array",__call__("array_keys", __php__("$_FILES")));
			var errors = [];
			var allPartFutures = [];

			if ( onPart==null ) onPart = function(_,_) return Sync.of( Success(Noise) );
			if ( onData==null ) onData = function(_,_,_) return Sync.of( Success(Noise) );
			if ( onEndPart==null ) onEndPart = function() return Sync.of( Success(Noise) );

			for(part in parts) {
				// Extract the info from PHP's $_FILES
				var info:Dynamic = untyped __php__("$_FILES[$part]");
				var file:String = untyped info['name'];
				var tmp:String = untyped info['tmp_name'];
				var name = StringTools.urlDecode(part);
				if (tmp == '') continue;

				// Handle any errors
				var err:Int = untyped info['error'];
				if(err > 0) {
					switch(err) {
						case 1:
							var maxSize = untyped __call__('ini_get', 'upload_max_filesize');
							errors.push('The uploaded file exceeds the max size of $maxSize');
						case 2:
							var maxSize = untyped __call__('ini_get', 'post_max_size');
							errors.push('The uploaded file exceeds the max file size directive specified in the HTML form (max is $maxSize)');
						case 3: errors.push('The uploaded file was only partially uploaded');
						case 4: // No file was uploaded
						case 6: errors.push('Missing a temporary folder');
						case 7: errors.push('Failed to write file to disk');
						case 8: errors.push('File upload stopped by extension');
					}
					continue;
				}

				// Prepare for parsing the file
				var fileResource:Dynamic = null;
				var bsize = 8192;
				var currentPos = 0;
				var partFinishedTrigger = Future.trigger();
				allPartFutures.push( partFinishedTrigger.asFuture() );

				// Helper function for processing the results of our callback functions.
				function processResult( surprise:Surprise<Noise,Error>, andThen:Void->Void ) {
					surprise.handle( function(outcome) {
						switch outcome {
							case Success(err):
								andThen();
							case Failure(err):
								errors.push( err.toString() );
								try untyped __call__("fclose", fileResource) catch (e:Dynamic) errors.push( 'Failed to close upload tmp file: $e' );
								try untyped __call__("unlink", tmp) catch (e:Dynamic) errors.push( 'Failed to delete upload tmp file: $e' );
								partFinishedTrigger.trigger( outcome );
						}
					});
				}

				// Function to read chunks of the file, and close when done
				function readNextPart() {
					if ( false==untyped __call__("feof", fileResource) ) {
						// Read this line, call onData, and then read the next part
						var buf:String = untyped __call__("fread", fileResource, bsize);
						var size:Int = untyped __call__("strlen", buf);
						processResult( onData(Bytes.ofString(buf),currentPos,size), function() readNextPart() );
						currentPos += size;
					}
					else {
						// close the file, call onEndPart(), and delete the temp file
						untyped __call__("fclose", fileResource);
						processResult( onEndPart(), function() {
							untyped __call__("unlink",tmp);
							partFinishedTrigger.trigger( Success(Noise) );
						});
					}
				}

				// Call `onPart`, then open the file, then start reading
				processResult( onPart(name,file), function() {
					fileResource = untyped __call__("fopen", tmp, "r");
					readNextPart();
				});
			}

			return Future.ofMany( allPartFutures ).map( function(_) {
				if ( errors.length==0 ) return Success(Noise);
				else return Failure(Error.withData('Error parsing multipart request data', errors));
			});
		}
		else return Sync.of( Success(Noise) );
	}

	override function get_query() {
		if ( query==null ) {
			query = getHashFromString(queryString);
		}
		return query;
	}

	override function get_post() {
		if ( post==null ) {
			post = new MultiValueMap();
			if ( httpMethod=="POST" ) {
				if ( isMultipart() ) {
					post = new MultiValueMap();
					if (untyped __call__("isset", __php__("$_POST"))) {
						var postNames:Array<String> = untyped __call__( "new _hx_array",__call__("array_keys", __php__("$_POST" )));

						for ( name in postNames ) {
							var val:Dynamic = untyped __php__("$_POST[$name]");
							if ( untyped __call__("is_array", val) ) {
								// For each value in the array, add it to our post object.
								for ( innerVal in php.Lib.hashOfAssociativeArray(val) ) {
									if ( untyped __call__("is_string", innerVal) )
										post.add( name, innerVal );
									// else: Note that we could try recurse here if there's another array, but for now I'm
									// giving ufront a rule: only single level `fruit[]` type input arrays are supported,
									// any recursion goes beyond this, so let's not bother.
								}
							}
							else if ( untyped __call__("is_string", val) ) {
								post.add( name, cast val );
							}
						}
					}
				}
				else {
					post = getHashFromString(postString);
				}

				if (untyped __call__("isset", __php__("$_FILES"))) {
					var parts:Array<String> = untyped __call__("new _hx_array",__call__("array_keys", __php__("$_FILES")));
					for (part in parts) {
						var file:String = untyped __php__("$_FILES[$part]['name']");
						var name = StringTools.urlDecode(part);
						post.add(name, file);
					}
				}
			}
		}
		return post;
	}

	override function get_cookies() {
		if ( cookies==null ) {
			cookies = new MultiValueMap();
			var h = Lib.hashOfAssociativeArray(untyped __php__("$_COOKIE"));
			for ( k in h.keys() ) {
				cookies.add( k, h.get(k) );
			}
		}
		return cookies;
	}

	override function get_hostName() {
		if ( hostName==null )
			hostName = getServerParam( "SERVER_NAME" );
		return hostName;
	}

	override function get_clientIP() {
		if ( clientIP==null )
			clientIP = getServerParam( "REMOTE_ADDR" );
		return clientIP;
	}

	override function get_uri() {
		if ( uri==null ) {
			var s = getServerParam( "REQUEST_URI" );
			uri = s.split("?")[0];
		}
		return uri;
	}

	override function get_clientHeaders() {
		if ( clientHeaders==null ) {
			clientHeaders = new MultiValueMap();
			var h = Lib.hashOfAssociativeArray(untyped __php__("$_SERVER"));
			for(k in h.keys()) {
				if(k.substr(0,5) == "HTTP_") {
					var headerName:String = k.substr(5).toLowerCase().replace("_", "-").capitalizeWords();
					var headerValues:String = h.get(k);
					for ( val in headerValues.split(",") ) {
						clientHeaders.add(headerName, val.trim());
					}
				}
			}
			if (h.exists("CONTENT_TYPE"))
				clientHeaders.set("Content-Type", h.get("CONTENT_TYPE"));
		}
		return clientHeaders;
	}

	override function get_httpMethod() {
		if ( httpMethod==null )
			httpMethod = getServerParam( "REQUEST_METHOD" );
		return httpMethod;
	}

	override function get_scriptDirectory() {
		if (null == scriptDirectory) {
			var dir = getServerParam( "SCRIPT_FILENAME" );
			scriptDirectory = (untyped __call__("dirname",dir):String) + "/";
		}
		return scriptDirectory;
	}

	override function get_authorization() {
		if ( authorization==null ) {
			authorization = {
				user: getServerParam( "PHP_AUTH_USER" ),
				pass: getServerParam( "PHP_AUTH_PW" )
			};
		}
		return (authorization.user!=""||authorization.pass!="") ? authorization : null;
	}

	static inline function getServerParam( name:String ) {
		if (untyped __call__("array_key_exists", name, __php__("$_SERVER"))) {
			return untyped __var__('_SERVER', name);
		}
		else return "";
	}

	static function encodeName(s:String) {
		return s.urlEncode().replace('.', '%2E');
	}

	static var paramPattern = ~/^([^=]+)=(.*?)$/;
	static function getHashFromString(s:String):MultiValueMap<String> {
		var qm = new MultiValueMap();
		for (part in s.split("&"))
		{
			if (!paramPattern.match(part))
				continue;
			qm.add(
				StringTools.urlDecode(paramPattern.matched(1)),
				StringTools.urlDecode(paramPattern.matched(2)));
		}
		return qm;
	}

	static function getHashFrom(a:php.NativeArray) {
		if(untyped __call__("get_magic_quotes_gpc"))
			untyped __php__("reset($a); while(list($k, $v) = each($a)) $a[$k] = stripslashes((string)$v)");
		return Lib.hashOfAssociativeArray(a);
	}
}
