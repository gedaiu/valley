module valley.storage.sqlite;

import valley.storage.base;
import valley.uri;
import d2sqlite3;

import std.file;
import std.conv;
import std.datetime;
import std.typecons : Nullable;

version (unittest)
{
  import fluent.asserts;
}

void setupSqliteDb(string fileName) {
  auto db = Database(fileName);
  db.run(`CREATE TABLE pages (
          id           INTEGER PRIMARY KEY autoincrement,
          title        TEXT NOT NULL,
          location     TEXT NOT NULL,
          description  TEXT NOT NULL,
          time         INTEGER NOT NULL,
          type         INTEGER NOT NULL
        )`);

  db.run(`CREATE TABLE keywords (
          id           INTEGER primary key autoincrement,
          keyword      TEXT NOT NULL
        )`);

  db.run(`CREATE TABLE keywordLinks (
    pageId        INTEGER NOT NULL,
    keywordId     INTEGER NOT NULL
  )`);

  db.close;
}

class SQLiteStorage : Storage
{
  private {
    Database db;
    Statement insertPage;
    Statement insertKeyword;
    Statement insertKeywordLinks;
    Statement lastInsertId;
  }

  this(string fileName) {
    if(!fileName.exists) {
      setupSqliteDb(fileName);
    }

    db = Database(fileName);
    insertPage = db.prepare("INSERT INTO pages (title,  location,   description,  time,  type)
                                        VALUES (:title, :location, :description, :time, :type )");

    insertKeyword = db.prepare("INSERT INTO keywords (keyword) VALUES (:keyword) ");
    insertKeywordLinks = db.prepare("INSERT INTO keywordLinks (keywordId, pageId) VALUES (:keywordId, :pageId) ");
    lastInsertId = db.prepare("SELECT last_insert_rowid()");
  }

  ulong getLastId() {
    ulong id = lastInsertId.execute.oneValue!ulong;
    lastInsertId.reset;

    return id;
  }

  void add(PageData data)
  {
    insertPage.bind(":title", data.title);
    insertPage.bind(":location", data.location.toString);
    insertPage.bind(":description", data.description);
    insertPage.bind(":time", data.time.toUnixTime);
    insertPage.bind(":type", data.type.to!int);

    insertPage.execute;
    insertPage.reset;

    auto pageId = getLastId;
    ulong[] keywords;

    foreach(keyword; data.keywords) {
      insertKeyword.bind(":keyword", keyword);

      insertKeyword.execute;
      insertKeyword.reset;

      keywords ~= getLastId;
    }

    foreach(keywordId; keywords) {
      insertKeywordLinks.bind(":keywordId", keywordId);
      insertKeywordLinks.bind(":pageId", pageId);

      insertKeywordLinks.execute;
      insertKeywordLinks.reset;
    }
  }

  PageData[] query(string data)
  {
    return [];
  }

  void close() {
    insertPage.finalize;
    insertKeyword.finalize;
    insertKeywordLinks.finalize;
    lastInsertId.finalize;

    db.close;
  }
}

/// SQLiteStorage should store a page in the db
unittest {
  if("data.db".exists) {
    "data.db".remove;
  }

  auto storage = new SQLiteStorage("data.db");

  scope(exit) {
    storage.close;

    if("data.db".exists) {
      "data.db".remove;
    }
  }

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

  auto db = Database("data.db");

  // Prepare an SELECT statement for the inserted pages
  Statement statement = db.prepare("SELECT * FROM pages");

  int found = 0;
  foreach (Row row; statement.execute) {
    row["id"].as!int.should.equal(1);
    row["title"].as!string.should.equal("some title");
    row["location"].as!string.should.equal(data.location.toString);
    row["description"].as!string.should.equal("some description");
    row["time"].as!ulong.should.equal(data.time.toUnixTime);
    row["type"].as!int.should.equal(1);
    found++;
  }
  statement.finalize;
  found.should.equal(1);

  // Prepare an SELECT statement for the keywords
  statement = db.prepare("SELECT * FROM keywords");

  string[] keywords;
  foreach (Row row; statement.execute) {
    keywords ~= row["id"].as!string ~ "." ~ row["keyword"].as!string;
  }

  statement.finalize;
  keywords.should.containOnly([ "1.some", "2.keywords" ]);

  // Prepare an SELECT statement for the keywordLinkks
  statement = db.prepare("SELECT * FROM keywordLinks");

  string[] keywordLinks;
  foreach (Row row; statement.execute) {
    keywordLinks ~= row["pageId"].as!string ~ "." ~ row["keywordId"].as!string;
  }

  statement.finalize;
  keywordLinks.should.containOnly([ "1.1", "1.2" ]);

  /// Badges

  /// Relations

}