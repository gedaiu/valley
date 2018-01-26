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
import vibe.http.websockets: WebSocket, handleWebSockets;
import vibe.http.router : URLRouter;
import vibe.http.server;

import valley.uri;
import valley.storage.sqlite;
import valley.service.crawler;
import valley.service.client;

SQLiteStorage storage;

shared static this() {
  auto router = new URLRouter;
  router.get("/ws", handleWebSockets(&handleWebSocketConnection));

  auto settings = new HTTPServerSettings;
  settings.port = 8080;
  settings.bindAddresses = ["::1", "127.0.0.1"];
  listenHTTP(settings, router);
}

void handleWebSocketConnection(scope WebSocket socket) {
  writeln("new connection");

  auto connection = new WebsocketConnection(socket);
  auto clientService = new ClientService(storage, connection);

  connection.start;
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

  auto crawlerService = new CrawlerService(storage);

  crawlerService.add(URI("http://ew.com/"));
  crawlerService.add(URI("https://www.wired.com/"));
  crawlerService.add(URI("http://www.imdb.com/"));
  /*crawlerService.add(URI("https://www.w3schools.com/"));
  crawlerService.add(URI("https://fsfe.org/"));
  /*crawlerService.add(URI("http://dlang.org/"));
  crawlerService.add(URI("https://code.dlang.org/"));
  crawlerService.add(URI("https://forum.dlang.org/group/learn"));
  crawlerService.add(URI("https://forum.dlang.org/group/announce"));
  crawlerService.add(URI("https://stackoverflow.com/questions/tagged/d"));
  crawlerService.add(URI("https://events.ccc.de/congress/2017/wiki/index.php/Main_Page"));*/

  crawlerService.start;

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
