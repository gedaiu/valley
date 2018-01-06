import std.stdio;

/*
import vibe.core.log;
import vibe.core.net;
import vibe.stream.operations;
import vibe.stream.tls;
import vibe.core.log;
import core.thread;
*/

import std.stdio;
import std.datetime;
import std.conv;
import std.socket;
import std.algorithm;
import std.array;
import std.string;

import vibe.core.core;
import vibe.http.client;
import vibe.stream.operations;

import valley.crawler;
import valley.uri;
import valley.htmlParser;
import valley.storage.base;
import valley.storage.sqlite;
import valley.stemmer.english;
import valley.stemmer.cleaner;

Storage storage;

void crawlerResult(scope CrawlPage crawlPage) {
  writeln("GOT ", crawlPage.uri);

  auto document = new HTMLDocument(crawlPage.uri, crawlPage.content);

  auto stem = new EnStemmer;

  auto page = PageData(
    document.title,
    crawlPage.uri,
    document.preview,
    Clock.currTime,

    document.links.map!(a => URI(a)).array,
    [],
    document.plainText.clean
      .split(" ")
      .map!(a => a.strip.toLower)
      .map!(a => stem.get(a))
      .filter!(a => a.length > 4).array,
    InformationType.webPage
  );

  storage.add(page);
}

auto runApplication() {
  lowerPrivileges();

  writeln("Running event loop...");
  int status;

  while (true) {
    try {
      status = runEventLoop();
      break;
    }
    catch (Throwable th) {
      writeln("Unhandled exception in event loop:");
      writeln(th);

      return 1;
    }
  }

  writeln("Event loop exited with status " ~ status.to!string);

  return status;
}

int main() {
  storage = new SQLiteStorage("data.db");

  auto crawler = new Crawler(
    "Valley (https://github.com/gedaiu/valley)",
    5.seconds,
    CrawlerSettings([
      "dlang.org", "forum.dlang.org", "code.dlang.org",
      "events.ccc.de",
      "stackoverflow.com" ]
    ));

  crawler.onRequest(&request);
  crawler.onResult(&crawlerResult);

  crawler.add(URI("http://dlang.org"));
  crawler.add(URI("https://stackoverflow.com/questions/tagged/d"));
  crawler.add(URI("https://events.ccc.de/congress/2017/wiki/index.php/Main_Page"));

  runTask({
    auto seed = storage.pending(1.days, 100);

    if(seed.length == 0) {
      writeln("There are no expired pages. Using the default seed.");

      return;
    }

    foreach(uri; seed) {
      writeln(uri.toString);
      crawler.add(uri);
    }
  });

  ///
  runTask({
    while(true) {
      try {
        crawler.next();
      } catch(Exception e) {
        e.writeln;
      }
      sleep(1.seconds);
    }
  });

  return runApplication;
}

/*
shared static this()
{
  setLogLevel(LogLevel.debugV);

	listenForTLS;

  //logInfo("Send.");
  sendTLS;
}

void listenForTLS()
{
	auto sslctx = createTLSContext(TLSContextKind.server);
	sslctx.useCertificateChainFile("keys/server.crt");
	sslctx.usePrivateKeyFile("keys/server.key");

	listenTCP(1234, delegate void(TCPConnection conn) nothrow {
		try {
			auto stream = createTLSStream(conn, sslctx);

      while(stream.peek.length == 0) {
        Thread.sleep(1.seconds);
      }


      writeln("Got length ", stream.peek.length);

      ubyte[] dst = new ubyte[stream.peek.length];
      stream.read(dst);

      writeln("Got message: ", cast(char[]) dst);
			//logInfo("Got message: %s", stream.readAllUTF8());
			stream.finalize();
		} catch (Exception e) {

      try { e.writeln; } catch(Exception ex) {}

      logInfo("Failed to receive encrypted message");
		}
	});
}


void sendTLS()
{

  bool validateCert(scope TLSPeerValidationData) {
    logInfo("validate cert");

    return true;
  }

	auto conn = connectTCP("127.0.0.1", 1234);
	auto sslctx = createTLSContext(TLSContextKind.client);
  sslctx.peerValidationMode = TLSPeerValidationMode.checkCert;
  sslctx.peerValidationCallback = &validateCert;
	auto stream = createTLSStream(conn, sslctx);

  logInfo("sending...");
  stream.write("Hello, World!");
	stream.finalize();

  logInfo("done");
	conn.close();
}

*/
