package ufront.log;

class BasicMessageFormatter implements UFMessageFormatter {
	var formatter:Message->String;
	
	public function new(formatter:Message->String) {
		this.formatter = formatter;
	}
	
	public function format(m:Message):String {
		return formatter(m);
	}
}