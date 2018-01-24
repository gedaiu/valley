module tests.valley.storage.sqlite;

import fluent.asserts;
import trial.discovery.spec;

import valley.storage.sqlite;
import valley.storage.base;
import valley.uri;
import std.file;
import std.conv;
import std.datetime;

import d2sqlite3;

private alias suite = Spec!({
  describe("SQLite", {
    describe("when a page is added", {
      SQLiteStorage storage;
      Database db;
      SysTime time;

      beforeEach({
        if("test.db".exists) {
          "test.db".remove;
        }

        storage = new SQLiteStorage("test.db");
        time = SysTime.fromUnixTime(Clock.currTime.toUnixTime);

        Badge[] badges = [ Badge(BadgeType.approve, [1, 2, 3]) ];
        auto data = PageData(
          "some title",
          URI("http://example.com"),
          "some description",
          time,

          [ URI("http://example.com/page1"), URI("http://example.com/page2") ],
          badges,
          [ "some", "keywords" ],
          InformationType.webImage
        );

        storage.add(data);
        db = Database("test.db");
      });

      afterEach({
        storage.close;
        "test.db".remove;
      });

      it("should query the page", {
        auto result = storage.query("some description", 0, 100);

        result.length.should.equal(1);

        result[0].title.should.equal("some title");
        result[0].location.should.equal(URI("http://example.com"));
        result[0].description.should.equal("some description");
        result[0].time.should.be.equal(time);
        result[0].type.should.equal(InformationType.webImage);
        result[0].relations.should.equal([ URI("http://example.com/page1"), URI("http://example.com/page2") ]);
        result[0].keywords.should.equal([ "some", "keywords" ]);
        result[0].badges.should.equal([ Badge(BadgeType.approve, [1, 2, 3]) ]);
      });

      it("should add the page", {
        storage.exists(URI("http://example.com")).should.equal(true);
      });

      it("should add the links", {
        storage.exists(URI("http://example.com/page1")).should.equal(true);
        storage.exists(URI("http://example.com/page2")).should.equal(true);
      });

      it("should mark empty pages as pending", {
        storage.pending(0.seconds, 2, "example.com").should.containOnly([ URI("http://example.com/page1"), URI("http://example.com/page2")]);
      });

      it("should contain only 3 pages", {
        Statement statement = db.prepare("SELECT * FROM pages");

        string[] pages;
        foreach (Row row; statement.execute) {
          pages ~= row["location"].as!string;
        }

        statement.finalize;
        pages.should.containOnly([ "http://example.com", "http://example.com/page1", "http://example.com/page2"]);
      });

      it("should add the page", {
        Statement statement = db.prepare("SELECT * FROM pages WHERE id = 1 LIMIT 1");

        int found = 0;
        foreach (Row row; statement.execute) {
          row["id"].as!int.should.equal(1);
          row["title"].as!string.should.equal("some title");
          row["location"].as!string.should.equal("http://example.com");
          row["description"].as!string.should.equal("some description");
          row["time"].as!ulong.should.be.approximately(Clock.currTime.toUnixTime, 2000);
          row["type"].as!int.should.equal(1);
          found++;
        }

        statement.finalize;
        found.should.equal(1);
      });

      it("should add the keywords", {
        auto statement = db.prepare("SELECT * FROM keywords");

        string[] keywords;
        foreach (Row row; statement.execute) {
          keywords ~= row["id"].as!string ~ "." ~ row["keyword"].as!string;
        }

        statement.finalize;
        keywords.should.containOnly([ "1.some", "2.keywords" ]);
      });

      it("should add the keywordLinks", {
        auto statement = db.prepare("SELECT * FROM keywordLinks");

        string[] keywordLinks;
        foreach (Row row; statement.execute) {
          keywordLinks ~= row["pageId"].as!string ~ "." ~ row["keywordId"].as!string;
        }

        statement.finalize;
        keywordLinks.should.containOnly([ "1.1", "1.2" ]);
      });

      it("should add the badges", {
        auto statement = db.prepare("SELECT * FROM badges");

        string[] strBadges;
        foreach (Row row; statement.execute) {
          strBadges ~= row["pageId"].as!string ~ " " ~ row["type"].as!string ~ " " ~ row["signature"].as!string;
        }

        statement.finalize;
        strBadges.should.containOnly([ "1 1 [1, 2, 3]" ]);
      });

      it("should add the links", {
        auto statement = db.prepare("SELECT * FROM links");

        string[] strLinks;
        foreach (Row row; statement.execute) {
          strLinks ~= row["pageId"].as!string ~ "." ~ row["destinationId"].as!string;
        }

        statement.finalize;
        strLinks.should.containOnly([ "1.2", "1.3" ]);
      });

      describe("and add a new page with the same keywords", {
        beforeEach({
          auto data = PageData(
            "some title",
            URI("http://example.com"),
            "some description",
            Clock.currTime,
            [],
            [],
            [ "some", "keywords" ],
            InformationType.webImage
          );

          storage.add(data);
        });

        it("should have the keywords once", {
          auto statement = db.prepare("SELECT * FROM keywords");

          string[] keywords;
          foreach (Row row; statement.execute) {
            keywords ~= row["id"].as!string ~ "." ~ row["keyword"].as!string;
          }

          statement.finalize;
          keywords.should.containOnly([ "1.some", "2.keywords" ]);
        });
      });

      describe("and updated", {
        beforeEach({
          Badge[] badges = [ Badge(BadgeType.approve, [1, 2, 3]) ];
          auto data = PageData(
            "some other title",
            URI("http://example.com"),
            "some other description",
            Clock.currTime,

            [ URI("http://example.com/page3"), URI("http://example.com/page4") ],
            badges,
            [ "other", "keywords" ],
            InformationType.webPage
          );

          storage.add(data);
        });

        it("should update the fields", {
          Statement statement = db.prepare("SELECT * FROM pages WHERE id = 1 LIMIT 1");

          int found = 0;
          foreach (Row row; statement.execute) {
            row["id"].as!int.should.equal(1);
            row["title"].as!string.should.equal("some other title");
            row["location"].as!string.should.equal("http://example.com");
            row["description"].as!string.should.equal("some other description");
            row["time"].as!ulong.should.be.approximately(Clock.currTime.toUnixTime, 2000);
            row["type"].as!int.should.equal(0);
            found++;
          }

          statement.finalize;
          found.should.equal(1);
        });

        it("should contain only 4 pages", {
          Statement statement = db.prepare("SELECT * FROM pages");

          string[] pages;
          foreach (Row row; statement.execute) {
            pages ~= row["location"].as!string;
          }

          statement.finalize;
          pages.should.containOnly([
            "http://example.com",
            "http://example.com/page1",
            "http://example.com/page2",
            "http://example.com/page3",
            "http://example.com/page4"]);
        });
      });

      describe("and updated with less child items", {
        beforeEach({
          Badge[] badges = [ Badge(BadgeType.authenticity, [1, 2, 3]) ];
          auto data = PageData(
            "some other title",
            URI("http://example.com"),
            "some other description",
            Clock.currTime,

            [ URI("http://example.com/page4") ],
            badges,
            [ "new" ],
            InformationType.webPage
          );

          storage.add(data);
        });

        it("should contain only 3 pages", {
          Statement statement = db.prepare("SELECT * FROM pages");

          string[] pages;
          foreach (Row row; statement.execute) {
            pages ~= row["location"].as!string;
          }

          statement.finalize;
          pages.should.containOnly([
            "http://example.com",
            "http://example.com/page1",
            "http://example.com/page2",
            "http://example.com/page4"]);
        });

        it("should add the new keyword", {
          auto statement = db.prepare("SELECT * FROM keywords");

          string[] keywords;
          foreach (Row row; statement.execute) {
            keywords ~= row["id"].as!string ~ "." ~ row["keyword"].as!string;
          }

          statement.finalize;
          keywords.should.containOnly([ "1.some", "2.keywords", "3.new"]);
        });

        it("should update the keywordLinks", {
          auto statement = db.prepare("SELECT * FROM keywordLinks");

          string[] keywordLinks;
          foreach (Row row; statement.execute) {
            keywordLinks ~= row["pageId"].as!string ~ "." ~ row["keywordId"].as!string;
          }

          statement.finalize;
          keywordLinks.should.containOnly([ "1.3" ]);
        });

        it("should update the badge", {
          auto statement = db.prepare("SELECT * FROM badges");

          string[] strBadges;
          foreach (Row row; statement.execute) {
            strBadges ~= row["pageId"].as!string ~ " " ~ row["type"].as!string ~ " " ~ row["signature"].as!string;
          }

          statement.finalize;
          strBadges.should.containOnly([ "1 3 [1, 2, 3]" ]);
        });

        it("should update the links", {
          auto statement = db.prepare("SELECT * FROM links");

          string[] strLinks;
          foreach (Row row; statement.execute) {
            strLinks ~= row["pageId"].as!string ~ "." ~ row["destinationId"].as!string;
          }

          statement.finalize;
          strLinks.should.containOnly([ "1.4" ]);
        });
      });

      describe("and removed", {
        beforeEach({
          storage.remove(URI("http://example.com"));
        });

        it("should remove the page", {
          storage.exists(URI("http://example.com")).should.equal(false);
        });

        it("should not remove the linked page", {
          Statement statement = db.prepare("SELECT * FROM pages");

          string[] pages;
          foreach (Row row; statement.execute) {
            pages ~= row["location"].as!string;
          }

          statement.finalize;
          pages.should.containOnly([
            "http://example.com/page1",
            "http://example.com/page2"]);
        });

        it("should not remove the keywords", {
          auto statement = db.prepare("SELECT * FROM keywords");

          string[] keywords;
          foreach (Row row; statement.execute) {
            keywords ~= row["id"].as!string ~ "." ~ row["keyword"].as!string;
          }

          statement.finalize;
          keywords.should.containOnly([ "1.some", "2.keywords" ]);
        });

        it("should remove the keywordLinks", {
          db.execute("SELECT count(*) FROM keywordLinks").oneValue!long.should.equal(0);
        });

        it("should remove the badges", {
          db.execute("SELECT count(*) FROM badges").oneValue!long.should.equal(0);
        });

        it("should remove the links", {
          db.execute("SELECT count(*) FROM links").oneValue!long.should.equal(0);
        });
      });

      describe("LazySQLitePageData", {
        PageStorage storage;

        beforeEach({
          storage = new PageStorage(db);
        });

        afterEach({
          storage.close;
        });

        it("should resolve the title", {
          auto page = new LazySQLitePageData(1, storage);
          page.title.should.equal("some title");
        });

        it("should cache the title", {
          auto page = new LazySQLitePageData(1, storage);
          page.title.should.equal("some title");
          page.title.should.equal("some title");

          storage.queryCount.should.equal(1);
        });

        it("should resolve the description", {
          auto page = new LazySQLitePageData(1, storage);
          page.description.should.equal("some description");
        });

        it("should cache the description", {
          auto page = new LazySQLitePageData(1, storage);
          page.description.should.equal("some description");
          page.description.should.equal("some description");

          storage.queryCount.should.equal(1);
        });

        it("should resolve the location", {
          auto page = new LazySQLitePageData(1, storage);
          page.location.should.equal(URI("http://example.com"));
        });

        it("should cache the location", {
          auto page = new LazySQLitePageData(1, storage);
          page.location.should.equal(URI("http://example.com"));
          page.location.should.equal(URI("http://example.com"));

          storage.queryCount.should.equal(1);
        });

        it("should resolve the time", {
          auto page = new LazySQLitePageData(1, storage);
          page.time.should.equal(time);
        });

        it("should cache the time", {
          auto page = new LazySQLitePageData(1, storage);
          page.time.should.equal(time);
          page.time.should.equal(time);

          storage.queryCount.should.equal(1);
        });

        it("should resolve the type", {
          auto page = new LazySQLitePageData(1, storage);
          page.type.should.equal(InformationType.webImage);
        });

        it("should cache the type", {
          auto page = new LazySQLitePageData(1, storage);
          page.type.should.equal(InformationType.webImage);
          page.type.should.equal(InformationType.webImage);

          storage.queryCount.should.equal(1);
        });

        it("should resolve the keywords", {
          auto page = new LazySQLitePageData(1, storage);
          page.keywords.should.equal([ "some", "keywords" ]);
        });

        it("should cache the keywords", {
          auto page = new LazySQLitePageData(1, storage);
          page.keywords.should.equal([ "some", "keywords" ]);
          page.keywords.should.equal([ "some", "keywords" ]);

          storage.queryCount.should.equal(1);
        });

        it("should resolve the badges", {
          auto page = new LazySQLitePageData(1, storage);
          page.badges.should.equal([ Badge(BadgeType.approve, [1, 2, 3]) ]);
        });

        it("should cache the badges", {
          auto page = new LazySQLitePageData(1, storage);
          page.badges.should.equal([ Badge(BadgeType.approve, [1, 2, 3]) ]);
          page.badges.should.equal([ Badge(BadgeType.approve, [1, 2, 3]) ]);

          storage.queryCount.should.equal(1);
        });

        it("should resolve the relations", {
          auto page = new LazySQLitePageData(1, storage);
          page.relations.should.equal([ URI("http://example.com/page1"), URI("http://example.com/page2") ]);
        });

        it("should cache the relations", {
          auto page = new LazySQLitePageData(1, storage);
          page.relations.should.equal([ URI("http://example.com/page1"), URI("http://example.com/page2") ]);
          page.relations.should.equal([ URI("http://example.com/page1"), URI("http://example.com/page2") ]);

          storage.queryCount.should.equal(1);
        });

        it("should cache the relations", {
          auto page = new LazySQLitePageData(1, storage);
          page.relations.should.equal([ URI("http://example.com/page1"), URI("http://example.com/page2") ]);
          page.relations.should.equal([ URI("http://example.com/page1"), URI("http://example.com/page2") ]);

          storage.queryCount.should.equal(1);
        });

        it("should count the keywords", {
          auto page = new LazySQLitePageData(1, storage);
          page.countPresentKeywords([ "some", "keywords" ]).should.equal(2);
        });
      });
    });

    describe("when a page with external links is added", {
      SQLiteStorage storage;
      Database db;

      beforeEach({
        if("test.db".exists) {
          "test.db".remove;
        }

        storage = new SQLiteStorage("test.db");

        auto data = PageData(
          "some title",
          URI("http://example.com"),
          "some description",
          Clock.currTime,

          [ URI("http://other.com/page1"), URI("http://misc.com:8080/page2") ],
          [],
          [],
          InformationType.webPage
        );

        storage.add(data);
        db = Database("test.db");
      });

      afterEach({
        storage.close;
        "test.db".remove;
      });

      it("should not get the external links for the pending example authority", {
        storage.pending(0.seconds, 2, "example.com").should.equal([ ]);
      });
    });

    describe("when there is an empty database", {
      SQLiteStorage storage;
      Database db;

      beforeEach({
        if("test.db".exists) {
          "test.db".remove;
        }

        storage = new SQLiteStorage("test.db");
      });

      afterEach({
        storage.close;
        "test.db".remove;
      });

      it("should be able to add an unknown page type", {
        auto data = PageData(
          "",
          URI("http://other.com"),
          "",
          Clock.currTime,
          [],
          [],
          [],
          InformationType.other
        );

        storage.add(data);
        db = Database("test.db");

        Statement statement = db.prepare("SELECT * FROM pages WHERE id = 1 LIMIT 1");

        int found = 0;
        foreach (Row row; statement.execute) {
          row["id"].as!int.should.equal(1);
          row["title"].as!string.should.equal("");
          row["location"].as!string.should.equal("http://other.com");
          row["time"].as!ulong.should.be.approximately(Clock.currTime.toUnixTime, 2000);
          row["type"].as!uint.should.equal(uint.max);
          found++;
        }

        statement.finalize;
        found.should.equal(1);
      });
    });
  });
});