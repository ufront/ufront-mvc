import thx.culture.Culture;
import thx.culture.FormatDate;
import thx.culture.FormatParams;
import thx.error.Error;
import thx.culture.Culture;

/** Alias of `DateTools`, included so mixins work with `using Dates;` **/
typedef HaxeDateTools = DateTools;

/** Alias of `thx.culture.FormatDate`, included so mixins work with `using Dates;` **/
typedef FormatDate = thx.culture.FormatDate;

/**
	Helpers for working with Date objects or timestampts

	`using Dates;`

	@author Franco Ponticelli
	@author Jason O'Neil

	Also includes typed aliases for `DateTools` and `thx.culture.FormatDate` so their mixins can be included in `using Dates` also
**/
class Dates
{
	/**
		Format a date.

		```
		Output examples:
			date.format("D");		Tuesday, October 16, 2012
			date.format("DS");		10/16/2012
			date.format("DST");		10/16/2012 12:31:05 PM
			date.format("DSTS");	10/16/2012 12:31 PM
			date.format("DTS");		Tuesday, October 16, 2012 12:31 PM
			date.format("Y");		2012
			date.format("YM");		October, 2012
			date.format("M");		10
			date.format("MN");		October
			date.format("MS");		Oct
			date.format("MD");		October 16
			date.format("MDS");		Oct 16
			date.format("WD");		2
			date.format("WDN");		Tuesday
			date.format("WDS");		Tue
			date.format("R");		Tue, 16 Oct 2012 12:31:05 GMT
			date.format("DT");		Tuesday, October 16, 2012 12:31:05 PM
			date.format("U");		2012-10-16 12:31:05Z
			date.format("S");		2012-10-16T12:31:05
			date.format("T");		12:31:05 PM
			date.format("TS");		12:31 PM
			date.format("C");		Tuesday, October 16, 2012
			date.format(["C", "This happened on %A at %r"]);	This happened on Tuesday at 12:31:05 PM
		```

		If the provided format does not match one of these strings, it is passed to FormatDate.format() and is used.

		```
		@param d The Date object to format
		@param param A String with the parameter describing the desired output.  See the description above for a list of codes.
		@param params An array containing a number of parameters.  Mostly useful if you use "C", and then need a second parameter to describe the format.
		@param culture The culture to use.
		```
	**/
	public static function format(d : Date, ?param : String, ?params : Array<String>, ?culture : Culture):String
	{
		return formatf(param, params, culture)(d);
	}

	/**
		Return a function for formatting a date.  The function returned depends on the format code used here.

		@see format()
	**/
	public static function formatf(?param : String, ?params : Array<String>, ?culture : Culture):Date->String
	{
		params = FormatParams.params(param, params, 'D');
		var format = params.shift();
		switch(format)
		{
			case 'D':
				return function(d) return FormatDate.date(d, culture);
			case 'DS':
				return function(d) return FormatDate.dateShort(d, culture);
			case 'DST':
				return function(d) return FormatDate.dateShort(d, culture)+' '+FormatDate.time(d, culture);
			case 'DSTS':
				return function(d) return FormatDate.dateShort(d, culture)+' '+FormatDate.timeShort(d, culture);
			case 'DTS':
				return function(d) return FormatDate.date(d, culture)+' '+FormatDate.timeShort(d, culture);
			case 'Y':
				return function(d) return FormatDate.year(d, culture);
			case 'YM':
				return function(d) return FormatDate.yearMonth(d, culture);
			case 'M':
				return function(d) return FormatDate.month(d, culture);
			case 'MN':
				return function(d) return FormatDate.monthName(d, culture);
			case 'MS':
				return function(d) return FormatDate.monthNameShort(d, culture);
			case 'MD':
				return function(d) return FormatDate.monthDay(d, culture);
			case 'MDS':
				return function(d) return FormatDate.monthDayShort(d, culture);
			case 'WD':
				return function(d) return FormatDate.weekDay(d, culture);
			case 'WDN':
				return function(d) return FormatDate.weekDayName(d, culture);
			case 'WDS':
				return function(d) return FormatDate.weekDayNameShort(d, culture);
			case 'R':
				return function(d) return FormatDate.dateRfc(d, culture);
			case 'DT':
				return function(d) return FormatDate.dateTime(d, culture);
			case 'U':
				return function(d) return FormatDate.universal(d, culture);
			case 'S':
				return function(d) return FormatDate.sortable(d, culture);
			case 'T':
				return function(d) return FormatDate.time(d, culture);
			case 'TS':
				return function(d) return FormatDate.timeShort(d, culture);
			case 'C':
				var f = params[0];
				if (null == f)
					return function(d) return FormatDate.date(d, culture);
				else
					return function(d) return FormatDate.format(d, f, culture, (params[1] != null ? (params[1] == 'true') : true));
			default:
				// Attempt to use FormatDate.format()
				return function (d) return FormatDate.format(d, format, culture, (params[0] != null ? (params[0] == 'true') : true));
		}
	}

	inline public static function interpolate(f : Float, a : Date, b : Date, ?equation : Float -> Float) : Date
	{
		return interpolatef(a, b, equation)(f);
	}

	public static function interpolatef(a : Date, b : Date, ?equation : Float -> Float)
	{
		var f = Floats.interpolatef(a.getTime(), b.getTime(), equation);
		return function(v) return Date.fromTime(f(v));
	}

	/**
		Snaps a time to the nearest second, minute, hour, day, week, month or year.

		Note, I'm not sure if "week" is functioning correctly yet. It rounds up/down to the
		nearest 7 days, but the epoch didn't begin on a sunday or monday, so that's probably wrong

		@param time The unix time in milliseconds.  See date.getTime()
		@param period Either: Second, Minute, Hour, Day, Week, Month or Year
		@param mode Either: Up, Down or Round

		@return the unix time of the snapped date (In milliseconds).  Or 0 if "period" was invalid.
	**/
	public static function snap(time : Float, period : TimePeriod, ?mode : SnapMode) : Float
	{
		var mode = (mode!=null) ? mode : Round;
		switch(mode) {
			case Down:
				switch(period)
				{
					case Second:
						return Math.floor(time / 1000.0) * 1000.0;
					case Minute:
						return Math.floor(time / 60000.0) * 60000.0;
					case Hour:
						return Math.floor(time / 3600000.0) * 3600000.0;
					case Day:
						var d = Date.fromTime(time);
						return new Date(d.getFullYear(), d.getMonth(), d.getDate(), 0, 0, 0).getTime();
					case Week:
						return Math.floor(time / (7.0 * 24.0 * 3600000.0)) * (7.0 * 24.0 * 3600000.0);
					case Month:
						var d = Date.fromTime(time);
						return new Date(d.getFullYear(), d.getMonth(), 1, 0, 0, 0).getTime();
					case Year:
						var d = Date.fromTime(time);
						return new Date(d.getFullYear(), 0, 1, 0, 0, 0).getTime();
				}
			case Up:
				switch(period)
				{
					case Second:
						return Math.ceil(time / 1000.0) * 1000.0;
					case Minute:
						return Math.ceil(time / 60000.0) * 60000.0;
					case Hour:
						return Math.ceil(time / 3600000.0) * 3600000.0;
					case Day:
						var d = Date.fromTime(time);
						return new Date(d.getFullYear(), d.getMonth(), d.getDate() + 1, 0, 0, 0).getTime();
					case Week:
						return Math.ceil(time / (7.0 * 24.0 * 3600000.0)) * (7.0 * 24.0 * 3600000.0);
					case Month:
						var d = Date.fromTime(time);
						return new Date(d.getFullYear(), d.getMonth() + 1, 1, 0, 0, 0).getTime();
					case Year:
						var d = Date.fromTime(time);
						return new Date(d.getFullYear() + 1, 0, 1, 0, 0, 0).getTime();
				}
			case Round:
				switch(period)
				{
					case Second:
						return Math.round(time / 1000.0) * 1000.0;
					case Minute:
						return Math.round(time / 60000.0) * 60000.0;
					case Hour:
						return Math.round(time / 3600000.0) * 3600000.0;
					case Day:
						var d = Date.fromTime(time),
							mod = (d.getHours() >= 12) ? 1 : 0;
						return new Date(d.getFullYear(), d.getMonth(), d.getDate() + mod, 0, 0, 0).getTime();
					case Week:
						return Math.round(time / (7.0 * 24.0 * 3600000.0)) * (7.0 * 24.0 * 3600000.0);
					case Month:
						var d = Date.fromTime(time),
							mod = d.getDate() > Math.round(DateTools.getMonthDays(d) / 2) ? 1 : 0;
						return new Date(d.getFullYear(), d.getMonth() + mod, 1, 0, 0, 0).getTime();
					case Year:
						var d = Date.fromTime(time),
							mod = time > new Date(d.getFullYear(), 6, 2, 0, 0, 0).getTime() ? 1 : 0;
						return new Date(d.getFullYear() + mod, 0, 1, 0, 0, 0).getTime();
				}
		}
	}

	/**
		Snaps a time to a given weekday in the current week.  The time within the day will stay the same.

		If you are already on the given day, the date will not change.

		@param time The unix time in milliseconds.  See date.getTime()
		@param day Day to snap to.  Either "sunday", "monday", "tuesday" etc. Case insensitive.
		@param mode Whether to go the next day (Up), the previous day (Down), or in the current week (Round, default).
		@param firstDayOfWk The first day of the week.  Default to 0 (Sunday).  Monday = 1.

		@throws String if invalid weekday was entered.

		@return The unix time of the day you have snapped to.
	**/
	public static function snapToWeekDay(time : Float, day : Weekday, ?snapMode : SnapMode, ?firstDayOfWk : Weekday)
	{
		var snapMode = (snapMode!=null) ? snapMode : Round;
		if ( firstDayOfWk==null ) firstDayOfWk = Sunday;
		var d = Date.fromTime(time).getDay();

		var s:Int = day;
		if (s == -1) throw new Error("unknown week day '{0}'", day);

		switch (snapMode)
		{
			case Down:
				// get the previous occurence of that day (backward in time)
				if (s > d) s = s - 7;
				return time - (d-s) * 24 * 60 * 60 * 1000;
			case Up:
				// get the next occurence of that day (forward in time)
				if (s < d) s = s + 7;
				return time + (s-d) * 24 * 60 * 60 * 1000;
			case Round:
				// get whichever occurence happened in the current week.

				if (s < (firstDayOfWk:Int)) s = s+7;
				if (d < (firstDayOfWk:Int))  d = d+7;
				// var offset = s-d;
				return time + (s-d) * 24 * 60 * 60 * 1000;
		}
	}

	/**
		Tells if a year is a leap year

		@param year The year, represented as a 4 digit integer
		@return True if a leap year, false otherwise.
	**/
	public static function isLeapYear(year:Int)
	{
		// Only every 4th year
		if ((year % 4) != 0) return false;
		// Except every 100, unless it's the 400th year
		if ((year % 100) == 0)
			return ((year % 400) == 0);
		// It's divisible by 4, and it's not divisible by 100 - it's leap
		return true;
	}

	/**
		Tells if the given date is inside a leap year.

		@param date The date object to check.
		@return True if it is in a leap year, false otherwise.
	**/
	inline public static function isInLeapYear(d:Date) return isLeapYear(d.getFullYear());

	/**
		Returns the number of days in a month.

		@param month An integer representing the month. (Jan=0, Dec=11)
		@param year An 4 digit integer representing the year.
		@return Int, the number of days in the month.
		@throws Error if the month is not between 0 and 11.
	**/
	public static function numDaysInMonth(month:Int, year:Int)
	{
		// 31: Jan, Mar, May, Jul, Aug, Oct, Dec
		// 30: Apr, Jun, Sep, Nov
		// 28or29 Feb
		return switch (month)
		{
			case 0 | 2 | 4 | 6 | 7 | 9 | 11: 31;
			case 3 | 5 | 8 | 10: 30;
			case 1: isLeapYear(year) ? 29 : 28;
			default: throw new Error("Invalid month '{0}'.  Month should be a number, Jan=0, Dec=11", month); 0;
		}
	}

	/**
		Tells how many days in the month of the given date.

		@param date The date representing the month we are checking.
		@return Int, the number of days in the month.
		@throws Error if the month is not between 0 and 11.
	**/
	public static function numDaysInThisMonth(d:Date) return numDaysInMonth(d.getMonth(), d.getFullYear());

	/**
		Perform a delta by creating a new Date object, rather than incrementing a timestamp.

		This is important when the length of the delta is not a guaranteed number of seconds, for example:

		- a month may have a differing number of days,
		- a day may not be exactly 24 hours if Daylight Savings begins or ends during that day,
		- a year may be 365 or or 366 days depending on the year.
	**/
	public static function dateBasedDelta( d:Date, ?yearDelta:Int=0, ?monthDelta:Int=0, ?dayDelta:Int=0, ?hourDelta:Int=0, ?minDelta:Int=0, ?secDelta:Int=0, ?msDelta:Int=0 ):Date {
		var year = d.getFullYear()+yearDelta;
		var month = d.getMonth()+monthDelta;
		var day = d.getDate()+dayDelta;
		var hour = d.getHours()+hourDelta;
		var min = d.getMinutes()+minDelta;
		var sec = d.getSeconds()+secDelta;

		// Wrap values that are too large
		while ( sec>60 ) { sec -= 60; min++; }
		while ( min>60 ) { min -= 60; hour++; }
		while ( hour>23 ) { hour -= 24; day++; }
		while ( hour>23 ) { hour -= 24; day++; }

		var daysInMonth = numDaysInMonth(month,year);
		while ( day>daysInMonth || month>11 ) {
			if ( day>daysInMonth ) {
				day -= daysInMonth;
				month++;
			}
			if ( month>11 ) {
				month -= 12;
				year++;
			}
			daysInMonth = numDaysInMonth( month, year );
		}

		var d = new Date( year, month, day, hour, min, sec );
		return DateTools.delta( d, msDelta );
	}

	/** Return a new date, offset by `numSec` seconds */
	public inline static function deltaSec(d:Date, numSec:Int):Date return DateTools.delta(d, numSec*1000);

	/** Return a new date, offset by `numMin` minutes */
	public inline static function deltaMin(d:Date, numMin:Int):Date return DateTools.delta(d, numMin*60*1000);

	/** Return a new date, offset by `numHrs` hours */
	public inline static function deltaHour(d:Date, numHrs:Int):Date return DateTools.delta(d, numHrs*60*60*1000);

	/** Return a new date, offset by `numDays` days */
	public static inline function deltaDay(d:Date, numDays:Int):Date {
		return dateBasedDelta( d, 0, 0, numDays );
	}

	/** Return a new date, offset by `numWks` weeks */
	public static inline function deltaWeek(d:Date, numWks:Int):Date {
		return dateBasedDelta( d, 0, 0, numWks*7 );
	}

	/** Return a new date, offset by `numMonths` months */
	public static inline function deltaMonth(d:Date, numMonths:Int):Date {
		return dateBasedDelta( d, 0, numMonths );
	}

	/** Return a new date, offset by `numYrs` years */
	public static inline function deltaYear(d:Date, numYrs:Int):Date {
		return dateBasedDelta( d, numYrs );
	}

	/** Returns a new date, exactly 1 year before the given date/time. */
	inline public static function prevYear(d:Date):Date return deltaYear(d, -1);
	/** Returns a new date, exactly 1 year after the given date/time. */
	inline public static function nextYear(d:Date):Date return deltaYear(d, 1);
	/** Returns a new date, exactly 1 month before the given date/time. */
	inline public static function prevMonth(d:Date):Date return deltaMonth(d, -1);
	/** Returns a new date, exactly 1 month after the given date/time. */
	inline public static function nextMonth(d:Date):Date return deltaMonth(d, 1);
	/** Returns a new date, exactly 1 week before the given date/time. */
	inline public static function prevWeek(d:Date):Date return deltaWeek(d, -1);
	/** Returns a new date, exactly 1 week after the given date/time. */
	inline public static function nextWeek(d:Date):Date return deltaWeek(d, 1);
	/** Returns a new date, exactly 1 day before the given date/time. */
	inline public static function prevDay(d:Date):Date return deltaDay(d, -1);
	/** Returns a new date, exactly 1 day after the given date/time. */
	inline public static function nextDay(d:Date):Date return deltaDay(d, 1);


	static var _reparse = ~/^\d{4}-\d\d-\d\d(( |T)\d\d:\d\d(:\d\d(\.\d{1,3})?)?)?Z?$/;

	/**
		Let's you know if a string can be parsed into a valid date format

		String formats allowed include:

		```
		"2010-10-01", "2010-10-01 05:05",
	   "2010-10-01T05:05Z", "2010-10-01 05:05:05", "2010-10-01T05:05:05Z",
		"2010-10-01T05:05:05", "2010-10-01 05:05:05.005"]
		```

		@param s `String` to check.
		@return True if the string can be parsed as a date.
		@see `Dates.parse()`
	**/
	public static function canParse(s : String):Bool
	{
		return _reparse.match(s);
	}

	/**
		Parses a string into a Date object.

		Use Dates.canParse() to see if a string is in a parsable format.

		@param s String to parse.  See canParse() docs for valid string formats.

		@return A Date object for the given time.

		@see `Dates.canParse()`
	**/
	public static function parse(s : String) : Date
	{
		var parts = s.split(".");
		var date = Date.fromString(StringTools.replace(parts[0], "T", " "));
		if (parts.length > 1)
			date = Date.fromTime(date.getTime() + Std.parseInt(parts[1]));
		return date;
	}

	/**
		A comparison function for dates.

		Can be used to sort an array of dates from earliest to latest:

			arrayOfDates.sort(Dates.compare);

		@param a First Date to compare.
		@param b Second Date to compare.
		@return 1 if A is before B, -1 if B is before A and 0 if they represent the same point in time.
	**/
	inline public static function compare(a : Date, b : Date):Int
	{
		return Floats.compare(a.getTime(), b.getTime());
	}
}

@:enum
abstract Weekday(Int) from Int to Int {
	var Sunday = 0;
	var Monday = 1;
	var Tuesday = 2;
	var Wednesday = 3;
	var Thursday = 4;
	var Friday = 5;
	var Saturday = 6;
}

@:enum
abstract Month(Int) from Int to Int {
	var January = 0;
	var February = 1;
	var March = 2;
	var April = 3;
	var May = 4;
	var June = 5;
	var July = 6;
	var August = 7;
	var September = 8;
	var October = 9;
	var November = 10;
	var December = 11;
}

enum TimePeriod {
	Second;
	Minute;
	Hour;
	Day;
	Week;
	Month;
	Year;
}

enum SnapMode {
	Up;
	Down;
	Round;
}
