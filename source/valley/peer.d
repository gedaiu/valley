module valley.peer;

import std.algorithm;
import std.meta;
import std.array;
import std.stdio;
import std.file;
import std.conv;
import std.exception;
import std.string;

import deimos.openssl.bio;
import deimos.openssl.x509;
import deimos.openssl.pem;
import deimos.openssl.rsa;
import deimos.openssl.err;

alias OnMessageEvent = void delegate(Message message) nothrow;

struct Message {
  string destinationId;
  string data;
  string sourceId;
}

struct Packet {
  string sourceId;
  string destinationId;

  ubyte[] data;
  string signature;
}

extern(C) {
  X509 *PEM_read_bio_X509(BIO *bp, X509 **x, pem_password_cb* callback, void *u);
}

class Certificate {
  private {
    rsa_st* rsaPubKey;
    BIO *bio;
    X509 *certificate;
  }

  this(string fileName) {
    string certificateString = readText(fileName);

    EVP_PKEY *pubkey;
    bio = BIO_new(BIO_s_mem());

    auto lTemp = BIO_write(bio, cast(const(void)*) certificateString.ptr, certificateString.length.to!int);
    enforce(lTemp == certificateString.length);

    certificate = PEM_read_bio_X509(bio, null, null, null);
    pubkey = X509_get_pubkey(certificate);
    scope(exit) EVP_PKEY_free(pubkey);

    rsaPubKey = EVP_PKEY_get1_RSA(pubkey);
  }

  ~this() {
    X509_free(certificate);
    BIO_vfree(bio);
    RSA_free(rsaPubKey);
  }

  ubyte[] encrypt(string message) {
    ubyte[] encryptedData;

    encryptedData.length = RSA_size(rsaPubKey);
    auto temp = RSA_public_encrypt(message.length.to!int, (cast(ubyte[]) message).ptr, encryptedData.ptr, rsaPubKey, RSA_PKCS1_OAEP_PADDING);

    return encryptedData;
  }
}

Packet toPacket(Message message, string sourceId) {
  auto certificate = new Certificate("keys/server.crt");

  return Packet(sourceId, message.destinationId, certificate.encrypt(message.data));
}

class PrivateKey {

  private {
    RSA *rsa_privkey;
    BIO *bio;
  }

  this(string fileName) {
    string certificateString = readText("keys/server.key");

    bio = BIO_new(BIO_s_mem());

    auto lTemp = BIO_write(bio, cast(const(void)*) certificateString.ptr, certificateString.length.to!int);
    enforce(lTemp == certificateString.length);

    rsa_privkey = PEM_read_bio_RSAPrivateKey(bio, &rsa_privkey, null, null);
  }

  ~this() {
    BIO_vfree(bio);
    RSA_free(rsa_privkey);
  }

  string decrypt(ubyte[] data) {
    ubyte[] decrypted;
    decrypted.length = RSA_size(rsa_privkey);

    auto resultDecrypt = RSA_private_decrypt(data.length.to!int, data.ptr, decrypted.ptr, rsa_privkey, RSA_PKCS1_OAEP_PADDING);
    enforce(resultDecrypt > 0);

    auto pos = decrypted.countUntil(0);
    if(pos != -1) {
      decrypted = decrypted[0..pos];
    }

    return decrypted.assumeUTF;
  }
}

/// It should convert a Message to a Packet
unittest {
  auto message = Message("destinationId", "some data");
  auto packet = message.toPacket("sourceId");

  packet.sourceId.should.equal("sourceId");
  packet.destinationId.should.equal("destinationId");
  packet.data.length.should.be.greaterThan(0);
  packet.signature.length.should.equal(0);
}

Message decrypt(Packet packet) {
  auto privateKey = new PrivateKey("keys/server.key");

  return Message(packet.destinationId, privateKey.decrypt(packet.data), packet.sourceId);
}

/// It should decode a Packet to a message
unittest {
  auto packet = Message("destinationId", "some data").toPacket("sourceId");
  auto message = packet.decrypt();

  message.sourceId.should.equal("sourceId");
  message.destinationId.should.equal("destinationId");
  message.data.should.equal("some data");
}

class PeerCollection {
  ValleyPeer[] peers;

  alias peers this;

  ValleyPeer relayTo(string peerId) {
    struct Pair {
      ValleyPeer peer;
      int distance;
    }

    auto knownPeer = peers.map!(a => Pair(a, a.distanceTo(peerId))).array.sort!"a.distance < b.distance";

    if(knownPeer.length == 0) {
      throw new Exception("No peer.");
    }

    return knownPeer[0].peer;
  }
}

class ValleyPeer {
  string id;
  PeerCollection peers;

  private {
    OnMessageEvent[] onMessageEvents;
  }

  this() {
    peers = new PeerCollection;
  }

  void onMessage(OnMessageEvent event) {
    onMessageEvents ~= event;
  }

  int distanceTo(string peerId) {
    if(peerId == id) {
      return 0;
    }

    if(peers.map!"a.id".canFind(peerId)) {
      return 1;
    }

    return int.max;
  }

  void send(Message message) {
    if(message.destinationId == id) {
      foreach(event; onMessageEvents) {
        event(message);
      }

      return;
    }

    auto peer = peers.relayTo(message.destinationId);
    peer.send(message);
  }
}

version(unittest) {
  import fluent.asserts;
}

/// It should send a message using a relay peer
unittest {
  auto client1 = new ValleyPeer;
  client1.id = "client1";

  auto client2 = new ValleyPeer;
  client2.id = "client2";

  auto client3 = new ValleyPeer;
  client3.id = "client3";

  client1.peers ~= client2;
  client2.peers ~= client3;

  bool gotMessage;

  void messageHandler(Message message) nothrow {
    try {
      message.destinationId.should.equal(client3.id);
      message.data.should.equal("hello");
      gotMessage = true;
    } catch(Exception e) { }
  }

  client3.onMessage(&messageHandler);

  auto message = Message(client3.id, "hello");

  client1.send(message);

  gotMessage.should.equal(true);
}

/// It should send a message using a relay peer without sending to
/// peers that don't have a link to the destination peer
unittest {
  auto client1 = new ValleyPeer;
  client1.id = "client1";

  auto client2 = new ValleyPeer;
  client2.id = "client2";

  auto client3 = new ValleyPeer;
  client3.id = "client3";

  auto client4 = new ValleyPeer;
  client4.id = "client4";

  client1.peers ~= [ client4, client2 ];
  client2.peers ~= client3;

  bool gotMessage;

  void messageHandler(Message message) nothrow {
    gotMessage = true;
  }

  client4.onMessage(&messageHandler);

  auto message = Message(client3.id, "hello");

  client1.send(message);

  gotMessage.should.equal(false);
}