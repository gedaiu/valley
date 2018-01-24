module valley.service.client;

import std.string;
import std.algorithm;
import std.array;
import std.range;
import std.conv;
import vibe.http.websockets : WebSocket;

import vibe.data.json;

import valley.storage.base;
import valley.uri;
import valley.stemmer.english;
import valley.stemmer.cleaner;

struct Result {
  ulong id;
  string title;
  string description;
  URI location;

  double score;
}

Json toJson(Result result) {
  auto serialized = Json.emptyObject;

  serialized["id"] = result.id;
  serialized["title"] = result.title;
  serialized["description"] = result.description;
  serialized["location"] = result.location.toString;
  serialized["score"] = result.score;

  return serialized;
}

interface Connection {
  void send(string);
  void onMessage(void delegate(string));
}

class WebsocketConnection : Connection {
  private {
    void delegate(string) messageEvent;
    WebSocket socket;
  }

  this(WebSocket socket) {
    this.socket = socket;
  }

  void send(string message) {
    socket.send(message);
  }

  void onMessage(void delegate(string) messageEvent) {
    this.messageEvent = messageEvent;
  }

  void start() {
    while (socket.waitForData()) {
      auto txt = socket.receiveText;
      messageEvent(txt);
    }
  }
}

class ClientService {
  private {
    Storage storage;
    Connection connection;

    string[] query;
    EnStemmer stem;
  }

  this(Storage storage, Connection connection) {
    this.storage = storage;
    this.connection = connection;

    this.connection.onMessage(&this.onMessage);
    this.stem = new EnStemmer;
  }

  void onMessage(const string message) {
    auto pos = message.indexOf(":");
    auto instruction = message[0 .. pos];
    auto param = message[pos + 1 .. $];

    switch (instruction) {
      case "query":
        setQuery(param);
        break;

      case "get all":
        getAll(param);
        break;

      default:
    }
  }

  void setQuery(string queryString) {
    query = queryString.clean.split(" ").map!(a => stem.get(a)).array;

    import std.stdio;
    writeln(query);
  }

  void getAll(string model) {

    Result[] result = storage.query(query.join(" "), 0, 1000).enumerate
      .map!(a => Result(a[0], a[1].title, a[1].description, a[1].location, score(a.value)))
      .array;

    auto indexList = new size_t[result.length];
    result.makeIndex!"a.score > b.score"(indexList);

    auto sortedResult = indexed(result, indexList).take(50).array;

    connection.send(`{"searchResults":` ~ sortedResult.map!(a => a.toJson).array.serializeToJsonString ~ `}`);
  }

  double score(IPageData pageData) {
    return pageData.countPresentKeywords(query).to!double / query.length.to!double;
  }
}
