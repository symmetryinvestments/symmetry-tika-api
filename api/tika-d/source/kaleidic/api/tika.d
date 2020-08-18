module kaleidic.api.tika;
import std.stdio;
import core.thread;
import std.algorithm;
import std.array;
import std.exception;
import std.string;
import std.file;
import requests;

unittest
{
	import std.conv : to;
	import std.net.curl : download;
	auto testFileUrl ="https://github.com/Laeeth/docshare/raw/master/paretian.pdf";
	auto filenameIndex = testFileUrl.lastIndexOf("/");
	enforce (filenameIndex > -1);
	auto filename="." ~ testFileUrl[filenameIndex..$];
	if(!filename.exists)
		download(testFileUrl,filename);
	TikaServer tikaServer;
	enforce(tikaServer.detectType(filename).value == "application/pdf");
	auto meta = tikaServer.extractMetaData(filename);
	enforce(meta.success, "failed to extract metadata" ~ "\n" ~ meta.value.to!string);
	auto res = tikaServer.convertBulkToText([filename]);
	import std.stdio;
	stderr.writeln(meta.value["title"]);
	enforce(meta.value["title"] == "THE BEST AND THE REST: REVISITING THE NORM OF NORMALITY OF INDIVIDUAL PERFORMANCE");
}

struct TikaResult
{
	import requests : Response;
	int responseCode;
	bool success = false;
	string value;

	private this(Response response)
	{
		import std.conv : to;
		success = (response.code == 200);
		responseCode = response.code;
		value = (cast(char[]) response.responseBody.data).idup;
	}
}

struct TikaMetaData
{
	import requests : Response;
	int responseCode;
	bool success = false;
	string[string] value;

	private this(Response response)
	{
		import std.conv : to;
		import std.string : splitLines, split;
		success = (response.code == 200);
		responseCode = response.code;
		auto lines = (cast(char[])response.responseBody.data).idup
			.splitLines;

		foreach(line;lines)
		{
			auto cols = line.split(',');
			value[cols[0].unQuote] = cols[1].unQuote;
		}
	}
}

struct TikaServer
{
	import core.time : Duration, seconds;
	enum url_tika = "tika";
	enum url_meta = "meta";
	enum url_detect = "detect/stream";
	enum url_detectors = "detectors";
	enum url_mimetypes = "mime-types";

	string url="http://127.0.0.1:9998";
	Duration timeout = 60.seconds;

	this(string url = "http://127.0.0.1:9998", int timeoutSeconds = 60)
	{
		this.url = url;
		this.timeout= timeoutSeconds.seconds;
	}

	TikaMetaData extractMetaData(string filename)
	{
		import requests : Request;
		import std.stdio : File;
		auto file = File(filename);
		auto rq = Request();
		auto response = rq.exec!"PUT"(url~"/"~url_meta,file.byChunk(1024));
		return TikaMetaData(response);
	}

	TikaResult[] convertBulkToText(string[] filenames)
	{
		import std.algorithm : map;
		import std.array : array;
		return filenames.map!(filename => convertToText(filename)).array;
	}

	TikaResult detectType(string filename)
	{
		import std.stdio : File;
		import requests : Request;
		string ret;
		auto file = File(filename);
		auto rq = Request();
		auto response = rq.exec!"PUT"(url~"/"~url_detect,file.byChunk(1024));
		return TikaResult(response);
	}

	TikaResult convertToText(string filename)
	{
		import requests : Request;
		import std.stdio;
		import std.conv : to;
		auto file = File(filename);
		auto rq = Request();
		auto response = rq.exec!"PUT"(url~"/"~url_tika,file.byChunk(1024));
		return TikaResult(response);
	}

	TikaResult convertStringToText(string inputString)
	{
		import requests : Request;
		import std.stdio;
		auto rq = Request();
		auto response = rq.exec!"PUT"(url~"/"~url_tika,inputString);
		return TikaResult(response);
	}
}

private string unQuote(string s)
{
	s = s.strip;
	if (s.length > 2 && (s[0] == '\"'))
		s = s[1 .. $];
	if (s.length > 1 && (s[$-1] == '\"'))
		s = s[0 .. $-1];
	return s;
}

