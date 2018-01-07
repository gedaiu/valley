module valley.crawler;

import valley.uri;
import valley.robots;

import vibe.http.client;
import vibe.stream.operations;

import std.functional;
import std.socket;
import std.datetime;
import std.algorithm;
import std.utf;
import std.exception;

/// A special uri queue used by the crawler to fetch new pages.
/// It will fetch an uri once, so if you want to fetch same page multiple
/// times you need to create a new queue. This queue will also apply the robots.txt
/// rules.
class UriQueue {

  private const {
    Agent agent;
    Authority authority;
  }

  private {
    const(URI)[] queue;
    size_t start;
    Duration delay;

    bool _busy;
    SysTime lastFetch;
  }

  ///
  this(const Authority authority, Duration delay) {
    this(Agent(), authority, delay);
  }

  ///
  this(const Agent agent, const Authority authority, Duration delay) {
    this.agent = agent;
    this.authority = authority;
    lastFetch = Clock.currTime - 1.hours;

    this.delay = delay > agent.crawlDelay ? delay : agent.crawlDelay;
  }

  bool busy() const {
    if (_busy) {
      return true;
    }

    return Clock.currTime - delay < lastFetch;
  }

  void busy(bool value) {
    if (!value) {
      lastFetch = Clock.currTime;
    }

    _busy = value;
  }

  /// Add a new uri to the queue. If the uri was
  /// previously added it will be ignored
  void add(const URI uri) {
    enforce(uri.host == authority.host, "Can not add uris from a different host.");

    if (!agent.canAccess(uri)) {
      return;
    }

    string strUri = uri.toString;
    bool isNotProcessed = queue.map!"a.toString".filter!(a => a == strUri).empty;

    if (isNotProcessed) {
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

/// An fetched page
struct CrawlPage {
  URI uri;
  int statusCode;
  string[string] headers;
  string content;
}

/// The Crawler settings
immutable struct CrawlerSettings {
  string[] authorityWhitelist;
}

///
class Crawler {
  private {
    void delegate(immutable string authority) emptyQueue;
    void delegate(bool success, scope CrawlPage) callback;
    void delegate(const URI uri, void delegate(bool success, scope CrawlPage) @system callback) request;

    UriQueue[string] queues;
    URI[][string] pending;

    immutable {
      string agentName;
      Duration defaultDelay;
      CrawlerSettings settings;
    }
  }

  ///
  this(const string agentName, Duration defaultDelay, CrawlerSettings settings) {
    this.agentName = agentName.idup;
    this.defaultDelay = defaultDelay;
    this.settings = settings;
  }

  private void responseHandler(bool success, scope CrawlPage page) {
    queues[page.uri.host].busy = false;
    queues[page.uri.host].lastFetch = Clock.currTime;

    if (page.statusCode >= 300 && page.statusCode < 400) {
      if ("Location" in page.headers) {
        URI uri = URI(page.headers["Location"]);

        auto scheme = uri.scheme.value == "" ? page.uri.scheme : uri.scheme;
        auto authority = uri.authority.toString == "" ? page.uri.authority : uri.authority;
        auto path = uri.path;
        auto query = uri.query;
        auto fragment = uri.fragment;

        add(URI(scheme, authority, path, query, fragment));
      }
    }

    this.callback(success, page);
  }

  ///
  void add(URI uri) {
    if (!settings.authorityWhitelist.canFind(uri.authority.toString)) {
      return;
    }

    if (uri.host in queues) {
      queues[uri.host].add(uri);
      return;
    }

    pending[uri.host] ~= uri;

    void robotsHandler(bool success, scope CrawlPage page) {
      if(success) {
        queues[uri.host] = new UriQueue(Robots(page.content).get(agentName),
            uri.authority, defaultDelay);
      } else {
        queues[uri.host] = new UriQueue(uri.authority, defaultDelay);
      }

      foreach (uri; pending[uri.host]) {
        queues[uri.host].add(uri);
      }
    }

    if (pending[uri.host].length == 1) {
      this.request(uri ~ "/robots.txt".path, &robotsHandler);
    }
  }

  void next() {
    auto freeQueues = queues.byValue.filter!"!a.empty".filter!(a => !a.busy);

    if (freeQueues.empty) {
      return;
    }

    freeQueues.front.busy = true;
    auto uri = freeQueues.front.pop;
    this.request(uri, &responseHandler);

    if(queues.byValue.filter!"!a.empty".empty && emptyQueue !is null) {
      settings.authorityWhitelist.each!(a => emptyQueue(a));
      return;
    }

    if(freeQueues.front.empty && emptyQueue !is null) {
      emptyQueue(uri.authority.toString);
    }
  }

  void onEmptyQueue(T)(T event) {
    this.emptyQueue = event.toDelegate;
  }

  void onRequest(T)(T request) {
    this.request = request.toDelegate;
  }

  void onResult(T)(T callback) {
    this.callback = callback.toDelegate;
  }
}

/// Perform an http request
void request(const URI uri, void delegate(bool success, scope CrawlPage) callback) {
  import std.stdio;
  writeln("GET: ", uri.toString);
  HTTPClientSettings settings = new HTTPClientSettings;
  settings.dnsAddressFamily = AddressFamily.INET;

  try {
    requestHTTP(uri.toString, (scope HTTPClientRequest req) {  }, (scope HTTPClientResponse res) {
      string[string] headers;

      foreach (string key, string value; res.headers) {
        headers[key] = value;
      }

      string content;

      try {
        content = res.bodyReader.readAllUTF8(true);
      } catch(UTFException) {
        callback(false, CrawlPage(uri, res.statusCode, headers));
      }

      callback(true, CrawlPage(uri, res.statusCode, headers, content));
    }, settings);
  } catch(Exception) {
    callback(false, CrawlPage(uri));
  }
}
