/// http://www.robotstxt.org/norobots-rfc.txt
/// https://en.wikipedia.org/wiki/Robots_exclusion_standard
module valley.robots;

import std.string;
import std.algorithm;
import std.conv;
import std.datetime;

/// An agent rules
struct Agent {
  /// Which routes are not allowed to be crawled
  string[] disallow;

  /// Which routes are allowed to be crawled
  string[] allow;

  /// How much we should wait between the requests
  Duration crawlDelay;
}

/// Converts a string to a robot key
Robots.RobotKey toRobotKey(const string value) pure nothrow @safe {
  string key;

  try {
    key = value.strip.toLower;
  } catch(Exception e) {
    return Robots.RobotKey.unknown;
  }

  switch(key) {
    case "user-agent":
      return Robots.RobotKey.userAgent;

    case "disallow":
      return Robots.RobotKey.disallow;

    case "allow":
      return Robots.RobotKey.allow;

    case "crawl-delay":
      return Robots.RobotKey.crawlDelay;

    default:
      return Robots.RobotKey.unknown;
  }
}

/// Convert string to RobotKey
unittest {
  "user-agent".toRobotKey.should.equal(Robots.RobotKey.userAgent);
  "USER-AGENT".toRobotKey.should.equal(Robots.RobotKey.userAgent);

  "disallow".toRobotKey.should.equal(Robots.RobotKey.disallow);
  "allow".toRobotKey.should.equal(Robots.RobotKey.allow);
  "crawl-delay".toRobotKey.should.equal(Robots.RobotKey.crawlDelay);

  "".toRobotKey.should.equal(Robots.RobotKey.unknown);
}

private void add(Robots.RobotKey key)(const string[] currentAgents, ref string[][string][string] agents, string value) {
  foreach(currentAgent; currentAgents) {
    agents[currentAgent][key] ~= value;
  }
}

/// A robots.txt parser
struct Robots {

  /// The parsed keys in lower case
  enum RobotKey : string {
    /// Tells that the following rules
    // are for a certain user agent
    userAgent = "user-agent",

    /// Which routes can not pe crawled
    disallow = "disallow",

    /// Which routes can be crawled
    allow = "allow",

    /// Delay in seconds between crawling
    crawlDelay = "crawl-delay",

    /// Some invalid key
    unknown = "unknown"
  }

  immutable {
    /// All the parsed agents
    Agent[string] agents;
  }

  /// Parse a robots.txt
  this(string content) inout {
    string[][string][string] agents;
    string[] currentAgents;
    bool resetCurrentAgents;

    foreach(line; content.lineSplitter.map!(a => a.strip)) {
      auto commentPos = line.indexOf("#");
      if(commentPos == -1) {
        commentPos = line.length;
      }

      line = line[0..commentPos];

      if(line.indexOf(":") != -1) {
        const auto pieces = line.split(":");
        const string value = pieces[1].strip;
        const RobotKey key = pieces[0].toRobotKey;

        if(key == RobotKey.userAgent) {
          if(resetCurrentAgents) {
            currentAgents = [];
          }

          currentAgents ~= value;
          string[][string] emptyList;
          agents[value] = emptyList;
          resetCurrentAgents = false;
          continue;
        }

        if(key == RobotKey.disallow) {
          add!(RobotKey.disallow)(currentAgents, agents, value);
        }

        if(key == RobotKey.allow) {
          add!(RobotKey.allow)(currentAgents, agents, value);
        }

        if(key == RobotKey.crawlDelay) {
          add!(RobotKey.crawlDelay)(currentAgents, agents, value);
        }
      }

      resetCurrentAgents = true;
    }

    Agent[string] tmpAgents;
    foreach(string name, properties; agents) {
      string[] disallow;
      string[] allow;
      Duration crawlDelay = 0.seconds;

      if(RobotKey.disallow in properties) {
        disallow = properties[RobotKey.disallow];
      }

      if(RobotKey.allow in properties) {
        allow = properties[RobotKey.allow];
      }

      if(RobotKey.crawlDelay in properties) {
        try {
          crawlDelay = properties[RobotKey.crawlDelay][0].to!uint.seconds;
        } catch(ConvException) {
          crawlDelay = 0.seconds;
        }
      }

      tmpAgents[name] = Agent(disallow, allow, crawlDelay);
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
Disallow: /`);

  robots.agents.length.should.equal(2);
  robots.agents.keys.should.contain([ "a", "b" ]);
  robots.agents["a"].disallow.length.should.equal(1);
  robots.agents["a"].disallow[0].should.equal("/private/");

  robots.agents["b"].disallow.length.should.equal(1);
  robots.agents["b"].disallow[0].should.equal("/");
}

/// Parsing robots.txt with rules for two user agents
unittest {
  auto robots = Robots(`User-agent: a
User-agent: b
Disallow: /`);

  robots.agents.length.should.equal(2);
  robots.agents.keys.should.contain([ "a", "b" ]);
  robots.agents["a"].disallow.length.should.equal(1);
  robots.agents["a"].disallow[0].should.equal("/");

  robots.agents["b"].disallow.length.should.equal(1);
  robots.agents["b"].disallow[0].should.equal("/");
}

/// Parsing robots.txt with rules for two user agents
unittest {
  auto robots = Robots(`User-agent: a
User-agent: b
Disallow: /`);

  robots.agents.length.should.equal(2);
  robots.agents.keys.should.contain([ "a", "b" ]);
  robots.agents["a"].disallow.length.should.equal(1);
  robots.agents["a"].disallow[0].should.equal("/");

  robots.agents["b"].disallow.length.should.equal(1);
  robots.agents["b"].disallow[0].should.equal("/");
}

/// Parsing robots.txt with allow rules
unittest {
  auto robots = Robots(`User-agent: a
allow: /`);

  robots.agents.length.should.equal(1);
  robots.agents.keys.should.contain([ "a" ]);
  robots.agents["a"].disallow.length.should.equal(0);
  robots.agents["a"].allow.length.should.equal(1);
  robots.agents["a"].allow[0].should.equal("/");
}

/// Parsing robots.txt with comments
unittest {
  auto robots = Robots(`User-agent: googlebot        # all Google services
Disallow: /private/          # disallow this directory

User-agent: googlebot-news   # only the news service
Disallow: /                  # disallow everything

User-agent: *                # any robot
Disallow: /something/        # disallow this directory`);

  robots.agents.length.should.equal(3);
  robots.agents.keys.should.contain([ "googlebot", "googlebot-news", "*" ]);
  robots.agents["googlebot"].disallow.should.containOnly([ "/private/" ]);
  robots.agents["googlebot-news"].disallow.should.containOnly([ "/" ]);
  robots.agents["*"].disallow.should.containOnly([ "/something/" ]);
}

/// Parsing robots.txt with no new line sepparators
unittest {
  auto robots = Robots(`User-agent: googlebot
Disallow: /private/
User-agent: googlebot-news
Disallow: /
# missing new line
User-agent: *
Disallow: /something/`);

  robots.agents.length.should.equal(3);
  robots.agents.keys.should.contain([ "googlebot", "googlebot-news", "*" ]);
  robots.agents["googlebot"].disallow.should.containOnly([ "/private/" ]);
  robots.agents["googlebot-news"].disallow.should.containOnly([ "/" ]);
  robots.agents["*"].disallow.should.containOnly([ "/something/" ]);
}


/// Parsing robots.txt with valid Crawl-delay
unittest {
  auto robots = Robots(`User-agent: googlebot
Crawl-delay: 10`);

  robots.agents.length.should.equal(1);
  robots.agents["googlebot"].crawlDelay.should.equal(10.seconds);
}

/// Parsing robots.txt with invalid Crawl-delay
unittest {
  auto robots = Robots(`User-agent: googlebot
Crawl-delay: -10`);

  robots.agents.length.should.equal(1);
  robots.agents["googlebot"].crawlDelay.should.equal(0.seconds);
}
