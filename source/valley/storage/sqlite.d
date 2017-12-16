module valley.storage.sqlite;

import valley.storage.base;
import valley.uri;
import d2sqlite3;

import std.file;
import std.conv;
import std.datetime;
import std.typecons : Nullable;

void setupSqliteDb(string fileName) {
  auto db = Database(fileName);
  db.run(`CREATE TABLE pages (
          id           INTEGER PRIMARY KEY autoincrement,
          title        TEXT,
          location     TEXT NOT NULL,
          description  TEXT,
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

  db.run(`CREATE TABLE badges (
          id           INTEGER primary key autoincrement,
          pageId       INTEGER NOT NULL,
          type         INTEGER NOT NULL,
          signature    BLOB NOT NULL
        )`);

  db.run(`CREATE TABLE links (
          id              INTEGER primary key autoincrement,
          pageId          INTEGER NOT NULL,
          destinationId   INTEGER NOT NULL
        )`);

  db.close;
}

class SQLiteStorage : Storage {
  private {
    Database db;
    Statement insertPage;
    Statement insertKeyword;
    Statement insertKeywordLinks;
    Statement insertBadge;
    Statement insertLink;
    Statement lastInsertId;

    Statement selectPage;
  }

  this(string fileName) {
    if(!fileName.exists) {
      setupSqliteDb(fileName);
    }

    db = Database(fileName);
    insertPage = db.prepare("INSERT INTO pages (title,  location,   description,  time,  type)
                                        VALUES (:title, :location, :description, :time, :type )");

    insertKeyword = db.prepare("INSERT INTO keywords (keyword) VALUES (:keyword) ");
    insertBadge = db.prepare("INSERT INTO badges (pageId, type, signature) VALUES (:pageId, :type, :signature) ");
    insertKeywordLinks = db.prepare("INSERT INTO keywordLinks (keywordId, pageId) VALUES (:keywordId, :pageId) ");
    insertLink = db.prepare("INSERT INTO links (pageId, destinationId) VALUES (:pageId, :destinationId) ");

    selectPage = db.prepare("SELECT * FROM pages WHERE location = :location");

    lastInsertId = db.prepare("SELECT last_insert_rowid()");
  }

  ulong getLastId() {
    ulong id = lastInsertId.execute.oneValue!ulong;
    lastInsertId.reset;

    return id;
  }

  ulong addKeyword(string value) {
    insertKeyword.bind(":keyword", value);
    insertKeyword.execute;
    insertKeyword.reset;

    return getLastId;
  }

  ulong addBadge(ulong pageId, BadgeType type, ubyte[] signature) {
    insertBadge.bind(":pageId", pageId);
    insertBadge.bind(":type", type);
    insertBadge.bind(":signature", signature);
    insertBadge.execute;
    insertBadge.reset;

    return getLastId;
  }

  ulong addKeywordLink(ulong pageId, ulong keywordId) {
    insertKeywordLinks.bind(":keywordId", keywordId);
    insertKeywordLinks.bind(":pageId", pageId);

    insertKeywordLinks.execute;
    insertKeywordLinks.reset;

    return getLastId;
  }

  void add(PageData data) {
    addPage(data);
  }

  ulong getPageId(URI location) {
    selectPage.bind(":location", location.toString);
    scope(exit) selectPage.reset;

    auto result = selectPage.execute;

    if(result.empty) {
      return addPage(PageData("", location));
    }

    assert(false);
  }

  ulong addLink(ulong pageId, URI location) {
    auto destinationId = getPageId(location);

    insertLink.bind(":pageId", pageId);
    insertLink.bind(":destinationId", destinationId);
    insertLink.execute;
    insertLink.reset;

    return getLastId;
  }

  ulong addPage(PageData data)
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
      keywords ~= addKeyword(keyword);
    }

    foreach(keywordId; keywords) {
      addKeywordLink(pageId, keywordId);
    }

    foreach(badge; data.badges) {
      addBadge(pageId, badge.type, badge.signature);
    }

    foreach(location; data.relations) {
      addLink(pageId, location);
    }

    return pageId;
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
    insertBadge.finalize;
    insertLink.finalize;
    selectPage.finalize;

    db.close;
  }
}
