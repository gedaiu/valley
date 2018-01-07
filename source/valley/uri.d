module valley.uri;

import std.string;
import std.conv;
import std.algorithm;
import std.array;
import std.range;

class URIParseException : Exception
{
    this(string msg, string file = __FILE__, size_t line = __LINE__) pure {
        super(msg, file, line);
    }
}

struct Scheme {
  immutable(string) value;

  pure inout {
    URI opBinary(string op)(Authority rhs)
    {
      static if (op == "~") {
        return URI(this, rhs, Path(""), Query(""), "");
      } else {
        static assert(0, "The `" ~ op ~ "` operator is not supported.");
      }
    }

    URI opBinary(string op)(URI rhs)
    {
      static if (op == "~") {
        return URI(this, rhs.authority, rhs.path, rhs.query, rhs.fragment);
      } else {
        static assert(0, "The `" ~ op ~ "` operator is not supported.");
      }
    }

    auto length()
    {
      return value.length;
    }
  }
}

/// concatenate a scheme and an Authority
unittest {
  auto uri = Scheme("https") ~ Authority("google.com");

  uri.scheme.value.should.equal("https");
  uri.userInformation.should.equal("");
  uri.host.should.equal("google.com");
  uri.port.should.equal(0);
  uri.path.value.should.equal("");
  uri.query.value.should.equal("");
  uri.fragment.should.equal("");
  uri.toString.should.equal("https://google.com");
}

/// concatenate a scheme and an URI
unittest {
  auto uri = Scheme("https") ~ URI("//google.com/path/?query#hashtag");

  uri.scheme.value.should.equal("https");
  uri.userInformation.should.equal("");
  uri.host.should.equal("google.com");
  uri.port.should.equal(0);
  uri.path.value.should.equal("/path/");
  uri.query.value.should.equal("query");
  uri.fragment.should.equal("hashtag");
  uri.toString.should.equal("https://google.com/path/?query#hashtag");
}

struct Authority {
  immutable {
    string userInformation;
    string host;
    ushort port;
  }

  this(const string authority) pure {
    string tmp = authority.dup;

    auto userInformationEnd = tmp.indexOf("@");
    if(userInformationEnd != -1) {
      userInformation = tmp[0..userInformationEnd].idup;
    }

    auto last = authority.lastIndexOf(":");
    if(last == -1) {
      last = authority.length;
    }

    if(last < authority.length) {
      port = authority[last+1 .. $].to!short;
    }

    host = authority[userInformationEnd+1 .. last].idup;
  }

  string toString() pure inout {
    string result;

    if(userInformation != "") {
      result = userInformation ~ "@";
    }

    result ~= host;

    if(port != 0) {
      result ~= ":" ~ port.to!string;
    }

    return result;
  }
}

/// Parse an url Authority with all the components
unittest {
  auto authority = Authority("username:password@example.com:123");

  authority.userInformation.should.equal("username:password");
  authority.host.should.equal("example.com");
  authority.port.should.equal(123);
}

/// Parse an url Authority with missing user info
unittest {
  auto authority = Authority("example.com:123");

  authority.userInformation.should.equal("");
  authority.host.should.equal("example.com");
  authority.port.should.equal(123);
}

/// Parse an url Authority with missing user info and port
unittest {
  auto authority = Authority("example.com");

  authority.userInformation.should.equal("");
  authority.host.should.equal("example.com");
  authority.port.should.equal(0);
}

/// Parse an url Authority when it has an empty string
unittest {
  auto authority = Authority("");

  authority.userInformation.should.equal("");
  authority.host.should.equal("");
  authority.port.should.equal(0);
}

struct Path {
  immutable(string) value;

  pure inout {
    bool isAbsolute() nothrow {
      if(value.length == 0) {
        return false;
      }

      return value[0] == '/';
    }

    string toNormalizedString() {
      auto cleanPieces = toString.split("/");
      cleanPieces.reverse;

      int skip;
      string[] finalPieces;

      foreach(piece; cleanPieces) {
        if(piece == "..") {
          skip += 1;
          continue;
        }

        if(skip > 0) {
          skip--;
          continue;
        }

        finalPieces = finalPieces ~ piece;
      }

      finalPieces.reverse;

      if(isAbsolute && (finalPieces.length == 0 || finalPieces[0] != "")) {
        finalPieces = "" ~ finalPieces;
      }

      return finalPieces.join('/');
    }

    immutable(Path) parent() pure {
      if(value == "/") {
        return Path("/");
      }

      if(value == "") {
        return Path("");
      }

      auto cleanPieces = toString.split("/");
      auto localParent = cleanPieces[0..$-1];

      if(localParent == [""]) {
        return Path("/");
      }

      return Path(localParent.join("/"));
    }

    string toString() pure {
      auto pieces = value.split("/").filter!`a != "."`.array;

      if(pieces.length == 0) {
        return value;
      }

      if(pieces.length == 1) {
        return value;
      }

      string result = pieces.join("/");
      while(result.indexOf("//") != -1) {
        result = result.replace("//", "/");
      }

      return result;
    }

    auto length() {
      return value.length;
    }

    Path opBinary(string op)(Path rhs) pure {
      static if (op == "~") {
        if(rhs.isAbsolute) {
          return rhs;
        }

        string rhsValue = rhs.toString;

        string currentParent = this.parent.toString;

        auto tmp = currentParent.endsWith('/') ? Path(currentParent ~ rhsValue) : Path(currentParent ~ "/" ~ rhsValue);

        return Path(tmp.toNormalizedString);
      } else {
        static assert(0, "The `" ~ op ~ "` operator is not supported.");
      }
    }

    URI opBinary(string op)(Query rhs) pure {
      static if (op == "~") {
        return URI(Scheme(""), Authority(""), this, rhs, "");
      } else {
        static assert(0, "The `" ~ op ~ "` operator is not supported.");
      }
    }
  }
}

/// Convenient function to create a Path struct. Designed to use with UFCS.
Path path(const string value) pure {
  return Path(value);
}

/// The parent of the root path should be root
unittest {
  Path("/").parent.toString.should.equal("/");
}

/// The parent of an empty path should be the empty path
unittest {
  Path("").parent.toString.should.equal("");
}

/// The parent of a page path should be the empty path
unittest {
  Path("index.html").parent.toString.should.equal("");
}

/// The parent of a root page path should be the root path
unittest {
  Path("/index.html").parent.toString.should.equal("/");
}

/// Should be able to get page parent
unittest {
  Path("/a/index.html").parent.toString.should.equal("/a");
}

/// Path absolute
unittest {
  Path("").isAbsolute.should.equal(false);
  Path("/").isAbsolute.should.equal(true);
  Path("document.html").isAbsolute.should.equal(false);
  Path("/document.html").isAbsolute.should.equal(true);
}

/// Concatenate paths
unittest {
  (Path("/path") ~ Path("/other")).toString.should.equal("/other");
  (Path("/path") ~ Path("other")).toString.should.equal("/other");
  (Path("/path/") ~ Path("other")).toString.should.equal("/path/other");
  (Path("/path/") ~ Path("./other")).toString.should.equal("/path/other");
  (Path("/path/") ~ Path("other//")).toString.should.equal("/path/other/");
  (Path("/path/") ~ Path("../other/")).toString.should.equal("/other/");
  (Path("/") ~ Path("")).toString.should.equal("/");
  (Path("/") ~ Path("/")).toString.should.equal("/");
  (Path("/congress/Other.html") ~ Path("../Static.html")).toString.should.equal("/Static.html");
  (Path("/congress") ~ Path("../Static.html")).toString.should.equal("/Static.html");
}

/// it should replace the last path node if the appended path has no /
unittest {
  auto result = Path("/spec/spec.html") ~ Path("expression.html");

  result.toString.should.equal("/spec/expression.html");
}

/// Normalize paths
unittest {
  Path("/path/../other/").toNormalizedString.should.equal("/other/");
  Path("/path/../../other/").toNormalizedString.should.equal("/other/");
  Path("/path/../../../other/").toNormalizedString.should.equal("/other/");
  Path("path").toNormalizedString.should.equal("path");
  Path("").toNormalizedString.should.equal("");
  Path("/").toNormalizedString.should.equal("/");
}

struct Query {
  immutable(string) value;
  alias value this;
}

struct URI {

  immutable {
    Scheme scheme;

    Authority authority;
    Path path;
    Query query;
    string fragment;
  }

  this(const Scheme scheme, const Authority authority, const Path path, const Query query, const string fragment) pure nothrow {
    this.scheme = scheme;
    this.authority = authority;
    this.path = path;
    this.query = query;
    this.fragment = fragment;
  }

  this(const string uri) pure {
    auto tmpUri = uri.dup;
    auto pos = tmpUri.indexOf("//");

    if(pos > 0) {
      if(tmpUri[pos - 1] == ':') {
        scheme = Scheme(tmpUri[0..pos-1].idup);
      } else {
        scheme = Scheme(tmpUri[0..pos].idup);
      }
    }

    if(pos != -1) {
      tmpUri = tmpUri[pos + 2..$];

      pos = tmpUri.indexOf("/");

      if(pos == -1) {
        pos = tmpUri.indexOf("?");
      }

      if(pos == -1) {
        pos = tmpUri.length;
      }

      try {
        authority = Authority(tmpUri[0..pos].idup);
      } catch(ConvException) {
        throw new URIParseException("Can not parse the URI authority");
      }

      tmpUri = tmpUri[pos..$];
    }

    auto queryPos = tmpUri.indexOf("?");
    auto fragmentPos = tmpUri.indexOf("#");

    if(queryPos == -1 && fragmentPos == -1) {
      path = Path(tmpUri.idup);
      return;
    } else if(queryPos != -1){
      path = Path(tmpUri[0..queryPos].idup);
    } else {
      path = Path(tmpUri[0..fragmentPos].idup);
    }

    if(queryPos != -1 && fragmentPos != -1) {
      query = Query(tmpUri[queryPos + 1 .. fragmentPos].idup);
      fragment = tmpUri[fragmentPos + 1..$].idup;
    } else if(fragmentPos == -1) {
      query = Query(tmpUri[queryPos + 1 .. $].idup);
    } else if(fragmentPos == -1) {
      fragment =tmpUri[fragmentPos + 1 .. $].idup;
    }
  }

  pure inout:
    auto userInformation() {
      return this.authority.userInformation;
    }

    auto host() {
      return this.authority.host;
    }

    auto port() {
      return this.authority.port;
    }

    URI opBinary(string op)(Path rhs)
    {
      static if (op == "~") {
        return URI(scheme, authority, path ~ rhs, Query(""), "");
      } else {
        static assert(0, "The `" ~ op ~ "` operator is not supported.");
      }
    }

    URI opBinary(string op)(Query rhs)
    {
        static if (op == "~") {
          return URI(scheme, authority, path, rhs, "");
        } else {
          static assert(0, "The `" ~ op ~ "` operator is not supported.");
        }
    }

    string toString() {
      string result;

      if(scheme.length > 0) {
        result = scheme.value ~ ":";
      }

      auto strAuthority = authority.toString;
      if(strAuthority != "") {
        result ~= "//" ~ strAuthority;
      }

      if(result != "" && path.length > 0 && !path.isAbsolute) {
        result ~= "/";
      }

      result ~= path.toString;

      if(query.length > 0) {
        result ~= "?" ~ query;
      }

      if(fragment.length > 0) {
        result ~= "#" ~ fragment;
      }

      return result;
    }
}

version(unittest) {
  import fluent.asserts;
}

/// Parse an url with all the elements
unittest {
  auto uri = URI("abc://username:password@example.com:123/path/data?key=value&key2=value2#fragid1");

  uri.scheme.value.should.equal("abc");
  uri.userInformation.should.equal("username:password");
  uri.host.should.equal("example.com");
  uri.port.should.equal(123);
  uri.path.value.should.equal("/path/data");
  uri.query.value.should.equal("key=value&key2=value2");
  uri.fragment.should.equal("fragid1");
  uri.toString.should.equal("abc://username:password@example.com:123/path/data?key=value&key2=value2#fragid1");
}

/// Parse an url with all the elements and empty fragment
unittest {
  auto uri = URI("abc://username:password@example.com:123/path/data?key=value&key2=value2#");

  uri.scheme.value.should.equal("abc");
  uri.userInformation.should.equal("username:password");
  uri.host.should.equal("example.com");
  uri.port.should.equal(123);
  uri.path.value.should.equal("/path/data");
  uri.query.value.should.equal("key=value&key2=value2");
  uri.fragment.should.equal("");
  uri.toString.should.equal("abc://username:password@example.com:123/path/data?key=value&key2=value2");
}

/// Parse an url with no query string and empty fragment
unittest {
  auto uri = URI("abc://username:password@example.com:123/path/data#");

  uri.scheme.value.should.equal("abc");
  uri.userInformation.should.equal("username:password");
  uri.host.should.equal("example.com");
  uri.port.should.equal(123);
  uri.path.value.should.equal("/path/data");
  uri.query.value.should.equal("");
  uri.fragment.should.equal("");
  uri.toString.should.equal("abc://username:password@example.com:123/path/data");
}

/// Parse an url without scheme and user information
unittest {
  auto uri = URI("//example.com:123/path/data?key=value&key2=value2#fragid1");

  uri.scheme.value.should.equal("");
  uri.userInformation.should.equal("");
  uri.host.should.equal("example.com");
  uri.port.should.equal(123);
  uri.path.value.should.equal("/path/data");
  uri.query.value.should.equal("key=value&key2=value2");
  uri.fragment.should.equal("fragid1");
  uri.toString.should.equal("//example.com:123/path/data?key=value&key2=value2#fragid1");
}

/// Parse an url with domain and path
unittest {
  auto uri = URI("//example.com/scheme-relative/URI/with/absolute/path/to/resource");

  uri.scheme.value.should.equal("");
  uri.userInformation.should.equal("");
  uri.host.should.equal("example.com");
  uri.port.should.equal(0);
  uri.path.value.should.equal("/scheme-relative/URI/with/absolute/path/to/resource");
  uri.query.value.should.equal("");
  uri.fragment.should.equal("");
  uri.toString.should.equal("//example.com/scheme-relative/URI/with/absolute/path/to/resource");
}

/// Parse an url that is a document name
unittest {
  auto uri = URI("documentation.html");

  uri.scheme.value.should.equal("");
  uri.userInformation.should.equal("");
  uri.host.should.equal("");
  uri.port.should.equal(0);
  uri.path.value.should.equal("documentation.html");
  uri.query.value.should.equal("");
  uri.fragment.should.equal("");
  uri.toString.should.equal("documentation.html");
}

/// Parse an url that is a document name with a query
unittest {
  auto uri = URI("documentation.html?query");

  uri.scheme.value.should.equal("");
  uri.userInformation.should.equal("");
  uri.host.should.equal("");
  uri.port.should.equal(0);
  uri.path.value.should.equal("documentation.html");
  uri.query.value.should.equal("query");
  uri.fragment.should.equal("");
  uri.toString.should.equal("documentation.html?query");
}

/// Parse an url that that has no path
unittest {
  auto uri = URI("http://example.com");

  uri.scheme.value.should.equal("http");
  uri.userInformation.should.equal("");
  uri.host.should.equal("example.com");
  uri.port.should.equal(0);
  uri.path.value.should.equal("");
  uri.query.value.should.equal("");
  uri.fragment.should.equal("");
  uri.toString.should.equal("http://example.com");
}

/// Parse an url that that has no path
unittest {
  auto uri = URI("http://example.com/path?query");

  (uri.path ~ uri.query).toString.should.equal("/path?query");
}

/// Parse an url with root path and query
unittest {
  auto uri = URI("http://example.com/?query");

  (uri.path ~ uri.query).toString.should.equal("/?query");
}

/// Parse a path with : and no port
unittest {
  auto uri = URI("../Static:MCCL");
  uri.path.toString.should.equal("../Static:MCCL");
}


/// Parse a url without : after protocol
unittest {
  auto uri = URI("http//example.com");
  uri.toString.should.equal("http://example.com");
}


/// Parse an url with trailing paths and query
unittest {
  auto uri = URI("http://example.com/path/?query");

  (uri.path ~ uri.query).toString.should.equal("/path/?query");
}


/// Get the domain from an url without path
unittest {
  auto uri = URI("https://www.demo.com?ref=val");

  uri.authority.host.should.equal("www.demo.com");
  uri.query.value.should.equal("ref=val");
}

/// Parse an uri with invalid scheme should throw an exception
unittest {
  ({
    URI("http://http://www.demo.com");
  }).should.throwException!URIParseException.withMessage.equal("Can not parse the URI authority");
}
