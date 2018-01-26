module valley.htmlParser;

import valley.uri;

import std.stdio;
import std.file;
import std.conv;
import std.string;
import std.algorithm;
import std.array;
import std.math;

import html.dom;

class HTMLDocument {

  private {
    Document doc;
  }

  URI uri;

  this(URI uri, string document) {
    doc = createDocument(document);
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

    return list.filter!(a => a != "").array;
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

    return rawText;
  }

  string preview() {
    foreach(p; doc.querySelectorAll("meta")) {
      if(p.hasAttr("name") && p.hasAttr("content") && p.attr("name").toLower == "description") {
        return p.attr("content").to!string.strip;
      }
    }

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
        return text;
      }
    }

    text = plainText.strip;

    size_t len = min(250, text.length);

    return text[0..len];
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
