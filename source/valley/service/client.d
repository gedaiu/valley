module valley.service.client;

import std.string;
import std.algorithm;
import std.array;

import vibe.data.json;

import valley.storage.base;
import valley.uri;

struct Result {
  string title;
  string description;
  URI location;
}

interface Connection {
  void send(string);
  void onMessage(void delegate(string));
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
    auto instruction = message[0..pos];
    auto param = message[pos + 1..$];

    switch(instruction) {
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
    auto result = storage.query(queryString).map!(a => Result(a.title, a.description, a.location));

    connection.send(result.array.serializeToJsonString);
  }
}