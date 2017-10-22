import std.stdio;


import vibe.core.log;
import vibe.core.net;
import vibe.stream.operations;
import vibe.stream.tls;
import vibe.core.log;
import core.thread;

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