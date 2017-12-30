module valley.stemmer;

import std.string;
import std.conv;
import std.algorithm;
import std.array;

interface IStemmer {
  string get(string) pure;
}

immutable interface IStemOperation {
  string get(const string value) pure;
}

immutable class Invariant : IStemOperation {
  immutable(string[]) list;

  this(immutable(string[]) list) pure {
    this.list = list;
  }

  static immutable(IStemOperation) opCall(immutable(string[]) list) pure {
    return new immutable Invariant(list);
  }

  string get(const string value) pure {
    if(list.canFind(value)) {
      return value;
    }

    return "";
  }
}

immutable class ReplaceWord : IStemOperation {

  immutable(string[2][]) list;

  this(immutable(string[2][]) list) {
    this.list = list;
  }

  static immutable(IStemOperation) opCall(immutable(string[2][]) list) {
    return new immutable ReplaceWord(list);
  }

  string get(const string value) pure {

    foreach(pair; list) {
      if(pair[0] == value) {
        return pair[1];
      }
    }

    return "";
  }
}

immutable class ReplaceAfter : IStemOperation {
  immutable(string[2][]) list;

  this(immutable(string[2][]) list) pure {
    this.list = list;
  }

  static immutable(IStemOperation) opCall(immutable(string[2][]) list) pure {
    return new immutable ReplaceAfter(list);
  }

  string get(const string value) pure {

    foreach(pair; list) {
      auto pos = value.indexOf(pair[0]);

      if(pos != -1) {
        return value[0..pos] ~ pair[1];
      }
    }

    return "";
  }
}

immutable class ReplacePostfix : IStemOperation {
  immutable(string[2][]) list;
  immutable size_t minLength;


  this(immutable(string[2][]) list, size_t minLength = 0) pure {
    this.list = list;
    this.minLength = minLength;
  }

  static immutable(IStemOperation) opCall(immutable(string[2][]) list, size_t minLength = 0) pure {
    return new immutable ReplacePostfix(list, minLength);
  }

  string get(const string value) pure {
    if(value.length <= minLength) {
      return "";
    }

    foreach(pair; list) {
      if(value.endsWith(pair[0])) {
        return value[0..$-pair[0].length] ~ pair[1];
      }
    }

    return "";
  }
}


immutable class InlineReplace : IStemOperation {

  immutable(string[2][]) list;

  this(immutable(string[2][]) list) pure {
    this.list = list;
  }

  static immutable(IStemOperation) opCall(const(string[2][]) list) pure {
    return new immutable InlineReplace(list.idup);
  }

  static immutable(IStemOperation) opCall(immutable(string[2][]) list) pure {
    return new immutable InlineReplace(list);
  }

  string get(const string value) pure {
    string result = value.dup;

    foreach(pair; list) {
      result = result.replace(pair[0], pair[1]);

      if(result != value) {
        return result;
      }
    }

    return "";
  }
}

immutable class RemovePostfix : IStemOperation {
  immutable(string[]) list;

  this(immutable(string[]) list) pure {
    this.list = list;
  }

  static immutable(IStemOperation) opCall(immutable(string[]) list) pure {
    return new immutable RemovePostfix(list);
  }

  string get(const string value) pure {
    foreach(element; list) {
      if(value.endsWith(element)) {
        return value[0 .. $ - element.length];
      }
    }

    return "";
  }
}

immutable class And : IStemOperation {
  immutable(IStemOperation[]) list;

  this(immutable(IStemOperation[]) list) pure {
    this.list = list;
  }

  static immutable(IStemOperation) opCall(immutable(IStemOperation[]) list) pure {
    return new immutable And(list);
  }

  string get(const string value) pure {
    auto result = value.dup.to!string;
    bool gotResult;

    foreach(operation; list) {
      auto tmp = operation.get(result);

      if(tmp != "") {
        gotResult = true;
        result = tmp;
      }
    }

    return gotResult ? result : "";
  }
}

immutable class Or : IStemOperation {
  immutable(IStemOperation[][]) list;

  this(immutable(IStemOperation[][]) list) pure {
    this.list = list;
  }

  static immutable(IStemOperation) opCall(immutable(IStemOperation[][]) list) pure {
    return new immutable Or(list);
  }

  static immutable(IStemOperation) opCall(immutable(IStemOperation[]) list) pure {
    return new immutable Or(list.map!(a => [a]).array.idup);
  }

  string get(const string value) pure {
    foreach(andList; list) {
      auto result = And(andList).get(value);

      if(result != "") {
        return result;
      }
    }

    return "";
  }
}

immutable abstract class StemOperationFromRegion(T) : IStemOperation {
  immutable {
    size_t region;
  }

  this(size_t region) pure {
    this.region = region;
  }

  string getRegion(const string value) pure {
    if(region == 0) {
      return value;
    }

    if(region == 1) {
      return T.region1(value);
    }

    if(region == 2) {
      return T.region2(value);
    }

    throw new Exception("Undefined region");
  }
}

immutable class RemovePostifixFromRegion(T) : StemOperationFromRegion!T {
  string postfix;

  this(size_t region, immutable string postfix) pure {
    super(region);

    this.postfix = postfix;
  }

  static immutable(IStemOperation) opCall(size_t region, immutable string postfix) pure {
    return new immutable RemovePostifixFromRegion!T(region, postfix);
  }

  string get(const string value) pure {
    string strRegion = getRegion(value);

    if(strRegion.endsWith(postfix)) {
      return value[0..$ - strRegion.length] ~ strRegion[0..$ - postfix.length];
    }

    return "";
  }
}

immutable class ReplaceFromRegion(T) : StemOperationFromRegion!T {
  immutable {
    string from;
    string to;
  }

  this(size_t region, immutable string from, immutable string to) pure {
    super(region);

    this.from = from;
    this.to = to;
  }

  static immutable(IStemOperation) opCall(size_t region, immutable string from, immutable string to) pure {
    return new immutable ReplaceFromRegion!T(region, from, to);
  }

  string get(const string value) pure {
    string strRegion = getRegion(value);

    return value[0..$ - strRegion.length] ~ strRegion.replace(from, to);
  }
}

immutable class ReplaceAfterFromRegion(T) : StemOperationFromRegion!T {
  immutable(string[2][]) list;

  this(size_t region, immutable(string[2][]) list) pure {
    super(region);

    this.list = list;
  }

  static immutable(IStemOperation) opCall(size_t region, immutable(string[2][]) list) pure {
    return new immutable ReplaceAfterFromRegion(region, list);
  }

  string get(const string value) pure {
    auto strRegion = getRegion(value);

    if(strRegion == "") {
      return "";
    }

    foreach(pair; list) {
      auto pos = strRegion.indexOf(pair[0]);

      if(pos != -1) {
        return value[0 .. $ - strRegion.length] ~ strRegion[0..pos] ~ pair[1];
      }
    }

    return "";
  }
}

immutable(string[]) removeLetters(const string[] letters, const string[] extra) pure {
  return letters.filter!(a => !extra.canFind(a)).array.idup;
}

string change(const string source, const string reference) pure {
  char[] result;
  result.length = source.length;

  foreach(index, char c; source) {
    if(c == '*') {
      result[index] = reference[index];
    } else {
      result[index] = source[index];
    }
  }

  return result.to!string;
}

struct Alphabet(string[] vowels, string[] extraLetters = []) {
  static:
    immutable {
      string[] alphabet =
      ["a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z"] ~
      extraLetters;

      string[] nonVowels = removeLetters(alphabet, vowels);
    }

    string[] replaceVowels(const string value) pure {
      if(!value.canFind!"a == 'V'") {
        return [ value ];
      }

      string[] list = [];

      foreach(vowel; vowels) {
        list ~= value.replaceFirst("V", vowel);
      }

      if(list[0].canFind!"a == 'V'") {
        list = list.map!(a => replaceVowels(a)).joiner.array;
      }

      return list;
    }

    string[] replaceNonVowels(const string value) pure {
      if(!value.canFind!"a == 'N'") {
        return [ value ];
      }

      string[] list = [];

      foreach(vowel; nonVowels) {
        list ~= value.replaceFirst("N", vowel);
      }

      if(list[0].canFind!"a == 'N'") {
        list = list.map!(a => replaceNonVowels(a)).joiner.array;
      }

      return list;
    }

    string[] replaceAny(const string value) pure {
      if(!value.canFind!"a == '*'") {
        return [ value ];
      }

      string[] list = [];

      foreach(ch; alphabet) {
        list ~= value.replaceFirst("*", ch);
      }

      if(list[0].canFind!"a == '*'") {
        list = list.map!(a => replaceAny(a)).joiner.array;
      }

      return list;
    }

    immutable(string[]) get(const string value) pure {
      return replaceVowels(value)
          .map!(a => replaceNonVowels(a))
          .joiner
          .map!(a => replaceAny(a))
          .joiner
          .filter!(a => !a.canFind("*")).array.idup;
    }

    string[2][] get(string replace)(const string value) pure {
      return get(value)
        .map!(a => cast(string[2])[a, change(replace, a)])
          .array;
    }

    string region1(string word) pure {
      if(word.length < 4) {
        return "";
      }

      foreach(i; 1..word.length - 1) {
        if(nonVowels.canFind(word[i..i+1]) && vowels.canFind(word[i+1..i+2])) {
          return word[i+1..$];
        }
      }

      return "";
    }

    string region2(string word) pure {
      return region1(region1(word));
    }
}

immutable class EnglishRule1b : IStemOperation {
  static immutable(IStemOperation) opCall() pure {
    return new immutable EnglishRule1b();
  }

  string get(const string value) pure {
    auto result = Or([
      RemovePostfix([ "ed", "ing" ]),
      ReplaceAfter([
        ["edly", ""],
        ["ingly", ""]
      ])
    ]).get(value);

    if(result == "") {
      return "";
    }

    if(result.endsWith("at") || result.endsWith("bl") || result.endsWith("iz")) {
      result ~= "e";
    }

    auto replaceDouble = ReplaceAfter([
      ["bb", "b"],
      ["dd", "d"],
      ["ff", "f"],
      ["gg", "g"],
      ["mm", "m"],
      ["nn", "n"],
      ["pp", "p"],
      ["rr", "r"],
      ["tt", "t"]
    ]).get(result);

    if(replaceDouble != "") {
      result = replaceDouble;
    }

    if(result.length <= 3) {
      result ~= "e";
    }

    return result;
  }
}

alias EnglishAlphabet = Alphabet!(["a", "e", "i", "o", "u", "y"]);

class EnStemmer {
  static immutable operations = [
    Or([
      [ Invariant(["sky", "news", "howe", "atlas", "cosmos", "bias", "andes"]) ], // exception 1 or
      [
        InlineReplace([ // step 0
          ["'s'", ""],
          ["'s", ""],
          ["'", ""]
        ]),
        Or([[
              ReplaceWord([
                ["skis", "ski"],
                ["skies", "sky"],
                ["dying", "die"],
                ["lying", "lie"],
                ["tying", "tie"],
                ["idly", "idl"],
                ["gently", "gentl"],
                ["ugly", "ugli"],
                ["early", "earli"],
                ["only", "onli"],
                ["singly", "singl"]
              ])
            ],[
              Or([ // step 1a
                InlineReplace([["sses", "ss"]]),
                InlineReplace(EnglishAlphabet.get!"**i"("**ied") ~ EnglishAlphabet.get!"**i"("**ies")),
                ReplacePostfix([["ies", "ie"]]),
                ReplacePostfix(EnglishAlphabet.get!"**"("V*s")),
                ReplacePostfix(EnglishAlphabet.get!"***"("V**s"))
              ]),
              Or([ // step 1b
                ReplaceAfterFromRegion!EnglishAlphabet(1, [
                  ["eed", "ee" ],
                  ["eedly", "ee" ]
                ]),
                EnglishRule1b()
              ]),
              ReplacePostfix(EnglishAlphabet.get!"*i"("Ny"), 2),

              ReplacePostfix([
                ["tional", "tion"],
                ["enci", "ence"],
                ["anci", "ance"],
                ["abli", "able"],
                ["entli", "ent"],
                ["izer", "ize"],
                ["ization", "ize"],
                ["ational", "ate"],
                ["ation", "ate"],
                ["ator", "ate"],
                ["alism", "al"],
                ["aliti", "al"],
                ["alli", "al"],
                ["fulness", "ful"],
                ["ousli", "ous"],
                ["ousness", "ous"],
                ["iveness", "ive"],
                ["iviti", "ive"],
                ["biliti", "ble"]
              ]),
              ReplaceAfter([
                ["bli", "ble"],
                ["logi", "log"],
                ["fulli", "ful"],
                ["lessli", "less"],
                ["cli", ""],
                ["dli", ""],
                ["eli", ""],
                ["gli", ""],
                ["hli", ""],
                ["kli", ""],
                ["mli", ""],
                ["nli", ""],
                ["rli", ""],
                ["tli", ""]
              ]),

              Or([
                ReplacePostfix([
                  ["alize", "al"],
                  ["icate", "ic"],
                  ["iciti", "ic"],
                  ["ical", "ic"],
                  ["ful", ""],
                  ["ness", ""]
                ]),

                ReplaceAfter([
                  ["tional", "tion"],
                  ["ational", "ate"]
                ]),
                ReplaceFromRegion!EnglishAlphabet(2, "ative", ""),
              ]),

              Or([
                RemovePostifixFromRegion!EnglishAlphabet(2, "ement"),
                RemovePostifixFromRegion!EnglishAlphabet(2, "ance"),
                RemovePostifixFromRegion!EnglishAlphabet(2, "ence"),
                RemovePostifixFromRegion!EnglishAlphabet(2, "able"),
                RemovePostifixFromRegion!EnglishAlphabet(2, "ible"),
                RemovePostifixFromRegion!EnglishAlphabet(2, "ment"),
                RemovePostifixFromRegion!EnglishAlphabet(2, "ant"),
                RemovePostifixFromRegion!EnglishAlphabet(2, "ent"),
                RemovePostifixFromRegion!EnglishAlphabet(2, "ism"),
                RemovePostifixFromRegion!EnglishAlphabet(2, "ate"),
                RemovePostifixFromRegion!EnglishAlphabet(2, "iti"),
                RemovePostifixFromRegion!EnglishAlphabet(2, "ous"),
                RemovePostifixFromRegion!EnglishAlphabet(2, "ive"),
                RemovePostifixFromRegion!EnglishAlphabet(2, "ize"),
                RemovePostifixFromRegion!EnglishAlphabet(2, "er"),
                RemovePostifixFromRegion!EnglishAlphabet(2, "ic"),
                RemovePostifixFromRegion!EnglishAlphabet(2, "al"),
              ]),
              ReplaceFromRegion!EnglishAlphabet(1, "e", "")
        ]]),
      ]
    ])
  ];

  string get(const string value) pure {
    auto result = And(operations).get(value);

    if(result == "") {
      return value;
    }

    return result;
  }
}