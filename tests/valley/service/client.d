module tests.valley.service.client;

import fluent.asserts;
import trial.discovery.spec;

import valley.service.client;
import valley.storage.base;
import valley.uri;
import std.file;
import std.conv;
import std.datetime;

class MockConnection : Connection {
  string result;

  private {
    void delegate(string) event;
  }

  void mockSend(string message) {
    event(message);
  }

  void send(string message) {
    result ~= message ~ "\n";
  }

  void onMessage(void delegate(string) event) {
    this.event = event;
  }
}

class MockStorage : Storage {
  string _queryString;

  void add(PageData) {}
  void remove(URI) {}

  IPageData[] query(string queryString, size_t, size_t) {
    _queryString = queryString;
    return [ PageData("mock title", URI("http://location.com"), "some description").toClass ];
  }

  URI[] pending(const Duration, const size_t count, const string pending = "") {
    return [];
  }

  ulong[] getKeywordId(string[] keywords) {
    return [];
  }
}

private alias suite = Spec!({
  describe("The client service", {
    it("should get the data from the storage using the setQuery command", {
      auto mockStorage = new MockStorage;
      auto mockConnection = new MockConnection;
      auto client = new ClientService(mockStorage, mockConnection);

      mockConnection.mockSend("query:some description");
      mockConnection.mockSend("get all:results");

      mockStorage._queryString.should.equal("some descript");
      mockConnection.result.should.equal(`{"searchResults":[{"id":0,"description":"some description","title":"mock title","location":"http://location.com","score":0}]}` ~ "\n");
    });
  });
});
