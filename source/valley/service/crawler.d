module valley.service.crawler;

import std.stdio;
import std.datetime;
import std.conv;
import std.algorithm;
import std.string;
import std.array;

import vibe.core.core;

import valley.crawler;
import valley.uri;
import valley.htmlParser;
import valley.stemmer.english;
import valley.stemmer.cleaner;
import valley.storage.base;

class CrawlerService {
  Storage storage;
  Crawler crawler;

  this(Storage storage) {
    this.storage = storage;
    crawler = new Crawler("Valley (https://github.com/gedaiu/valley)",
        5.seconds, CrawlerSettings(["dlang.org", "forum.dlang.org",
          "code.dlang.org", "wiki.dlang.org", "blog.dlang.org",
          "events.ccc.de", "stackoverflow.com"]));

    crawler.onRequest(&request);
    crawler.onResult(&crawlerResult);
    crawler.onEmptyQueue(&fillQueue);
  }

  void start() {
    runTask({
      while (true) {
        try {
          crawler.next();
        }
        catch (Exception e) {
          e.writeln;
        }
        sleep(1.seconds);
      }
    });
  }

  void add(const URI uri) {
    crawler.add(uri);
  }

  private {
    void storeUnknownPage(scope CrawlPage crawlPage) {
      writeln("store unknown page");
      auto page = PageData("", crawlPage.uri, "", Clock.currTime, [], [], [],
          InformationType.other);

      try {
        storage.add(page);
      }
      catch (Exception e) {
        writeln("cannot save page to db `", crawlPage.uri, "`: ", e.msg);
      }
    }

    void storeRedirect(scope CrawlPage crawlPage) {
      writeln("store redirect");

      if ("Location" !in crawlPage.headers) {
        storeUnknownPage(crawlPage);
      }

      auto page = PageData("Redirect to " ~ crawlPage.headers["Location"], crawlPage.uri,
          crawlPage.statusCode.to!string, Clock.currTime,

          [URI(crawlPage.headers["Location"])], [], [], InformationType.redirect);

      try {
        storage.add(page);
      }
      catch (Exception e) {
        writeln("cannot save page to db `", crawlPage.uri, "`: ", e.msg);
      }
    }

    void storeUserError(scope CrawlPage crawlPage) {
      writeln("store user error");

      auto page = PageData(crawlPage.statusCode.to!string ~ " error",
          crawlPage.uri, "", Clock.currTime, [], [], [], InformationType.userError);

      try {
        storage.add(page);
      }
      catch (Exception e) {
        writeln("cannot save page to db `", crawlPage.uri, "`: ", e.msg);
      }
    }

    void crawlerResult(bool success, scope CrawlPage crawlPage) {
      writeln("GOT: ", success, " ", crawlPage.statusCode, " ", crawlPage.uri);
      writeln(crawlPage.headers);

      if (crawlPage.statusCode >= 300 && crawlPage.statusCode < 400) {
        storeRedirect(crawlPage);
        return;
      }

      if (crawlPage.statusCode >= 400 && crawlPage.statusCode < 500) {
        storeUserError(crawlPage);
        return;
      }

      if (crawlPage.content == "" || !success || "Content-Type" !in crawlPage.headers
          || !crawlPage.headers["Content-Type"].startsWith("text/html")) {
        storeUnknownPage(crawlPage);
        return;
      }

      auto document = new HTMLDocument(crawlPage.uri, crawlPage.content);

      auto stem = new EnStemmer;

      auto page = PageData(document.title, crawlPage.uri, document.preview,
          Clock.currTime, document.links.map!(a => URI(a)).array, [],
          document.plainText.clean.split(" ").map!(a => a.strip.toLower)
          .map!(a => stem.get(a)).array, InformationType.webPage);

      try {
        storage.add(page);
      }
      catch (Exception e) {
        writeln("cannot save page to db `", crawlPage.uri, "`: ", e.msg);
      }
    }

    void fillQueue(immutable string authority) {
      writeln("Get more links for ", authority);
      auto seed = storage.pending(1.days, 10, authority);

      foreach (uri; seed) {
        writeln("add ", uri.toString);
        crawler.add(uri);
      }
    }
  }
}
