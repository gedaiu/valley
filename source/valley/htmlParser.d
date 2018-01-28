module valley.htmlParser;

import valley.uri;

import std.stdio;
import std.file;
import std.conv;
import std.string;
import std.algorithm;
import std.array;
import std.math;
import std.digest.sha;

import html.dom;
import valley.storage.base;
import valley.stemmer.english;
import valley.stemmer.cleaner;

class HTMLDocument {

  private {
    Document doc;
    immutable string _hash;
  }

  URI uri;

  this(URI uri, string document) {
    doc = createDocument(document);

    if(document != "") {
      _hash = toHexString(sha1Of(document)).to!string;
    } else {
      _hash = "";
    }

    this.uri = uri;
  }

  string title() {
    auto node = doc.querySelector("title");

    if(node is null) {
      return "";
    }

    return node.text.to!string;
  }

  string[] links() {
    string[] list;

    foreach(a; doc.querySelectorAll("a")) {
      if(a.hasAttr("href")) {
        try {
          auto link = a.attr("href").strip.to!string.toAbsoluteLink(uri.toString);
          list ~= link.removeFragment;
        } catch(URIParseException) {}
      }
    }

    return list.filter!(a => a != "").array.sort.array;
  }

  auto plainText() {
    auto bodyNode = doc.querySelector("body");
    if(bodyNode is null) {
      return "";
    }

    string[] pieces;

    string rawText = bodyNode.text.replace("\n", " ").split(" ").filter!(a => a != "").join(" ").to!string;

    foreach(p; doc.querySelectorAll("style")) {
      rawText = rawText.replace(p.text.replace("\n", " ").split(" ").filter!(a => a != "").join(" "), "");
    }

    foreach(p; doc.querySelectorAll("script")) {
      rawText = rawText.replace(p.text.replace("\n", " ").split(" ").filter!(a => a != "").join(" "), "");
    }

    return rawText.replace("\n", " ").replace("\r", " ").replace("\t", " ").split(" ").filter!(a => a != "").join(" ");
  }

  string meta() {
    foreach(p; doc.querySelectorAll("meta")) {
      if(p.hasAttr("name") && p.hasAttr("content") && p.attr("name").toLower == "description") {
        return p.attr("content").to!string.strip;
      }
    }

    return "";
  }

  string hash() {
    return _hash;
  }

  string preview() {
    auto paragraphs = doc.querySelectorAll("p").map!(a => a.text.strip)
      .filter!(a => a.count(" ") > 3)
      .filter!(a => a.canFind(".") || a.canFind("!") || a.canFind("?"))
      .filter!(a => a.length > 20);

    string text;
    string glue;

    foreach(paragraph; paragraphs) {
      text ~= glue ~ paragraph;
      glue = " ";

      if(text.length > 250) {
        break;
      }
    }

    if(text.length == 0) {
      text = plainText.strip;
      size_t len = min(250, text.length);
      text = text[0..len];
    }

    text = text.replace("\n", " ").replace("\r", " ").replace("\t", " ").split(" ").filter!(a => a != "").join(" ");

    return text;
  }

  string[] robots() {
    foreach(p; doc.querySelectorAll("meta")) {
      if(p.hasAttr("name") && p.hasAttr("content") && p.attr("name").toLower == "robots") {
        return p.attr("content").to!string.toLower.split(",").map!(a => a.strip).array;
      }
    }

    return [];
  }

  Keyword[] keywords() {
    auto stem = new EnStemmer;
    string[] keywords = plainText.clean.split(" ").map!(a => a.strip.toLower).map!(a => stem.get(a)).array.sort.array;
    string[] uniqueKeywords = keywords.uniq.array;

    Keyword[] finalKeywords;

    foreach(keyword; uniqueKeywords) {
      finalKeywords ~= Keyword(keyword, keywords.count!(a => a == keyword));
    }

    return finalKeywords;
  }

  bool isNoindex() {
    return robots.canFind("noindex");
  }

  bool isNofollow() {
    return robots.canFind("nofollow");
  }
}


string toAbsoluteLink(const string link, const string base) pure {
  auto linkUri = URI(link);
  auto baseUri = URI(base);

  if(linkUri.host != "") {
    return linkUri.scheme.value != "" ? linkUri.toString : (baseUri.scheme ~ linkUri).toString.removeFragment;
  }

  return (baseUri.scheme ~ baseUri.authority ~ baseUri.path ~ linkUri.path ~ linkUri.query).toString.removeFragment;
}

string removeFragment(const string link) pure {
  auto linkUri = URI(link);
  return (linkUri.scheme ~ linkUri.authority ~ linkUri.path ~ linkUri.query).toString;
}
