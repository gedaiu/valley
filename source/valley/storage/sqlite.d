module valley.storage.sqlite;

import valley.storage.base;
import valley.uri;
import d2sqlite3;

import std.file;
import std.conv;
import std.datetime;
import std.algorithm;
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

class KeywordStorage {
  private {
    Statement insertKeyword;
    Statement insertKeywordLinks;
    Statement removePageId;
    Statement selectPageLinks;
    Statement unlinkPage;
    Statement lastInsertId;

    Database db;
  }

  this(Database db) {
    insertKeywordLinks = db.prepare("INSERT INTO keywordLinks (keywordId, pageId) VALUES (:keywordId, :pageId) ");
    insertKeyword = db.prepare("INSERT INTO keywords (keyword) VALUES (:keyword) ");
    removePageId = db.prepare("DELETE FROM keywordLinks WHERE pageId = :pageId");
    selectPageLinks = db.prepare("SELECT keywordId FROM keywordLinks WHERE pageId = :pageId");
    unlinkPage = db.prepare("DELETE FROM keywordLinks WHERE pageId = :pageId AND keywordId = :keywordId");
    lastInsertId = db.prepare("SELECT last_insert_rowid()");

    this.db = db;
  }

  ulong getLastId() {
    ulong id = lastInsertId.execute.oneValue!ulong;
    lastInsertId.reset;

    return id;
  }

  ulong add(string value) {
    insertKeyword.bind(":keyword", value);
    insertKeyword.execute;
    insertKeyword.reset;

    return getLastId;
  }

  ulong link(ulong pageId, ulong keywordId) {
    insertKeywordLinks.bind(":keywordId", keywordId);
    insertKeywordLinks.bind(":pageId", pageId);

    insertKeywordLinks.execute;
    insertKeywordLinks.reset;

    return getLastId;
  }

  void unlink(ulong pageId, ulong keywordId) {
    unlinkPage.bind(":keywordId", keywordId);
    unlinkPage.bind(":pageId", pageId);
    unlinkPage.execute;
    unlinkPage.reset;
  }

  ulong[] pageLinks(ulong pageId) {
    ulong[] list;

    selectPageLinks.bind(":pageId", pageId);

    foreach (Row row; selectPageLinks.execute) {
      list ~= row["keywordId"].as!ulong;
    }

    selectPageLinks.reset;

    return list;
  }

  void removeByPageId(ulong pageId) {
    removePageId.bind(":pageId", pageId);
    removePageId.execute;
    removePageId.reset;
  }

  void close() {
    removePageId.finalize;
    insertKeyword.finalize;
    insertKeywordLinks.finalize;
    unlinkPage.finalize;
    selectPageLinks.finalize;
    lastInsertId.finalize;
  }
}

class BadgeStorage {

  private {
    Statement insertBadge;
    Statement removePageId;
    Statement removeBadge;
    Statement lastInsertId;
    Statement selectPageBadges;

    Database db;
  }

  this(Database db) {
    insertBadge = db.prepare("INSERT INTO badges (pageId, type, signature) VALUES (:pageId, :type, :signature) ");
    removePageId = db.prepare("DELETE FROM badges WHERE pageId = :pageId");
    removeBadge = db.prepare("DELETE FROM badges WHERE pageId = :pageId AND type = :type");
    selectPageBadges = db.prepare("SELECT * FROM badges WHERE pageId = :pageId");
    lastInsertId = db.prepare("SELECT last_insert_rowid()");

    this.db = db;
  }

  ulong getLastId() {
    ulong id = lastInsertId.execute.oneValue!ulong;
    lastInsertId.reset;

    return id;
  }

  Badge[] get(ulong pageId) {
    Badge[] list;

    selectPageBadges.bind(":pageId", pageId);

    foreach (Row row; selectPageBadges.execute) {
      list ~= Badge(row["type"].as!uint.to!BadgeType, row["signature"].as!(ubyte[]));
    }

    selectPageBadges.reset;


    return list;
  }

  ulong add(ulong pageId, BadgeType type, ubyte[] signature) {
    insertBadge.bind(":pageId", pageId);
    insertBadge.bind(":type", type);
    insertBadge.bind(":signature", signature);
    insertBadge.execute;
    insertBadge.reset;

    return getLastId;
  }

  void removeByPageId(ulong pageId) {
    removePageId.bind(":pageId", pageId);
    removePageId.execute;
    removePageId.reset;
  }

  void remove(ulong pageId, BadgeType type) {
    removeBadge.bind(":pageId", pageId);
    removeBadge.bind(":type", type);
    removeBadge.execute;
    removeBadge.reset;
  }

  void close() {
    insertBadge.finalize;
    removePageId.finalize;
    removeBadge.finalize;
    lastInsertId.finalize;
    selectPageBadges.finalize;
  }
}

class LinkStorage {
  private {
    Statement insertLink;
    Statement removePageId;
    Statement removeLink;
    Statement lastInsertId;
    Statement selectPageId;
    Database db;
  }

  this(Database db) {
    insertLink = db.prepare("INSERT INTO links (pageId, destinationId) VALUES (:pageId, :destinationId) ");
    removePageId = db.prepare("DELETE FROM links WHERE pageId = :pageId");
    selectPageId = db.prepare("SELECT destinationId FROM links WHERE pageId = :pageId");
    removeLink = db.prepare("DELETE FROM links WHERE pageId = :pageId AND destinationId = :destinationId");
    lastInsertId = db.prepare("SELECT last_insert_rowid()");

    this.db = db;
  }

  ulong getLastId() {
    ulong id = lastInsertId.execute.oneValue!ulong;
    lastInsertId.reset;

    return id;
  }

  ulong add(ulong pageId, ulong destinationId) {
    insertLink.bind(":pageId", pageId);
    insertLink.bind(":destinationId", destinationId);
    insertLink.execute;
    insertLink.reset;

    return getLastId;
  }

  void removeByPageId(ulong pageId) {
    removePageId.bind(":pageId", pageId);
    removePageId.execute;
    removePageId.reset;
  }

  void unlink(ulong pageId, ulong destinationId) {
    removeLink.bind(":pageId", pageId);
    removeLink.bind(":destinationId", destinationId);
    removeLink.execute;
    removeLink.reset;
  }

  ulong[] get(ulong pageId) {
    ulong[] list;

    selectPageId.bind(":pageId", pageId);

    foreach (Row row; selectPageId.execute) {
      list ~= row["destinationId"].as!uint;
    }

    selectPageId.reset;

    return list;
  }

  void close() {
    insertLink.finalize;
    removePageId.finalize;
    lastInsertId.finalize;
    removeLink.finalize;
    selectPageId.finalize;
  }
}

class SQLiteStorage : Storage {
  private {
    Database db;
    KeywordStorage keywordStorage;
    BadgeStorage badgeStorage;
    LinkStorage linkStorage;

    Statement insertPage;
    Statement updatePage;
    Statement deletePage;
    Statement lastInsertId;
    Statement pageCount;

    Statement selectPage;
    Statement pageId;
  }

  this(string fileName) {
    if(!fileName.exists) {
      setupSqliteDb(fileName);
    }

    db = Database(fileName);
    keywordStorage = new KeywordStorage(db);
    badgeStorage = new BadgeStorage(db);
    linkStorage = new LinkStorage(db);

    insertPage = db.prepare("INSERT INTO pages (title,  location,   description,  time,  type)
                                        VALUES (:title, :location, :description, :time, :type )");

    deletePage = db.prepare("DELETE FROM pages WHERE id = :id");

    updatePage = db.prepare("UPDATE pages SET title=:title, location=:location, description=:description,
                              time=:time, type=:type WHERE id=:id");

    selectPage = db.prepare("SELECT * FROM pages WHERE location = :location");
    pageCount = db.prepare("SELECT count(*) FROM pages WHERE location = :location");
    pageId = db.prepare("SELECT id FROM pages WHERE location = :location");

    lastInsertId = db.prepare("SELECT last_insert_rowid()");
  }

  ulong getLastId() {
    ulong id = lastInsertId.execute.oneValue!ulong;
    lastInsertId.reset;

    return id;
  }

  void remove(URI location) {
    if(!exists(location)) {
      return;
    }

    auto id = getPageId(location);

    deletePage.bind(":id", id);
    deletePage.execute;
    deletePage.reset;

    keywordStorage.removeByPageId(id);
    badgeStorage.removeByPageId(id);
    linkStorage.removeByPageId(id);
  }

  void add(PageData data) {
    addPage(data);
  }

  ulong getPageId(URI location) {
    pageId.bind(":location", location.toString);
    scope(exit) pageId.reset;

    auto result = pageId.execute;

    if(result.empty) {
      return addPage(PageData("", location));
    }

    return result.oneValue!ulong;
  }

  ulong addPage(PageData data) {
    ulong id;

    if(!exists(data.location)) {
      insertPage.bind(":title", data.title);
      insertPage.bind(":location", data.location.toString);
      insertPage.bind(":description", data.description);
      insertPage.bind(":time", data.time.toUnixTime);
      insertPage.bind(":type", data.type.to!int);

      insertPage.execute;
      insertPage.reset;
      insertPage.clearBindings;

      id = getLastId;
    } else {
      id = getPageId(data.location);

      updatePage.bind(":id", id);
      updatePage.bind(":title", data.title);
      updatePage.bind(":location", data.location.toString);
      updatePage.bind(":description", data.description);
      updatePage.bind(":time", data.time.toUnixTime);
      updatePage.bind(":type", data.type.to!int);

      updatePage.execute;
      updatePage.reset;
      updatePage.clearBindings;
    }

    ulong[] keywords;

    foreach(keyword; data.keywords) {
      keywords ~= keywordStorage.add(keyword);
    }

    auto pageLinks = keywordStorage.pageLinks(id);
    foreach(linkedId; pageLinks) {
      if(!keywords.canFind(linkedId)) {
        keywordStorage.unlink(id, linkedId);
      }
    }

    foreach(keywordId; keywords) {
      keywordStorage.link(id, keywordId);
    }

    auto existingBadges = badgeStorage.get(id).map!"a.type";
    auto newBadges = data.badges.map!"a.type";

    foreach(badge; existingBadges) {
      if(!newBadges.canFind(badge)) {
        badgeStorage.remove(id, badge);
      }
    }

    foreach(badge; data.badges) {
      badgeStorage.add(id, badge.type, badge.signature);
    }

    ulong[] currentLinks = linkStorage.get(id);
    ulong[] newLinks;
    foreach(location; data.relations) {
      newLinks ~= getPageId(location);
      linkStorage.add(id, getPageId(location));
    }

    foreach(link; currentLinks) {
      if(!newLinks.canFind(link)) {
        linkStorage.unlink(id, link);
      }
    }

    return id;
  }

  PageData[] query(string data) {
    return [];
  }

  bool exists(URI location) {
    pageCount.bind(":location", location.toString);
    scope(exit) pageCount.reset;

    return pageCount.execute.oneValue!long > 0;
  }

  void close() {
    keywordStorage.close;
    badgeStorage.close;
    linkStorage.close;

    insertPage.finalize;
    updatePage.finalize;
    lastInsertId.finalize;
    selectPage.finalize;
    pageCount.finalize;
    pageId.finalize;
    deletePage.finalize;

    db.close;
  }
}
