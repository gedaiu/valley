module tests.valley.htmlParser;

import fluent.asserts;
import trial.discovery.spec;

import valley.htmlParser;
import valley.uri;
import std.file;

private alias suite = Spec!({
  describe("HTMLDocument", {
    it("should get the description from a twitter page", {
      auto rawHtml = readText("testData/page1.html");
      auto html = new HTMLDocument(URI("https://twitter.com/c3daysleft?lang=en"), rawHtml);

      html.title.should.equal("Waiting for 34C3 (@c3daysleft) | Twitter");
      html.preview.should.equal("Are you sure you want to view these Tweets? Viewing Tweets won't unblock @c3daysleft Bugged by all those strange people out there? Chin up, #34C3 will start in only 0x3B days!! :) Bugged by all those strange people out there? Chin up, #34C3 will start in only 62 days!! :)");
      html.links.length.should.be.greaterThan(0);
    });

    it("should get the description from the home dlang page", {
      auto rawHtml = readText("testData/page2.html");
      auto html = new HTMLDocument(URI("http://dlang.org"), rawHtml);

      html.title.should.equal("Home - D Programming Language");
      html.preview.should.equal(
      "D is a general-purpose programming language with static typing, systems-level access, and C-like syntax.");

      html.links.length.should.be.greaterThan(0);
    });

    it("should get the title and description from an empty page", {
      auto rawHtml = readText("testData/page3.html");
      auto html = new HTMLDocument(URI("http://dlang.org"), rawHtml);

      html.title.should.equal("");
      html.preview.should.equal("");

      html.links.length.should.equal(0);
    });

    it("should get the title and description from an empty string", {
      auto html = new HTMLDocument(URI("http://dlang.org"), "");

      html.title.should.equal("");
      html.preview.should.equal("");
      html.links.length.should.equal(0);
    });

  });

  describe("toAbsoluteLink", {
    it("should return the absolute link", {
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
    });
  });
});
