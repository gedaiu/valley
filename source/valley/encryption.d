module valley.encryption;

import std.exception;
import std.string;
import std.conv;
import std.stdio;
import std.file;
import std.base64;
import std.bitmanip;

import deimos.openssl.rand;
import deimos.openssl.bio;
import deimos.openssl.x509;
import deimos.openssl.pem;
import deimos.openssl.rsa;
import deimos.openssl.err;
import deimos.openssl.ssl;

version(unittest) import fluent.asserts;

extern (C)
{
  X509* PEM_read_bio_X509(BIO* bp, X509** x, pem_password_cb* callback, void* u);
}

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

  this(const ubyte[] key, const ubyte[] iv) {
    enforce(key.length == 16, "The key must have size 16");
    enforce(iv.length == 16, "The iv must have size 16");

    this.key = key;
    this.iv = iv;

    EVP_CIPHER_CTX_init(&ctx);
    EVP_CipherInit_ex(&ctx, EVP_aes_128_cbc(), null, null, null, 1);

    enforce(EVP_CIPHER_CTX_key_length(&ctx) == key.length);
    enforce(EVP_CIPHER_CTX_iv_length(&ctx) == iv.length);
  }

  this()
  {
    ubyte[16] data;
    EVP_CIPHER_CTX_init(&ctx);
    auto result = EVP_CipherInit_ex(&ctx, EVP_aes_128_cbc(), null, null, null, 1);
    enforce(result == 1, ERR_error_string(ERR_get_error(), null).fromStringz);

    enforce(EVP_CIPHER_CTX_key_length(&ctx) == key.length);
    enforce(EVP_CIPHER_CTX_iv_length(&ctx) == iv.length);

    result = RAND_bytes(data.ptr, data.length);
    enforce(result == 1, ERR_error_string(ERR_get_error(), null).fromStringz);
    key = data.dup;

    result = RAND_bytes(data.ptr, data.length);
    enforce(result == 1, ERR_error_string(ERR_get_error(), null).fromStringz);
    iv = data.dup;
  }

  ~this() {
    EVP_CIPHER_CTX_cleanup(&ctx);
  }

  private ubyte[] applyCipher(const ubyte[] data) {
    ubyte[] result;
    ubyte[] buffer;

    buffer.length = data.length + key.length;
    int len;

    auto success = EVP_CipherUpdate(&ctx, buffer.ptr, &len, data.ptr, data.length.to!int);
    enforce(success == 1, ERR_error_string(ERR_get_error(), null).fromStringz);
    result = buffer[0 .. len].dup;

    success = EVP_CipherFinal_ex(&ctx, buffer.ptr, &len);
    enforce(success == 1, ERR_error_string(ERR_get_error(), null).fromStringz);
    result ~= buffer[0 .. len];

    return result;
  }

  private ubyte[] applyCipher(char[] data) {
    ubyte[] byteData = cast(ubyte[]) data;
    return applyCipher(byteData);
  }

  ubyte[] encrypt(string data)
  {
    auto success = EVP_CipherInit_ex(&ctx, null, null, key.dup.ptr, iv.dup.ptr, 1);
    enforce(success == 1, ERR_error_string(ERR_get_error(), null).fromStringz);

    ubyte[16] padding;
    success = RAND_bytes(padding.ptr, padding.length);
    enforce(success == 1, ERR_error_string(ERR_get_error(), null).fromStringz);

    auto stringPadding = Base64.encode(padding);
    auto diff = key.length - data.length % key.length;

    return applyCipher(data.dup ~ stringPadding[0 .. diff]);
  }

  string decrypt(ubyte[] data)
  {
    auto result = EVP_CipherInit_ex(&ctx, null, null, key.dup.ptr, iv.dup.ptr, 0);
    enforce(result == 1, ERR_error_string(ERR_get_error(), null).fromStringz);

    return (cast(char*) applyCipher(data.dup).ptr).fromStringz.to!string;
  }
}

/// AES should encrypt a text
unittest
{
  auto aes = new AES();
  auto result = aes.encrypt("some text");

  auto aes2 = new AES(aes.key, aes.iv);
  aes2.decrypt(result).should.startWith("some text");
}

/// AES should encrypt an empty string
unittest
{
  auto aes = new AES();

  ({
    aes.encrypt("");
  }).should.not.throwAnyException;
}

/// AES not should encrypt the same string to the same sequence
unittest
{
  auto aes = new AES();
  auto result1 = aes.encrypt("string");
  auto result2 = aes.encrypt("string");

  result1.should.not.equal(result2);
}

/// AES should encrypt a long text
unittest {
auto aes = new AES();
  auto result = aes.encrypt("some text some text some text some text");

  auto aes2 = new AES(aes.key, aes.iv);
  aes2.decrypt(result).should.startWith("some text some text some text some text");
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

    ubyte[33] key = aes.key ~ aes.iv ~ [ (16 - message.length % 16).to!ubyte ];
    auto temp = RSA_public_encrypt(key.length.to!int, key.ptr, encryptedData.ptr, rsaPubKey, RSA_PKCS1_OAEP_PADDING);

    return encryptedData ~ aes.encrypt(message);
  }
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
    auto keySize = RSA_size(rsa_privkey);
    decrypted.length = keySize;
    auto prefix = data[0 .. decrypted.length];

    auto success = RSA_private_decrypt(prefix.length.to!int, prefix.ptr, decrypted.ptr, rsa_privkey, RSA_PKCS1_OAEP_PADDING);
    enforce(success != -1, ERR_error_string(ERR_get_error(), null).fromStringz);

    auto rsa = new AES(decrypted[0 .. 16], decrypted[16 .. 32]);
    auto extra = decrypted[32];

    auto result = rsa.decrypt(data[keySize .. $]);

    return result[0 .. $ - extra];
  }
}
