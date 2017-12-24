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

      beforeEach({
        if("test.db".exists) {
          "test.db".remove;
        }

        storage = new SQLiteStorage("test.db");

        Badge[] badges = [ Badge(BadgeType.approve, [1, 2, 3]) ];
        auto data = PageData(
          "some title",
          URI("http://example.com/"),
          "some description",
          Clock.currTime,

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

      it("should add the page", {
        storage.exists(URI("http://example.com")).should.equal(true);
      });

      it("should add the links", {
        storage.exists(URI("http://example.com/page1")).should.equal(true);
        storage.exists(URI("http://example.com/page2")).should.equal(true);
      });

      it("should mark empty pages as pending", {
        storage.pending(0.seconds).should.containOnly([ URI("http://example.com/page1"), URI("http://example.com/page2")]);
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

      describe("and updated", {
        beforeEach({
          Badge[] badges = [ Badge(BadgeType.approve, [1, 2, 3]) ];
          auto data = PageData(
            "some other title",
            URI("http://example.com/"),
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
            URI("http://example.com/"),
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
          storage.remove(URI("http://example.com/"));
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
    });
  });
});