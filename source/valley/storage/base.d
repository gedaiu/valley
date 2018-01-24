module valley.storage.base;

import valley.uri;
import std.datetime;
import std.algorithm;
import std.array;

enum InformationType : uint {
  webPage = 0,
  webImage = 1,

  redirect = uint.max - 2,
  userError = uint.max - 1,
  other = uint.max
}

enum BadgeType : uint {
  approve = 1,
  disapprove = 2,
  authenticity = 3,

  other = uint.max
}

struct Badge {
  BadgeType type;
  ubyte[] signature;
}

struct PageData {
  string title;
  URI location;
  string description;
  SysTime time;

  URI[] relations;
  Badge[] badges;
  string[] keywords;

  InformationType type;
}

IPageData toClass(PageData pageData) {
  return new ResolvedPageData(pageData);
}

interface IPageData {
  string title();
  URI location();
  string description();
  SysTime time();

  URI[] relations();
  Badge[] badges();
  string[] keywords();

  InformationType type();

  int countPresentKeywords(string[] keywords);
}

class ResolvedPageData : IPageData {
  private {
    PageData pageData;
  }

  this(PageData pageData) {
    this.pageData = pageData;
  }

  string title() {
    return pageData.title;
  }

  URI location() {
    return pageData.location;
  }

  string description() {
    return pageData.description;
  }

  SysTime time() {
    return pageData.time;
  }

  URI[] relations() {
    return pageData.relations;
  }

  Badge[] badges() {
    return pageData.badges;
  }

  string[] keywords() {
    return pageData.keywords;
  }

  InformationType type() {
    return pageData.type;
  }

  int countPresentKeywords(string[] keywords) {
    return 0;
  }
}

interface Storage {
  void add(PageData);
  void remove(URI);
  IPageData[] query(string, size_t start, size_t count);

  URI[] pending(const Duration, const size_t count, const string pending = "");
}
