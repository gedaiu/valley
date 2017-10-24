module valley.peer;

import std.algorithm;
import std.meta;
import std.array;

alias OnMessageEvent = void delegate(Message message) nothrow;

struct Message {
  string destinationId;
  string data;
}

class PeerCollection {
  ValleyPeer[] peers;

  alias peers this;

  ValleyPeer relayTo(string peerId) {
    struct Pair {
      ValleyPeer peer;
      int distance;
    }

    auto knownPeer = peers.map!(a => Pair(a, a.distanceTo(peerId))).array.sort!"a.distance < b.distance";

    if(knownPeer.length == 0) {
      throw new Exception("No peer.");
    }

    return knownPeer[0].peer;
  }
}

class ValleyPeer {
  string id;
  PeerCollection peers;

  private {
      OnMessageEvent[] onMessageEvents;
  }

  this() {
    peers = new PeerCollection;
  }

  void onMessage(OnMessageEvent event) {
    onMessageEvents ~= event;
  }

  int distanceTo(string peerId) {
    if(peerId == id) {
      return 0;
    }

    if(peers.map!"a.id".canFind(peerId)) {
      return 1;
    }

    return int.max;
  }

  void send(Message message) {
    if(message.destinationId == id) {
      foreach(event; onMessageEvents) {
        event(message);
      }

      return;
    }

    auto peer = peers.relayTo(message.destinationId);
    peer.send(message);
  }
}

version(unittest) {
  import fluent.asserts;
}

/// It should send a message using a relay peer
unittest {
  auto client1 = new ValleyPeer;
  client1.id = "client1";

  auto client2 = new ValleyPeer;
  client2.id = "client2";

  auto client3 = new ValleyPeer;
  client3.id = "client3";

  client1.peers ~= client2;
  client2.peers ~= client3;

  bool gotMessage;

  void messageHandler(Message message) nothrow {
    try {
      message.destinationId.should.equal(client3.id);
      message.data.should.equal("hello");
      gotMessage = true;
    } catch(Exception e) { }
  }

  client3.onMessage(&messageHandler);

  auto message = Message(client3.id, "hello");

  client1.send(message);

  gotMessage.should.equal(true);
}


/// It should send a message using a relay peer without sending to
/// peers that don't know the destination peer
unittest {
  auto client1 = new ValleyPeer;
  client1.id = "client1";

  auto client2 = new ValleyPeer;
  client2.id = "client2";

  auto client3 = new ValleyPeer;
  client3.id = "client3";

  auto client4 = new ValleyPeer;
  client4.id = "client4";

  client1.peers ~= [ client4, client2 ];
  client2.peers ~= client3;

  bool gotMessage;

  void messageHandler(Message message) nothrow {
    gotMessage = true;
  }

  client4.onMessage(&messageHandler);

  auto message = Message(client3.id, "hello");

  client1.send(message);

  gotMessage.should.equal(false);
}