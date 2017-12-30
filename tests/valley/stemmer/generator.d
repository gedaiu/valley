module tests.valley.stemmer.generator.d;

import fluent.asserts;
import trial.discovery.spec;

import valley.stemmer;

import std.file;
import std.conv;
import std.datetime;

private alias suite = Spec!({
  describe("stemmer", {
    describe("the alphabet", {
      it("should replace the vowels in a pattern", {
        auto generator = new Alphabet!(["a", "e", "i", "u", "o", "y"]);

        generator.get("Vdfg").should.equal([
          "adfg","edfg","idfg","udfg","odfg","ydfg",
        ]);
      });

      it("should generate the combination vowels in a pattern", {
        auto generator = new Alphabet!(["a", "e", "i", "u", "o", "y"]);

        generator.get("VdVfg").should.containOnly([
          "adafg","edafg","idafg","udafg","odafg","ydafg",
          "adefg","edefg","idefg","udefg","odefg","ydefg",
          "adifg","edifg","idifg","udifg","odifg","ydifg",
          "adufg","edufg","idufg","udufg","odufg","ydufg",
          "adofg","edofg","idofg","udofg","odofg","ydofg",
          "adyfg","edyfg","idyfg","udyfg","odyfg","ydyfg",
        ]);
      });
    });

    describe("english alphabet", {

      it("should get the regions for 'consignment'", {
        EnglishAlphabet.region1("consignment").should.equal("signment");
        EnglishAlphabet.region2("consignment").should.equal("nment");
      });

      it("should get the regions for 'beautiful'", {
        EnglishAlphabet.region1("beautiful").should.equal("iful");
        EnglishAlphabet.region2("beautiful").should.equal("ul");
      });

      it("should get the regions for 'beauty'", {
        EnglishAlphabet.region1("beauty").should.equal("y");
        EnglishAlphabet.region2("beauty").should.equal("");
      });

      it("should get the regions for 'beau'", {
        EnglishAlphabet.region1("beau").should.equal("");
        EnglishAlphabet.region2("beau").should.equal("");
      });

      it("should get the regions for 'animadversion'", {
        EnglishAlphabet.region1("animadversion").should.equal("imadversion");
        EnglishAlphabet.region2("animadversion").should.equal("adversion");
      });

      it("should get the regions for 'sprinkled'", {
        EnglishAlphabet.region1("sprinkled").should.equal("inkled");
        EnglishAlphabet.region2("sprinkled").should.equal("ed");
      });

      it("should get the regions for 'eucharist'", {
        EnglishAlphabet.region1("eucharist").should.equal("arist");
        EnglishAlphabet.region2("eucharist").should.equal("ist");
      });
    });
  });
});