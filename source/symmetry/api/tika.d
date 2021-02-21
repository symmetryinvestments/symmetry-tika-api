module symmetry.api.tika;

unittest
{
	import std.conv : text;
	import std.net.curl : download;
	import std.string : lastIndexOf;
	import std.file : exists;

	auto testFileUrl = "https://github.com/Laeeth/docshare/raw/master/paretian.pdf";
	auto filenameIndex = testFileUrl.lastIndexOf("/");
	assert(filenameIndex > -1);
	auto filename = "." ~ testFileUrl[filenameIndex .. $];
	if(!filename.exists)
		download(testFileUrl, filename);
	TikaServer tikaServer;
	assert(tikaServer.detectType(filename).value == "application/pdf");
	auto meta = tikaServer.extractMetaData(filename);
	assert(meta.success, "failed to extract metadata" ~ "\n" ~ meta.value.text);
	auto res = tikaServer.convertBulkTo([filename]);
	assert(meta.value["title"] == "THE BEST AND THE REST: REVISITING THE NORM OF NORMALITY OF INDIVIDUAL PERFORMANCE");
}

struct TikaResult
{
	import requests : Response;

	int responseCode;
	bool success = false;
	string value;

	private this(Response response)
	{
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
	enum url_tika = "tika";
	enum url_meta = "meta";
	enum url_detect = "detect/stream";
	enum url_detectors = "detectors";
	enum url_mimetypes = "mime-types";

	string url = "http://127.0.0.1:9998";
	int timeoutSeconds = 60;

	private auto doRequestFromFile(string urlPath, string filename,
			string[string] headers = [ "Accept":"text/plain" ])
	{
		import std.stdio : File;

		return doRequestFromData(urlPath, filename.File.byChunk(1024),headers);
	}

	private auto doRequestFromData(S)(string urlPath, S input,
			string[string] headers = [ "Accept":"text/plain" ])
	{
		import requests : Request;
		import core.time : seconds;

		auto rq = Request();
		rq.addHeaders(headers);

		rq.timeout = timeoutSeconds.seconds;
		return rq.exec!"PUT"(url ~ '/' ~ urlPath, input);
	}

	TikaMetaData extractMetaData(string filename,
			string[string] headers = (string[string]).init)
	{
		return doRequestFromFile(url_meta, filename,headers)
			.TikaMetaData;
	}

	TikaResult[] convertBulkTo(string[] filenames,
			string[string] headers = [ "Accept":"text/plain" ])
	{
		import std.algorithm : map;
		import std.array : array;

		return filenames.map!(filename => convertTo(filename,headers)).array;
	}

	TikaResult detectType(string filename,
			string[string] headers = (string[string]).init)
	{
		return doRequestFromFile(url_detect, filename,headers)
			.TikaResult;
	}

	TikaResult convertTo(string filename,
			string[string] headers = [ "Accept":"text/plain" ])
	{
		return doRequestFromFile(url_tika, filename,headers)
			.TikaResult;
	}

	TikaResult convertStringTo(string inputString,
			string[string] headers = [ "Accept":"text/plain" ])
	{
		return doRequestFromData(url_tika, inputString,headers)
			.TikaResult;
	}
}

private string unQuote(string s)
{
	import std.string : strip;

	s = s.strip;
	if (s.length > 2 && (s[0] == '\"'))
		s = s[1 .. $];
	if (s.length > 1 && (s[$-1] == '\"'))
		s = s[0 .. $-1];
	return s;
}

