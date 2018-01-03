module tests.valley.uriQueue;

import fluent.asserts;
import trial.discovery.spec;

import valley.crawler;
import valley.uri;
import valley.robots;

import std.file;
import std.conv;
import std.datetime;
import std.file;
import std.string;
import std.conv;

import trial.step;

private alias suite = Spec!({

  describe("URIQueue", {
    it("should not be empty after an uri is added", {
      auto queue = new UriQueue(Agent(), Authority("example.com"), 0.seconds);

      queue.add(URI("http://example.com/other.html"));
      queue.empty.should.equal(false);

      queue.pop.toString.should.equal("http://example.com/other.html");
      queue.empty.should.equal(true);
    });

    it("should be empty if a processed uri is added", {
      auto queue = new UriQueue(Agent(), Authority("example.com"), 0.seconds);
      queue.add(URI("http://example.com/index.html"));
      queue.pop;

      queue.add(URI("http://example.com/index.html"));
      queue.empty.should.equal(true);
    });

    it("should throw an exception on poping an empty queue", {
      auto queue = new UriQueue(Agent(), Authority("example.com"), 0.seconds);

      ({ queue.pop; }).should.throwAnyException.withMessage.equal("Can not pop an empty queue.");
    });

    it("should apply robots rules", {
      auto queue = new UriQueue(Agent(["/private/"]), Authority("example.com"), 0.seconds);

      queue.add(URI("http://example.com/private/page.html"));
      queue.empty.should.equal(true);
    });

    it("should throw an exception on adding an uri from a different host", {
      auto queue = new UriQueue(Agent(), Authority("example.com"), 0.seconds);

      ({ queue.add(URI("http://other.com/index.html")); }).should.throwAnyException.withMessage.equal(
      "Can not add uris from a different host.");
    });
  });
});
