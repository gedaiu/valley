module tests.valley.crawler;

import fluent.asserts;
import trial.discovery.spec;

import valley.crawler;
import valley.uri;
import valley.robots;

import std.file;
import std.conv;
import std.datetime;
import std.file;
import std.string;
import std.conv;

import trial.step;

void nullSinkResult(scope CrawlPage) {
}

void failureRequest(const URI uri, void delegate(scope CrawlPage) @system callback) {
  assert(false, "No request should be performed");
}

private alias suite = Spec!({

  describe("the crawler", {

    it("should GET the robots.txt on the first request", {
      auto crawler = new Crawler("", 0.seconds);
      int index;

      void requestHandler(const URI uri, void delegate(scope CrawlPage) @system callback) {
        scope (exit) {
          index++;
        }

        if (index == 0) {
          uri.toString.should.equal("http://something.com/robots.txt");
        }

        if (index == 1) {
          uri.toString.should.equal("http://something.com");
        }

        string[string] headers;
        callback(CrawlPage(uri, 200, headers, ""));
      }

      crawler.onRequest(&requestHandler);
      crawler.onResult(&nullSinkResult);
      crawler.add(URI("http://something.com"));
      crawler.next();

      index.should.equal(2);
    });

    it("should GET all the added uris", {
      auto crawler = new Crawler("", 0.seconds);
      string[] fetchedUris;

      void requestHandler(const URI uri, void delegate(scope CrawlPage) @system callback) {
        fetchedUris ~= uri.toString;

        string[string] headers;
        callback(CrawlPage(uri, 200, headers, ""));
      }

      crawler.onRequest(&requestHandler);
      crawler.onResult(&nullSinkResult);
      crawler.add(URI("http://something.com"));
      crawler.add(URI("http://something.com/page.html"));
      crawler.next();
      crawler.next();

      fetchedUris.should.contain(["http://something.com", "http://something.com/page.html"]);
    });

    it("should follow the redirects to absolute locations", {
      auto crawler = new Crawler("", 0.seconds);
      string[] fetchedUris;

      void requestHandler(const URI uri, void delegate(scope CrawlPage) @system callback) {
        string[string] headers;

        if (uri.toString == "http://something.com") {
          headers["Location"] = "https://other.com/";
          callback(CrawlPage(uri, 301, headers, ""));
          return;
        }

        callback(CrawlPage(uri, 200, headers, ""));
      }

      void pageResult(scope CrawlPage page) {
        fetchedUris ~= page.uri.toString;
      }

      crawler.onRequest(&requestHandler);
      crawler.onResult(&pageResult);
      crawler.add(URI("http://something.com"));
      crawler.next();
      crawler.next();

      fetchedUris.should.contain(["https://other.com/"]);
    });

    it("should follow the redirects to relative locations", {
      auto crawler = new Crawler("", 0.seconds);
      string[] fetchedUris;

      void requestHandler(const URI uri, void delegate(scope CrawlPage) @system callback) {
        string[string] headers;

        if (uri.toString == "http://something.com") {
          headers["Location"] = "/index.html";
          callback(CrawlPage(uri, 301, headers, ""));
          return;
        }

        callback(CrawlPage(uri, 200, headers, ""));
      }

      void pageResult(scope CrawlPage page) {
        fetchedUris ~= page.uri.toString;
      }

      crawler.onRequest(&requestHandler);
      crawler.onResult(&pageResult);
      crawler.add(URI("http://something.com"));
      crawler.next();
      crawler.next();

      fetchedUris.should.contain(["http://something.com/index.html"]);
    });

    it("should follow the redirects to absolute locations without scheme", {
      auto crawler = new Crawler("", 0.seconds);
      string[] fetchedUris;

      void requestHandler(const URI uri, void delegate(scope CrawlPage) @system callback) {
        string[string] headers;

        if (uri.toString == "http://something.com") {
          headers["Location"] = "//something.com/";
          callback(CrawlPage(uri, 301, headers, ""));
          return;
        }

        callback(CrawlPage(uri, 200, headers, ""));
      }

      void pageResult(scope CrawlPage page) {
        fetchedUris ~= page.uri.toString;
      }

      crawler.onRequest(&requestHandler);
      crawler.onResult(&pageResult);
      crawler.add(URI("http://something.com"));
      crawler.next();
      crawler.next();

      fetchedUris.should.contain(["http://something.com/"]);
    });

    it("should query robots once", {
      import std.stdio;
      import vibe.core.core;

      auto crawler = new Crawler("", 0.seconds);
      string[] fetchedUris;

      void requestHandler(const URI uri, void delegate(scope CrawlPage) @system callback) {
        yield;
        fetchedUris ~= uri.toString;

        string[string] headers;
        callback(CrawlPage(uri, 200, headers, ""));
      }

      crawler.onRequest(&requestHandler);
      crawler.onResult(&nullSinkResult);

      runTask({ crawler.add(URI("http://something.com")); });

      runTask({ crawler.add(URI("http://something.com/page.html")); });

      processEvents;

      crawler.next();
      crawler.next();
      crawler.next();

      fetchedUris.should.containOnly(["http://something.com/robots.txt",
      "http://something.com", "http://something.com/page.html"]);
    });

    it("should not get anything if the queues are empty", {
      auto crawler = new Crawler("", 0.seconds);

      ({
        crawler.onRequest(&failureRequest);
        crawler.onResult(&nullSinkResult);
        crawler.next();
      }).should.not.throwAnyException;
    });

    it("shoult GET all the added uris applying the crawler delay", {
      auto crawler = new Crawler("", 1.seconds);
      string[] fetchedUris;

      int index;
      void requestHandler(const URI uri, void delegate(scope CrawlPage) @system callback) {
        fetchedUris ~= uri.toString;

        string[string] headers;
        callback(CrawlPage(uri, 200, headers, ""));
        index++;
      }

      crawler.onRequest(&requestHandler);
      crawler.onResult(&nullSinkResult);
      crawler.add(URI("http://something.com"));
      crawler.add(URI("http://something.com/page.html"));

      auto begin = Clock.currTime;
      do {
        crawler.next();
      }
      while (index < 3);
      (Clock.currTime - begin).should.be.greaterThan(1.seconds);
    });
  });

  describe("vibe request", {
    it("should be able to get the first internet page", {
      bool hasResult;
      string firstCrawlPage = "http://info.cern.ch/hypertext/WWW/TheProject.html";

      request(URI(firstCrawlPage), (scope CrawlPage page) {
        hasResult = true;
        page.uri.toString.should.equal(firstCrawlPage);
        page.statusCode.should.equal(200);
        page.content.should.contain("WorldWideWeb");

        page.headers.keys.should.containOnly(["Last-Modified", "Accept-Ranges",
        "Content-Length", "Connection", "Server", "Content-Type", "Date", "ETag"]);

        page.headers["Content-Type"].should.equal("text/html");
      });

      hasResult.should.equal(true);
    });
  });
});
