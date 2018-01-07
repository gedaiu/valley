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

void nullSinkResult(bool, scope CrawlPage) {
}

void failureRequest(const URI uri, void delegate(bool success, scope CrawlPage) @system callback) {
  assert(false, "No request should be performed");
}

private alias suite = Spec!({

  describe("the crawler", {

    it("should GET the robots.txt on the first request", {
      auto crawler = new Crawler("", 0.seconds, CrawlerSettings(["something.com"]));
      int index;

      void requestHandler(const URI uri, void delegate(bool success, scope CrawlPage) @system callback) {
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
        callback(true, CrawlPage(uri, 200, headers, ""));
      }

      crawler.onRequest(&requestHandler);
      crawler.onResult(&nullSinkResult);
      crawler.add(URI("http://something.com"));
      crawler.next();

      index.should.equal(2);
    });

    it("should GET all the added uris", {
      auto crawler = new Crawler("", 0.seconds, CrawlerSettings(["something.com"]));
      string[] fetchedUris;

      void requestHandler(const URI uri, void delegate(bool, scope CrawlPage) @system callback) {
        fetchedUris ~= uri.toString;

        string[string] headers;
        callback(true, CrawlPage(uri, 200, headers, ""));
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
      auto crawler = new Crawler("", 0.seconds, CrawlerSettings(["something.com", "other.com"]));
      string[] fetchedUris;

      void requestHandler(const URI uri, void delegate(bool, scope CrawlPage) @system callback) {
        string[string] headers;

        if (uri.toString == "http://something.com") {
          headers["Location"] = "https://other.com/";
          callback(true, CrawlPage(uri, 301, headers, ""));
          return;
        }

        callback(true, CrawlPage(uri, 200, headers, ""));
      }

      void pageResult(bool, scope CrawlPage page) {
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
      auto crawler = new Crawler("", 0.seconds, CrawlerSettings(["something.com"]));
      string[] fetchedUris;

      void requestHandler(const URI uri, void delegate(bool, scope CrawlPage) @system callback) {
        string[string] headers;

        if (uri.toString == "http://something.com") {
          headers["Location"] = "/index.html";
          callback(true, CrawlPage(uri, 301, headers, ""));
          return;
        }

        callback(true, CrawlPage(uri, 200, headers, ""));
      }

      void pageResult(bool, scope CrawlPage page) {
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
      auto crawler = new Crawler("", 0.seconds, CrawlerSettings(["something.com"]));
      string[] fetchedUris;

      void requestHandler(const URI uri, void delegate(bool, scope CrawlPage) @system callback) {
        string[string] headers;

        if (uri.toString == "http://something.com") {
          headers["Location"] = "//something.com/";
          callback(true, CrawlPage(uri, 301, headers, ""));
          return;
        }

        callback(true, CrawlPage(uri, 200, headers, ""));
      }

      void pageResult(bool, scope CrawlPage page) {
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

      auto crawler = new Crawler("", 0.seconds, CrawlerSettings(["something.com"]));
      string[] fetchedUris;

      void requestHandler(const URI uri, void delegate(bool, scope CrawlPage) @system callback) {
        yield;
        fetchedUris ~= uri.toString;

        string[string] headers;
        callback(true, CrawlPage(uri, 200, headers, ""));
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
      auto crawler = new Crawler("", 0.seconds, CrawlerSettings());

      ({
        crawler.onRequest(&failureRequest);
        crawler.onResult(&nullSinkResult);
        crawler.next();
      }).should.not.throwAnyException;
    });

    it("should GET all the added uris applying the crawler delay", {
      auto crawler = new Crawler("", 1.seconds, CrawlerSettings(["something.com"]));
      string[] fetchedUris;

      int index;
      void requestHandler(const URI uri, void delegate(bool, scope CrawlPage) @system callback) {
        fetchedUris ~= uri.toString;

        string[string] headers;
        callback(true, CrawlPage(uri, 200, headers, ""));
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

    it("should GET pages only from the whitelisted domains", {
      string[] fetchedUris;
      void requestHandler(const URI uri, void delegate(bool, scope CrawlPage) @system callback) {
        fetchedUris ~= uri.toString;

        string[string] headers;
        callback(true, CrawlPage(uri, 200, headers, ""));
      }

      auto crawler = new Crawler("", 0.seconds, CrawlerSettings([ "white.com" ]));
      crawler.onRequest(&requestHandler);
      crawler.onResult(&nullSinkResult);

      crawler.add(URI("http://black.com"));
      crawler.add(URI("http://white.com"));
      crawler.next();
      crawler.next();
      crawler.next();

      fetchedUris.should.containOnly(["http://white.com/robots.txt", "http://white.com"]);
    });

    it("should trigger an event when there is no page available to scrape for a domain", {
      string emptyAuthority;
      void requestHandler(const URI uri, void delegate(bool, scope CrawlPage) @system callback) {
        string[string] headers;
        callback(true, CrawlPage(uri, 200, headers, ""));
      }

      void emptyQueueEvent(immutable string authority) {
        emptyAuthority = authority;
      }

      auto crawler = new Crawler("", 0.seconds, CrawlerSettings([ "white.com:8080" ]));
      crawler.onRequest(&requestHandler);
      crawler.onResult(&nullSinkResult);
      crawler.onEmptyQueue(&emptyQueueEvent);

      crawler.add(URI("http://white.com:8080"));
      crawler.add(URI("http://white.com:8080/page.html"));
      crawler.next();
      emptyAuthority.should.equal("");
      crawler.next();
      emptyAuthority.should.equal("white.com:8080");
    });

    it("should trigger an event for each domain when there is no page available to scrape", {
      string[] emptyAuthority;
      void requestHandler(const URI uri, void delegate(bool, scope CrawlPage) @system callback) {
        string[string] headers;
        callback(true, CrawlPage(uri, 200, headers, ""));
      }

      void emptyQueueEvent(immutable string authority) {
        emptyAuthority ~= authority;
      }

      auto crawler = new Crawler("", 0.seconds, CrawlerSettings([ "white.com:8080", "other.com" ]));
      crawler.onRequest(&requestHandler);
      crawler.onResult(&nullSinkResult);
      crawler.onEmptyQueue(&emptyQueueEvent);

      crawler.add(URI("http://white.com:8080"));
      crawler.next();
      emptyAuthority.should.containOnly(["white.com:8080", "other.com"]);
    });
  });

  describe("vibe request", {
    it("should be able to get the first internet page", {
      bool hasResult;
      string firstCrawlPage = "http://info.cern.ch/hypertext/WWW/TheProject.html";

      request(URI(firstCrawlPage), (bool success, scope CrawlPage page) {
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
