module kaleidic.api.tika;
import std.stdio;
import core.thread;
import std.algorithm;
import std.array;
import std.conv;
import std.exception;
import std.string;
import std.file;
import vibe.d;
import vibe.core.log;
import vibe.http.client;
import vibe.stream.operations;
import vibe.utils.dictionarylist;


unittest
{
	auto dlangUrl="http://dlang.org/dlangspec.pdf";
	auto filenameIndex=dlangUrl.lastIndexOf("/");
	enforce (filenameIndex>-1);
	auto filename="."~dlangUrl[filenameIndex..$];
	if(!filename.exists)
		download(dlangUrl,filename);
	TikaServer tikaServer;
	enforce(tikaServer.detectType(filename)=="application/pdf");
	auto meta=tikaServer.extractMetaData(filename);
	enforce(meta["title"]=="D Programming Language Specification");
	auto res=tikaServer.convertBulkToText([filename]);
}


struct TikaServer
{
	enum url_tika="tika";
	enum url_meta="meta";
	enum url_detect="detect/stream";
	enum url_detectors="detectors";
	enum url_mimetypes="mime-types";

	string url="http://127.0.0.1:9998";

	this(string url)
	{
		this.url=url;
	}
	string testGet()
	{
		string ret;
		requestHTTP(url~"/mime-types",
		(scope req) {
				req.method = HTTPMethod.GET;
			},
			(scope res) {
				ret~=res.bodyReader.readAllUTF8();
			}
		);
		return to!string(ret);
	}

	string[string] extractMetaData(string filename)
	{
		string[string] ret;
		auto buf=cast(ubyte[])read(filename);
		string meta;
		requestHTTP(url~"/"~url_meta,
			(scope req)
			{
				req.method = HTTPMethod.PUT;
				//req.contentLength=buf.length;
				req.bodyWriter.write(buf);
			},
			(scope res)
			{
				meta~= to!string(res.bodyReader.readAllUTF8());
			}
		);
		foreach(line;meta.splitLines)
		{
			auto cols=line.split(',');
			ret[cols[0].unQuote]=cols[1].unQuote;
		}
		return ret;
	}
 	string[] convertBulkToText(string[] filenames)
	{
		return convertBulkToText(filenames,false);
	}

	string[] convertBulkToText(string[] filenames, bool asHTML)
	{
		string[] ret;
		foreach(filename;filenames)
			ret~=convertToText(filename);
		return ret;
	}

	string detectType(string filename)
	{
		string ret;
		auto buf=cast(ubyte[])read(filename);
		requestHTTP(url~"/"~url_detect,
			(scope req)
			{
				req.method=HTTPMethod.PUT;
				req.bodyWriter.write(buf);
			},
			(scope res)
			{
				ret~=res.bodyReader.readAllUTF8.to!string;
			}
		);
		return ret;
	}

	string convertToText(string filename)
	{
		string ret;
		auto buf=cast(ubyte[])read(filename);
		requestHTTP(url~"/"~url_tika,
			(scope req)
			{
				req.method = HTTPMethod.PUT;
				//req.contentLength=buf.length;
				req.bodyWriter.write(buf);
			},
			(scope res)
			{
				ret~= to!string(res.bodyReader.readAllUTF8());
			}
		);
		return ret;
	}

	auto createDictionaryList(string[string] headers)
	{
		DictionaryList!(string,false,32L)  dictionaryList;
		foreach(header;headers.keys)
		{
			writefln("header: %s %s",header,headers[header]);
			dictionaryList.addField(header,headers[header]);
		}
		return dictionaryList;
	}
}

private void download(string url, string filename)
{
    requestHTTP(url,
	(scope req) {
		},
	(scope res) {
			std.file.write(filename,res.bodyReader.readAll);
		}
	);
}

private string unQuote(string s)
{
	s=s.strip;
	if (s.length>2 && (s[0]=='\"'))
		s=s[1..$];
	if (s.length>1 && (s[$-1]=='\"'))
		s=s[0..$-1];
	return s;
}

