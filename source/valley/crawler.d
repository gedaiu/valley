module valley.crawler;

import valley.uri;
import valley.robots;

import vibe.http.client;
import vibe.stream.operations;

import std.functional;
import std.socket;
import std.datetime;
import std.algorithm;
import std.exception;

version (unittest)
{
  import fluent.asserts;
}

/// A special uri queue used by the crawler to fetch new pages.
/// It will fetch an uri once, so if you want to fetch same page multiple
/// times you need to create a new queue. This queue will also apply the robots.txt
/// rules.
class UriQueue {

  private const {
    Agent agent;
    URI baseUri;
  }

  private {
    const(URI)[] queue;
    size_t start;
  }

  ///
  this(const Agent agent, const URI baseUri) {
    this.agent = agent;
    this.baseUri = baseUri;
    queue ~= baseUri;
  }

  /// Add a new uri to the queue. If the uri was
  /// previously added it will be ignored
  void add(const URI uri) {
    enforce(uri.host == baseUri.host , "Can not add uris from a different host.");

    if(!agent.canAccess(uri)) {
      return;
    }

    string strUri = uri.toString;
    bool isNotProcessed = queue.map!"a.toString".filter!(a => a == strUri).empty;

    if(isNotProcessed) {
      queue ~= uri;
    }
  }

  /// Check if there are uris to be processed
  bool empty() const {
    return queue.length == start;
  }

  /// Get an uri from the queue
  const(URI) pop() {
    enforce(!empty, "Can not pop an empty queue.");
    auto value = queue[start];
    start++;

    return value;
  }
}

/// URIQueue should be initialised with the base uri
unittest {
  auto queue = new UriQueue(Agent(), URI("http://example.com/index.html"));

  queue.empty.should.equal(false);
  queue.pop.toString.should.equal("http://example.com/index.html");
  queue.empty.should.equal(true);
}

/// URIQueue should not be empty after an uri is added
unittest {
  auto queue = new UriQueue(Agent(), URI("http://example.com/index.html"));
  queue.pop(); /// pop the base uri

  queue.add(URI("http://example.com/other.html"));
  queue.empty.should.equal(false);

  queue.pop.toString.should.equal("http://example.com/other.html");
  queue.empty.should.equal(true);
}

/// URIQueue should be empty if a processed uri is added
unittest {
  auto queue = new UriQueue(Agent(), URI("http://example.com/index.html"));
  queue.pop(); /// pop the base uri

  queue.add(URI("http://example.com/index.html"));
  queue.empty.should.equal(true);
}

/// URIQueue should throw an exception on poping an empty queue
unittest {
  auto queue = new UriQueue(Agent(), URI("http://example.com/index.html"));
  queue.pop(); /// pop the base uri

  ({
    queue.pop;
  }).should.throwAnyException.withMessage.equal("Can not pop an empty queue.");
}

/// URIQueue should apply robots rules
unittest {
  auto queue = new UriQueue(Agent([ "/private/" ]), URI("http://example.com/index.html"));
  queue.pop(); /// pop the base uri

  queue.add(URI("http://example.com/private/page.html"));
  queue.empty.should.equal(true);
}

/// URIQueue should throw an exception on poping an empty queue
unittest {
  auto queue = new UriQueue(Agent(), URI("http://example.com/index.html"));

  ({
    queue.add(URI("http://other.com/index.html"));
  }).should.throwAnyException.withMessage.equal("Can not add uris from a different host.");
}

struct Page
{
  URI uri;
  int statusCode;
  string[string] headers;
  string content;
}

///
class Crawler
{
  private
  {
    void delegate(scope Page) callback;
    void delegate(const URI uri, void delegate(scope Page) @system callback) request;

    UriQueue[string] queues;

    immutable string agentName;
  }

  ///
  this(const string agentName) {
    this.agentName = agentName.idup;
  }

  private void responseHandler(scope Page page)
  {
    this.callback(page);
  }

  ///
  void add(URI uri)
  {
    if(uri.host in queues) {
      queues[uri.host].add(uri);
      return;
    }

    void robotsHandler(scope Page page) {
      queues[uri.host] = new UriQueue(Robots(page.content).get(agentName), uri);
    }

    this.request(uri ~ "/robots.txt".path, &robotsHandler);
  }

  void next()
  {
    auto freeQueues = queues.byValue.filter!"!a.empty";

    if(freeQueues.empty) {
      return;
    }

    this.request(freeQueues.front.pop, &responseHandler);
  }

  void onRequest(T)(T request)
  {
    this.request = request.toDelegate;
  }

  void onResult(T)(T callback)
  {
    this.callback = callback.toDelegate;
  }
}

version(unittest) {
  void nullSinkResult(scope Page) { }
  void failureRequest(const URI uri, void delegate(scope Page) @system callback) { assert(false, "No request should be performed"); }
}

/// GET the robots.txt on the first request
unittest
{
  auto crawler = new Crawler("");
  int index;

  void requestHandler(const URI uri, void delegate(scope Page) @system callback)
  {
    scope (exit)
    {
      index++;
    }

    if (index == 0)
    {
      uri.toString.should.equal("http://something.com/robots.txt");
    }

    if (index == 1)
    {
      uri.toString.should.equal("http://something.com");
    }

    string[string] headers;
    callback(Page(uri, 200, headers, ""));
  }

  crawler.onRequest(&requestHandler);
  crawler.onResult(&nullSinkResult);
  crawler.add(URI("http://something.com"));
  crawler.next();

  index.should.equal(2);
}

/// GET all the added uris
unittest
{
  auto crawler = new Crawler("");
  string[] fetchedUris;

  void requestHandler(const URI uri, void delegate(scope Page) @system callback)
  {
    fetchedUris ~= uri.toString;

    string[string] headers;
    callback(Page(uri, 200, headers, ""));
  }

  crawler.onRequest(&requestHandler);
  crawler.onResult(&nullSinkResult);
  crawler.add(URI("http://something.com"));
  crawler.add(URI("http://something.com/page.html"));
  crawler.next();
  crawler.next();

  fetchedUris.should.contain([ "http://something.com", "http://something.com/page.html" ]);
}

/// Do not get anything if the queues are empty
unittest
{
  auto crawler = new Crawler("");

  ({
    crawler.onRequest(&failureRequest);
    crawler.onResult(&nullSinkResult);
    crawler.next();
  }).should.not.throwAnyException;
}

/// Perform an http request
void request(const URI uri, void delegate(scope Page) callback)
{
  HTTPClientSettings settings = new HTTPClientSettings;
  settings.dnsAddressFamily = AddressFamily.INET;

  requestHTTP(uri.toString, (scope HTTPClientRequest req) {  }, (scope HTTPClientResponse res) {
    string[string] headers;

    foreach (string key, string value; res.headers)
    {
      headers[key] = value;
    }

    auto page = Page(uri, res.statusCode, headers, res.bodyReader.readAllUTF8());

    callback(page);
  }, settings);
}

/// It should be able to get the first internet page
unittest
{
  bool hasResult;
  string firstPage = "http://info.cern.ch/hypertext/WWW/TheProject.html";

  request(URI(firstPage), (scope Page page) {
    hasResult = true;
    page.uri.toString.should.equal(firstPage);
    page.statusCode.should.equal(200);
    page.content.should.contain("WorldWideWeb");

    page.headers.keys.should.containOnly(["Last-Modified", "Accept-Ranges",
      "Content-Length", "Connection", "Server", "Content-Type", "Date", "ETag"]);

    page.headers["Content-Type"].should.equal("text/html");
  });

  hasResult.should.equal(true);
}
