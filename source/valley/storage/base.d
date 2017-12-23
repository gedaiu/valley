module valley.storage.base;

import valley.uri;
import std.datetime;

enum InformationType : uint {
  webPage = 0,
  webImage = 1,

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

interface Storage {
  void add(PageData);
  void remove(URI);
  PageData[] query(string);
}
