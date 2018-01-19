module valley.service.client;

import std.string;
import std.algorithm;
import std.array;
import std.range;
import vibe.http.websockets : WebSocket;

import vibe.data.json;

import valley.storage.base;
import valley.uri;

struct Result {
  ulong id;
  string title;
  string description;
  URI location;
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

    string queryString;
  }

  this(Storage storage, Connection connection) {
    this.storage = storage;
    this.connection = connection;

    this.connection.onMessage(&this.onMessage);
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
    this.queryString = queryString;
  }

  void getAll(string model) {
    auto result = storage.query(queryString).enumerate.map!(a => Result(a[0],
        a[1].title, a[1].description, a[1].location));

    connection.send(`{"searchResults":` ~ result.array.serializeToJsonString ~ `}`);
  }
}
