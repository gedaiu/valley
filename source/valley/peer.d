module valley.peer;

import std.algorithm;
import std.meta;
import std.array;
import std.stdio;
import std.file;
import std.conv;
import std.exception;
import std.string;

import deimos.openssl.rand;
import deimos.openssl.bio;
import deimos.openssl.x509;
import deimos.openssl.pem;
import deimos.openssl.rsa;
import deimos.openssl.err;
import deimos.openssl.ssl;

alias OnMessageEvent = void delegate(Message message) nothrow;

shared static this()
{
  SSL_load_error_strings();
  ERR_load_BIO_strings();
  OpenSSL_add_all_algorithms();
}

class AES
{
  import deimos.openssl.aes;
  import deimos.openssl.rand;

  private
  {
    EVP_CIPHER_CTX ctx;
  }

  const
  {
    ubyte[16] key;
    ubyte[16] iv;
  }

  this()
  {
    ubyte[16] data;
    EVP_CIPHER_CTX_init(&ctx);
    EVP_CipherInit_ex(&ctx, EVP_aes_128_cbc(), null, null, null, 1);

    enforce(EVP_CIPHER_CTX_key_length(&ctx) == data.length);
    enforce(EVP_CIPHER_CTX_iv_length(&ctx) == data.length);

    auto result = RAND_bytes(data.ptr, data.length);
    enforce(result == 1, ERR_error_string(ERR_get_error(), null).fromStringz);
    key = data.dup;

    result = RAND_bytes(data.ptr, data.length);
    enforce(result == 1, ERR_error_string(ERR_get_error(), null).fromStringz);
    iv = data.dup;
  }

  auto encrypt(string data)
  {
    EVP_CipherInit_ex(&ctx, null, null, key.dup.ptr, iv.dup.ptr, 1);

    data ~= "\0";
    ubyte[] encrypted;
    int encryptedLen = ((data.length / key.length).to!int + 1) * key.length.to!int;
    int dataLen = data.length.to!int;
    encrypted.length = encryptedLen;

    const(ubyte)* dataCopy = cast(const(ubyte)*) data.dup.toStringz;

    auto result = EVP_CipherUpdate(&ctx, encrypted.ptr, &encryptedLen, dataCopy, dataLen);
    enforce(result == 1, ERR_error_string(ERR_get_error(), null).fromStringz);

    result = EVP_CipherFinal_ex(&ctx, encrypted.ptr, &encryptedLen);
    enforce(result == 1, ERR_error_string(ERR_get_error(), null).fromStringz);

    return encrypted;
  }

  string decrypt(ubyte[] data)
  {
    EVP_CipherInit_ex(&ctx, null, null, key.dup.ptr, null, 0);

    ubyte[] decrypted;
    decrypted.length = data.length;

    int decryptedLen = data.length.to!int;
    int dataLen = data.length.to!int;

    auto result = EVP_CipherUpdate(&ctx, decrypted.ptr, &decryptedLen, data.ptr, dataLen);
    enforce(result == 1, ERR_error_string(ERR_get_error(), null).fromStringz);

    result = EVP_CipherFinal_ex(&ctx, decrypted.ptr, &decryptedLen);
    enforce(result == 1, ERR_error_string(ERR_get_error(), null).fromStringz);

    return (cast(char*) decrypted.ptr).fromStringz.to!string;
  }
}

/// AES should encrypt a text
unittest
{
  auto aes = new AES();

  auto result = aes.encrypt("some text");

  aes.decrypt(result).should.equal("some text");
}

struct Message
{
  string destinationId;
  string data;
  string sourceId;
}

struct Packet
{
  string sourceId;
  string destinationId;

  ubyte[] data;
  string signature;
}

extern (C)
{
  X509* PEM_read_bio_X509(BIO* bp, X509** x, pem_password_cb* callback, void* u);
}

class Certificate
{
  private
  {
    rsa_st* rsaPubKey;
    BIO* bio;
    X509* certificate;
  }

  this(string fileName)
  {
    string certificateString = readText(fileName);

    EVP_PKEY* pubkey;
    bio = BIO_new(BIO_s_mem());

    auto lTemp = BIO_write(bio, cast(const(void)*) certificateString.ptr,
        certificateString.length.to!int);
    enforce(lTemp == certificateString.length);

    certificate = PEM_read_bio_X509(bio, null, null, null);
    pubkey = X509_get_pubkey(certificate);
    scope (exit)
      EVP_PKEY_free(pubkey);

    rsaPubKey = EVP_PKEY_get1_RSA(pubkey);
  }

  ~this()
  {
    X509_free(certificate);
    BIO_vfree(bio);
    RSA_free(rsaPubKey);
  }

  ubyte[] encrypt(string message)
  {
    auto aes = new AES();
    ubyte[] encryptedData;

    encryptedData.length = RSA_size(rsaPubKey);
    auto temp = RSA_public_encrypt(message.length.to!int, (cast(ubyte[]) message)
        .ptr, encryptedData.ptr, rsaPubKey, RSA_PKCS1_OAEP_PADDING);

    return encryptedData;
  }
}

Packet toPacket(Message message, string sourceId)
{
  auto certificate = new Certificate("keys/server.crt");

  return Packet(sourceId, message.destinationId, certificate.encrypt(message.data));
}

class PrivateKey
{

  private
  {
    RSA* rsa_privkey;
    BIO* bio;
  }

  this(string fileName)
  {
    string certificateString = readText("keys/server.key");

    bio = BIO_new(BIO_s_mem());

    auto lTemp = BIO_write(bio, cast(const(void)*) certificateString.ptr,
        certificateString.length.to!int);
    enforce(lTemp == certificateString.length, ERR_error_string(ERR_get_error(), null).fromStringz);

    rsa_privkey = PEM_read_bio_RSAPrivateKey(bio, &rsa_privkey, null, null);
  }

  ~this()
  {
    BIO_vfree(bio);
    RSA_free(rsa_privkey);
  }

  string decrypt(ubyte[] data)
  {
    ubyte[] decrypted;
    decrypted.length = RSA_size(rsa_privkey);

    auto result = RSA_private_decrypt(data.length.to!int, data.ptr,
        decrypted.ptr, rsa_privkey, RSA_PKCS1_OAEP_PADDING);
    enforce(result != -1, ERR_error_string(ERR_get_error(), null).fromStringz);

    auto pos = decrypted.countUntil(0);
    if (pos != -1)
    {
      decrypted = decrypted[0 .. pos];
    }

    return decrypted.assumeUTF;
  }
}

/// It should convert a Message to a Packet
unittest
{
  auto message = Message("destinationId", "some data");
  auto packet = message.toPacket("sourceId");

  packet.sourceId.should.equal("sourceId");
  packet.destinationId.should.equal("destinationId");
  packet.data.length.should.be.greaterThan(0);
  packet.signature.length.should.equal(0);
}

Message decrypt(Packet packet)
{
  auto privateKey = new PrivateKey("keys/server.key");

  return Message(packet.destinationId, privateKey.decrypt(packet.data), packet.sourceId);
}

/// It should decode a Packet to a message
unittest
{
  auto packet = Message("destinationId", "some data").toPacket("sourceId");
  auto message = packet.decrypt();

  message.sourceId.should.equal("sourceId");
  message.destinationId.should.equal("destinationId");
  message.data.should.equal("some data");
}

/// It should decode a long Packet to a message
unittest
{
  import std.random;

  auto rnd = Random(42);

  string data;
  foreach (i; 0 .. 1000)
  {
    data ~= uniform(0, 9, rnd).to!string;
  }

  data.writeln;

  auto packet = Message("destinationId", data).toPacket("sourceId");
  auto message = packet.decrypt();

  message.sourceId.should.equal("sourceId");
  message.destinationId.should.equal("destinationId");
  message.data.should.equal(data);
}

class PeerCollection
{
  ValleyPeer[] peers;

  alias peers this;

  ValleyPeer relayTo(string peerId)
  {
    struct Pair
    {
      ValleyPeer peer;
      int distance;
    }

    auto knownPeer = peers.map!(a => Pair(a, a.distanceTo(peerId)))
      .array.sort!"a.distance < b.distance";

    if (knownPeer.length == 0)
    {
      throw new Exception("No peer.");
    }

    return knownPeer[0].peer;
  }
}

class ValleyPeer
{
  string id;
  PeerCollection peers;

  private
  {
    OnMessageEvent[] onMessageEvents;
  }

  this()
  {
    peers = new PeerCollection;
  }

  void onMessage(OnMessageEvent event)
  {
    onMessageEvents ~= event;
  }

  int distanceTo(string peerId)
  {
    if (peerId == id)
    {
      return 0;
    }

    if (peers.map!"a.id".canFind(peerId))
    {
      return 1;
    }

    return int.max;
  }

  void send(Message message)
  {
    if (message.destinationId == id)
    {
      foreach (event; onMessageEvents)
      {
        event(message);
      }

      return;
    }

    auto peer = peers.relayTo(message.destinationId);
    peer.send(message);
  }
}

version (unittest)
{
  import fluent.asserts;
}

/// It should send a message using a relay peer
unittest
{
  auto client1 = new ValleyPeer;
  client1.id = "client1";

  auto client2 = new ValleyPeer;
  client2.id = "client2";

  auto client3 = new ValleyPeer;
  client3.id = "client3";

  client1.peers ~= client2;
  client2.peers ~= client3;

  bool gotMessage;

  void messageHandler(Message message) nothrow
  {
    try
    {
      message.destinationId.should.equal(client3.id);
      message.data.should.equal("hello");
      gotMessage = true;
    }
    catch (Exception e)
    {
    }
  }

  client3.onMessage(&messageHandler);

  auto message = Message(client3.id, "hello");

  client1.send(message);

  gotMessage.should.equal(true);
}

/// It should send a message using a relay peer without sending to
/// peers that don't have a link to the destination peer
unittest
{
  auto client1 = new ValleyPeer;
  client1.id = "client1";

  auto client2 = new ValleyPeer;
  client2.id = "client2";

  auto client3 = new ValleyPeer;
  client3.id = "client3";

  auto client4 = new ValleyPeer;
  client4.id = "client4";

  client1.peers ~= [client4, client2];
  client2.peers ~= client3;

  bool gotMessage;

  void messageHandler(Message message) nothrow
  {
    gotMessage = true;
  }

  client4.onMessage(&messageHandler);

  auto message = Message(client3.id, "hello");

  client1.send(message);

  gotMessage.should.equal(false);
}
