module valley.htmlParser;

import valley.uri;

import std.stdio;
import std.file;
import std.conv;
import std.string;
import std.algorithm;
import std.array;

import html.dom;

version(unittest) import fluent.asserts;

struct Heading {
  ubyte level;
  string text;

  Node* node;
}

class HTMLDocument {

  private {
    Document doc;
  }

  this(string document) {
    doc = createDocument(document);
  }

  string title() {
    auto node = doc.querySelector("title");

    return node.text.to!string;
  }

  auto headings() {
    Heading[] list;
    byte currentlevel = 1;

    foreach(tag; ["h1", "h2", "h3", "h4", "h5", "h6"]) {
      foreach(p; doc.querySelectorAll(tag)) {
        list ~= Heading(currentlevel, p.text.to!string.strip, p.node_);
      }

      currentlevel++;
    }

    return list;
  }

  string[] links() {
    string[] list;

    foreach(a; doc.querySelectorAll("a")) {
      if(a.hasAttr("href")) {
        list ~= a.attr("href").strip.to!string;
      }
    }

    return list.filter!(a => a != "").array;
  }

  auto plainText() {
    auto bodyNode = doc.querySelector("body");
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
        return p.attr("content").to!string;
      }
    }

    return plainText[0..100];
  }
}

/// It should get the description from a twitter page
unittest {
  auto rawHtml = readText("testData/page1.html");
  auto html = new HTMLDocument(rawHtml);

  html.title.should.equal("Waiting for 34C3 (@c3daysleft) | Twitter");
  html.preview.should.equal(html.plainText[0..100]);
  html.links.length.should.be.greaterThan(0);
}

/// It should get the description from the home dlang page
unittest {
  auto rawHtml = readText("testData/page2.html");
  auto html = new HTMLDocument(rawHtml);

  html.title.should.equal("Home - D Programming Language");
  html.preview.should.equal("D is a general-purpose programming language with static typing, systems-level access, and C-like syntax.");

  html.links.length.should.be.greaterThan(0);
}

string toAbsoluteLink(string link, string base) {
  auto linkUri = URI(link);
  return (URI(base) ~ linkUri.path ~ linkUri.query).toString;
}

/// It should get the absolute link
unittest {
  "documentation.html".toAbsoluteLink("http://example.com").should.equal("http://example.com/documentation.html");
  "/documentation.html".toAbsoluteLink("http://example.com").should.equal("http://example.com/documentation.html");

  "documentation.html".toAbsoluteLink("http://example.com/pages/").should.equal("http://example.com/pages/documentation.html");
  "/documentation.html".toAbsoluteLink("http://example.com/pages/").should.equal("http://example.com/documentation.html");
}