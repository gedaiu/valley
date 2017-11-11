module valley.robots;

import std.string;

/// http://www.robotstxt.org/norobots-rfc.txt
/// https://en.wikipedia.org/wiki/Robots_exclusion_standard

struct Agent {
  string[] disallow;
}

struct Robots {

  immutable Agent[string] agents;

  this(string content) {
    string[][string][string] agents;
    string currentAgent;

    foreach(line; content.lineSplitter) {
      auto pos = line.indexOf(":");

      if(pos != -1) {
        auto pieces = line.split(":");

        if(pieces[0] == "User-agent") {
          currentAgent = pieces[1].strip;
          string[][string] emptyList;
          agents[currentAgent] = emptyList;
        }

        if(pieces[0] == "Disallow") {
          agents[currentAgent]["Disallow"] ~= pieces[1].strip;
        }
      }
    }

    Agent[string] tmpAgents;
    foreach(string name, properties; agents) {
      tmpAgents[name] = Agent(properties["Disallow"]);
    }

    this.agents = cast(immutable) tmpAgents;
  }
}

version(unittest) {
  import fluent.asserts;
}

/// Parsing a simple robots.txt
unittest {
  auto robots = Robots("User-agent: *\nDisallow:");

  robots.agents.length.should.equal(1);
  robots.agents.keys.should.equal([ "*" ]);
  robots.agents["*"].disallow.length.should.equal(1);
  robots.agents["*"].disallow[0].should.equal("");
}

/// Parsing robots.txt with two user agents
unittest {
  auto robots = Robots(`User-agent: a
Disallow: /private/

User-agent: b
Disallow: /
`);

  robots.agents.length.should.equal(2);
  robots.agents.keys.should.contain([ "a", "b" ]);
  robots.agents["a"].disallow.length.should.equal(1);
  robots.agents["a"].disallow[0].should.equal("/private/");

  robots.agents["b"].disallow.length.should.equal(1);
  robots.agents["b"].disallow[0].should.equal("/");
}