module tests.valley.stemmer.en;

import fluent.asserts;
import trial.discovery.spec;

import valley.stemmer;

import std.file;
import std.conv;
import std.datetime;

private alias suite = Spec!({
  describe("english stemmer", {
    static immutable stems = [
      ["consign", "consign"],
      ["consigned", "consign"],
      ["consigning", "consign"],
      ["consignment", "consign"],
      ["consist", "consist"],
      ["consisted", "consist"],
      ["consistency", "consist"],
      ["consistent", "consist"],
      ["consistently", "consist"],
      ["consisting", "consist"],
      ["consists", "consist"],
      ["consolation", "consol"],
      ["consolations", "consol"],
      ["consolatory", "consolatori"],
      ["console", "consol"],
      ["consoled", "consol"],
      ["consoles", "consol"],
      ["consolidate", "consolid"],
      ["consolidated", "consolid"],
      ["consolidating", "consolid"],
      ["consoling", "consol"],
      ["consolingly", "consol"],
      ["consols", "consol"],
      ["consonant", "conson"],
      ["consort", "consort"],
      ["consorted", "consort"],
      ["consorting", "consort"],
      ["conspicuous", "conspicu"],
      ["conspicuously", "conspicu"],
      ["conspiracy", "conspiraci"],
      ["conspirator", "conspir"],
      ["conspirators", "conspir"],
      ["conspire", "conspir"],
      ["conspired", "conspir"],
      ["conspiring", "conspir"],
      ["constable", "constabl"],
      ["constables", "constabl"],
      ["constance", "constanc"],
      ["constancy", "constanc"],
      ["constant", "constant"],
      ["knack", "knack"],
      ["knackeries", "knackeri"],
      ["knacks", "knack"],
      ["knag", "knag"],
      ["knave", "knave"],
      ["knaves", "knave"],
      ["knavish", "knavish"],
      ["kneaded", "knead"],
      ["kneading", "knead"],
      ["knee", "knee"],
      ["kneel", "kneel"],
      ["kneeled", "kneel"],
      ["kneeling", "kneel"],
      ["kneels", "kneel"],
      ["knees", "knee"],
      ["knell", "knell"],
      ["knelt", "knelt"],
      ["knew", "knew"],
      ["knick", "knick"],
      ["knif", "knif"],
      ["knife", "knife"],
      ["knight", "knight"],
      ["knightly", "knight"],
      ["knights", "knight"],
      ["knit", "knit"],
      ["knits", "knit"],
      ["knitted", "knit"],
      ["knitting", "knit"],
      ["knives", "knive"],
      ["knob", "knob"],
      ["knobs", "knob"],
      ["knock", "knock"],
      ["knocked", "knock"],
      ["knocker", "knocker"],
      ["knockers", "knocker"],
      ["knocking", "knock"],
      ["knocks", "knock"],
      ["knopp", "knopp"],
      ["knot", "knot"],
      ["knots", "knot"],
      ["news", "news"],
      ["dying", "die"],
      ["cries", "cri"],
      ["by", "by"],
      ["say", "say"],
      ["ties", "tie"],
      ["cry", "cri"]
    ];

    static foreach(words; stems) {
      it("should get the stem for '" ~ words[0] ~ "'", {
        auto stem = new EnStemmer;
        stem.get(words[0]).should.equal(words[1]);
      });
    }
  });
});
