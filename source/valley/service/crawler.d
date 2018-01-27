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
          "imdb.com",
          "wired.com",
          "ew.com",
          "events.ccc.de", "stackoverflow.com", "w3schools.com", "fsfe.org"]));

    crawler.onRequest(&request);
    crawler.onResult(&crawlerResult);
    crawler.onEmptyQueue(&fillQueue);
  }

  void start() {
    runTask({
      while (true) {
        try {
          crawler.next();
        } catch (Exception e) {
          e.writeln;
        }

        if(crawler.isFullWorking) {
          sleep(1.seconds);
        }
      }
    });
  }

  void add(const URI uri) {
    crawler.add(uri);
  }

  private {
    void storeUnknownPage(scope CrawlPage crawlPage) {
      writeln("store unknown page");
      auto page = PageData("", crawlPage.uri, "", Clock.currTime, [], [], [], InformationType.other);

      try {
        storage.add(page);
      } catch (Exception e) {
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
      } catch (Exception e) {
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

      if(crawlPage.statusCode == 0) {
        return;
      }

      if (crawlPage.statusCode >= 300 && crawlPage.statusCode < 400) {
        storeRedirect(crawlPage);
        return;
      }

      if (crawlPage.statusCode >= 400 && crawlPage.statusCode < 500) {
        storeUserError(crawlPage);
        return;
      }

      if (crawlPage.content == "" || !success || "Content-Type" !in crawlPage.headers || !crawlPage.headers["Content-Type"].startsWith("text/html")) {
        storeUnknownPage(crawlPage);
        return;
      }

      auto document = new HTMLDocument(crawlPage.uri, crawlPage.content);
      URI[] links;

      if(!document.isNofollow) {
        links = document.links.map!(a => URI(a)).uniq.array;
      }

      if(document.isNoindex) {
        foreach(uri; links) {
          storage.add(PageData("", uri));
        }

        return;
      }

      auto stem = new EnStemmer;

      auto page = PageData(
        document.title,
        crawlPage.uri,
        document.preview,
        Clock.currTime,
        links,
        [],
        document.plainText.clean.split(" ").map!(a => a.strip.toLower).map!(a => stem.get(a)).uniq.array,
        InformationType.webPage);

      try {
        storage.add(page);
      } catch (Exception e) {
        writeln("cannot save page to db `", crawlPage.uri, "`: ", e.msg);
        debug writeln(e);
      }
    }

    void fillQueue(immutable string authority) {
      writeln("Get more links for ", authority);
      auto seed = storage.pending(5.days, 10, authority);

      foreach (uri; seed) {
        writeln("add ", uri.toString);
        crawler.add(uri);
      }
    }
  }
}
