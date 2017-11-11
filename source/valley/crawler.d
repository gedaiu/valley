module valley.crawler;

import valley.uri;

import vibe.http.client;
import vibe.stream.operations;

import std.functional;
import std.socket;
import std.datetime;

version (unittest) import fluent.asserts;

struct Page
{
  URI uri;
  string[string] headers;
  string content;
}

class Crawler
{

  private
  {
    void delegate(scope Page) @system callback;
  }

  void add(URI uri)
  {

  }

  void next()
  {
    HTTPClientSettings settings = new HTTPClientSettings;
    settings.dnsAddressFamily = AddressFamily.INET;

    requestHTTP("http://info.cern.ch/hypertext/WWW/TheProject.html", (scope HTTPClientRequest req) {
      // could add headers here before sending,
      // write a POST body, or do similar things.
    }, (scope HTTPClientResponse res) {
      string[string] headers;

      foreach(string key, string value; res.headers) {
        headers[key] = value;
      }

      auto page = Page(URI("http://info.cern.ch/hypertext/WWW/TheProject.html"), headers, res.bodyReader.readAllUTF8());

      callback(page);
    }, settings);
  }

  void onResult(T)(T callback)
  {
    this.callback = callback.toDelegate;
  }
}

/// It should be able to get the first internet page
unittest
{
  auto crawler = new Crawler();
  bool hasResult;

  crawler.onResult((scope Page page) {
    hasResult = true;
    page.uri.toString.should.equal("http://info.cern.ch/hypertext/WWW/TheProject.html");
    page.content.should.contain("WorldWideWeb");

    page.headers.keys.should.containOnly(["Last-Modified",
      "Accept-Ranges",
      "Content-Length",
      "Connection",
      "Server",
      "Content-Type",
      "Date",
      "ETag"]);

    page.headers["Content-Type"].should.equal("text/html");
  });

  crawler.add(URI("http://info.cern.ch/hypertext/WWW/TheProject.html"));
  crawler.next;

  hasResult.should.equal(true);
}
