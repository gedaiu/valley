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

version(unittest) import fluent.asserts;

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

/// It should get the description from a twitter page
unittest {
  auto rawHtml = readText("testData/page1.html");
  auto html = new HTMLDocument(URI("https://twitter.com/c3daysleft?lang=en"), rawHtml);

  html.title.should.equal("Waiting for 34C3 (@c3daysleft) | Twitter");
  html.preview.should.equal("Are you sure you want to view these Tweets? Viewing Tweets won't unblock @c3daysleft Bugged by all those strange people out there? Chin up, #34C3 will start in only 0x3B days!! :) Bugged by all those strange people out there? Chin up, #34C3 will start in only 62 days!! :)");
  html.links.length.should.be.greaterThan(0);
}

/// It should get the description from the home dlang page
unittest {
  auto rawHtml = readText("testData/page2.html");
  auto html = new HTMLDocument(URI("http://dlang.org"), rawHtml);

  html.title.should.equal("Home - D Programming Language");
  html.preview.should.equal("D is a general-purpose programming language with static typing, systems-level access, and C-like syntax.");

  html.links.length.should.be.greaterThan(0);
}

/// It should get the title and description from an empty page
unittest {
  auto rawHtml = readText("testData/page3.html");
  auto html = new HTMLDocument(URI("http://dlang.org"), rawHtml);

  html.title.should.equal("");
  html.preview.should.equal("");

  html.links.length.should.equal(0);
}

/// It should get the title and description from an empty string
unittest {
  auto html = new HTMLDocument(URI("http://dlang.org"), "");

  html.title.should.equal("");
  html.preview.should.equal("");
  html.links.length.should.equal(0);
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

/// It should get the absolute link
unittest {
  "documentation.html".toAbsoluteLink("http://example.com").should.equal("http://example.com/documentation.html");
  "/documentation.html".toAbsoluteLink("http://example.com").should.equal("http://example.com/documentation.html");
  "../documentation.html".toAbsoluteLink("http://example.com/index.html").should.equal("http://example.com/documentation.html");

  "documentation.html".toAbsoluteLink("http://example.com/pages/").should.equal("http://example.com/pages/documentation.html");
  "documentation.html#".toAbsoluteLink("http://example.com/pages/").should.equal("http://example.com/pages/documentation.html");
  "documentation.html#fragment".toAbsoluteLink("http://example.com/pages/").should.equal("http://example.com/pages/documentation.html");
  "documentation.html".toAbsoluteLink("http://example.com/pages/?some").should.equal("http://example.com/pages/documentation.html");

  "/documentation.html".toAbsoluteLink("http://example.com/pages/").should.equal("http://example.com/documentation.html");
  "/documentation.html".toAbsoluteLink("http://example.com/pages/?some").should.equal("http://example.com/documentation.html");
  "/documentation.html?some".toAbsoluteLink("http://example.com/pages").should.equal("http://example.com/documentation.html?some");

  "http://informit.com/articles/article.aspx?p=1609144".toAbsoluteLink("http://dlang.org").should.equal("http://informit.com/articles/article.aspx?p=1609144");
  "//informit.com/articles/article.aspx?p=1609144".toAbsoluteLink("http://dlang.org").should.equal("http://informit.com/articles/article.aspx?p=1609144");

  "../Static:ABC".toAbsoluteLink("https://page.com/congress/Other:MCCL").should.equal("https://page.com/Static:ABC");
  "http//other.com".toAbsoluteLink("https://page.com").should.equal("http://other.com");
}
