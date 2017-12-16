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

      before({
        if("data.db".exists) {
          "data.db".remove;
        }

        storage = new SQLiteStorage("data.db");

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
        db = Database("data.db");
      });

      after({
        storage.close;
        "data.db".remove;
      });

      it("should add the page", {
        storage.exists(URI("http://example.com")).should.equal(true);
      });

      it("should add the links", {
        storage.exists(URI("http://example.com/page1")).should.equal(true);
        storage.exists(URI("http://example.com/page2")).should.equal(true);
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
    });
  });
});