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

struct Information {
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
  void add(Information);
  Information[] query(string);
}