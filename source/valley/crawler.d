module valley.crawler;

import valley.uri;
import valley.robots;

import vibe.http.client;
import vibe.stream.operations;
import vibe.core.core;

import std.functional;
import std.socket;
import std.datetime;
import std.algorithm;
import std.utf;
import std.string;
import std.exception;
import std.array;

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

  /// Get the number of elements from the queue
  size_t size() {
    return queue.length;
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
    Task[] taskList;

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
    string strAuthority = page.uri.authority.toString;

    queues[strAuthority].busy = false;
    queues[strAuthority].lastFetch = Clock.currTime;

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
    enforce(request !is null, "the request handler is not set.");

    string strAuthority = uri.authority.toString;

    if (!settings.authorityWhitelist.canFind(strAuthority)) {
      return;
    }

    if (strAuthority in queues) {
      queues[uri.authority.toString].add(uri);
      return;
    }

    pending[strAuthority] ~= uri;

    void robotsHandler(bool success, scope CrawlPage page) {
      if(success) {
        queues[strAuthority] = new UriQueue(Robots(page.content).get(agentName),
            uri.authority, defaultDelay);
      } else {
        queues[strAuthority] = new UriQueue(uri.authority, defaultDelay);
      }

      foreach (uri; pending[strAuthority]) {
        queues[strAuthority].add(uri);
      }
      pending.remove(strAuthority);

      queues[strAuthority].busy = false;
    }

    if (pending[strAuthority].length == 1) {
      taskList ~= runTask({
        this.request(uri ~ "/robots.txt".path, &robotsHandler);
      });
    }
  }

  void finish() {
    taskList = taskList.filter!(a => a.running).array;

    foreach(task; taskList) {
      task.join;
    }
  }

  bool isFullWorking() {
    return queues.byValue.filter!"!a.empty".empty || pending.keys.length > 0;
  }

  void next() {
    auto freeQueues = queues.byValue.filter!"!a.empty".filter!(a => !a.busy).array;
    taskList = taskList.filter!(a => a.running).array;

    if (freeQueues.length == 0) {
      foreach(task; taskList) {
        task.join;
      }

      return;
    }

    auto selectedQueue = freeQueues.maxElement!"a.size";
    selectedQueue.busy = true;
    auto uri = selectedQueue.pop;

    taskList ~= runTask({
      this.request(uri, &responseHandler);
    });

    if(queues.byValue.all!"a.empty" && emptyQueue !is null) {
      foreach(host; settings.authorityWhitelist) {
        emptyQueue(host);
      }
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

      if("Content-Type" !in res.headers || res.headers["Content-Type"].indexOf("text") == -1) {
        callback(false, CrawlPage(uri, res.statusCode, headers));
        return;
      }

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
