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

  static immutable(IStemOperation) opCall(immutable(string) from, immutable(string) to) pure {
    return new immutable InlineReplace([[from, to]]);
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
  string[] list;

  this(size_t region, immutable string[] list) pure {
    super(region);

    this.list = list;
  }

  static immutable(IStemOperation) opCall(size_t region, immutable string postfix) pure {
    return new immutable RemovePostifixFromRegion!T(region, [ postfix ]);
  }

  static immutable(IStemOperation) opCall(size_t region, immutable string[] list) pure {
    return new immutable RemovePostifixFromRegion!T(region, list);
  }

  string get(const string value) pure {
    string strRegion = getRegion(value);

    foreach(postfix; list) {
      if(strRegion.endsWith(postfix)) {
        return value[0..$ - postfix.length];
      }

      if(value.endsWith(postfix)) {
        return "";
      }
    }

    return "";
  }
}

immutable class ReplacePostifixFromRegion(T) : StemOperationFromRegion!T {
  immutable {
    string[][] list;
  }

  this(size_t region, immutable(string[][]) list) pure {
    super(region);

    this.list = list;
  }

  static immutable(IStemOperation) opCall(size_t region, immutable string from, immutable string to) pure {
    return new immutable ReplacePostifixFromRegion!T(region, [[ from, to ]]);
  }

  static immutable(IStemOperation) opCall(size_t region, string[][] list) pure {
    return new immutable ReplacePostifixFromRegion!T(region, list.map!(a => a.idup).array.idup);
  }

  string get(const string value) pure {
    string strRegion = getRegion(value);

    foreach(item; list) {
      if(strRegion.endsWith(item[0])) {
        return value[0..$ - strRegion.length] ~ strRegion.replaceLast(item[0], item[1]);
      }

      if(value.endsWith(item[0])) {
        return "";
      }
    }

    return "";
  }
}

immutable class ReplaceFromRegion(T) : StemOperationFromRegion!T {
  immutable {
    string[][] list;
  }

  this(size_t region, immutable(string[][]) list) pure {
    super(region);

    this.list = list;
  }

  static immutable(IStemOperation) opCall(size_t region, immutable string from, immutable string to) pure {
    return new immutable ReplaceFromRegion!T(region, [[ from, to ]]);
  }

  static immutable(IStemOperation) opCall(size_t region, string[][] list) pure {
    return new immutable ReplaceFromRegion!T(region, list.map!(a => a.idup).array.idup);
  }

  string get(const string value) pure {
    string strRegion = getRegion(value);

    foreach(item; list) {
      if(strRegion.canFind(item[0])) {
        return value[0..$ - strRegion.length] ~ strRegion.replaceLast(item[0], item[1]);
      }
    }

    return "";
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

    bool isVowel(dchar ch) {
      return vowels.map!"a[0]".canFind(ch);
    }

    bool isShortWord(string data) pure {
      return EnglishAlphabet.endsWithShortSylable(data) && EnglishAlphabet.region1(data) == "";
    }

    bool endsWithShortSylable(string data) pure {
      if(data.length < 2) {
        return true;
      }

      auto result = data.map!(a => isVowel(a)).array;

      if(result == [true, false]) {
        return true;
      }

      if(result == [false, true] && data[1] == 'i') {
        return true;
      }

      if(data.length == 2) {
        return false;
      }

      auto lastChar = data[data.length - 1];
      auto vowelsXWY = vowels.join ~ "wxY";

      if(result.endsWith([false, true, false]) && vowelsXWY.indexOf(lastChar) == -1) {
        return true;
      }

      return false;
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

    immutable(string[2][]) get(string replace)(const string value) pure {
      return get(value)
        .map!(a => cast(string[2])[a, change(replace, a)])
          .array;
    }

    alias region1 = region!true;

    string region(bool useExceptions)(string word) pure {
      if(word.length < 2) {
        return "";
      }

      static if(useExceptions) {
        static foreach(prefix; [ "gener", "commun", "arsen"]) {
          if(word.startsWith(prefix)) {
            return word[prefix.length .. $];
          }
        }
      }

      foreach(i; 0..word.length - 1) {
        if(vowels.map!"a[0]".canFind(word[i]) && nonVowels.map!"a[0]".canFind(word[i+1])) {
          return word[i+2..$];
        }
      }

      return "";
    }

    string region2(string word) pure {
      return region!false(region1(word));
    }
}

immutable class EnglishRule1b : IStemOperation {
  static immutable(IStemOperation) opCall() pure {
    return new immutable EnglishRule1b();
  }

  string get(const string value) pure {
    if(value.endsWith("eed") || value.endsWith("eedly")) {
      auto r1 = EnglishAlphabet.region1(value);

      if(r1.endsWith("eed")){
        return value[0..$-1];
      }

      if(r1.endsWith("eedli")){
        return value[0..$-3];
      }

      return "";
    }

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

    if(!result.map!(a => EnglishAlphabet.isVowel(a)).canFind(true)) {
      return "";
    }

    if(result.endsWith("at") || result.endsWith("bl") || result.endsWith("iz")) {
      return result ~ "e";
    }

    auto replaceDouble = ReplacePostfix([
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
      return replaceDouble;
    }

    if(EnglishAlphabet.isShortWord(result)) {
      result ~= "e";
    }

    return result;
  }
}

immutable class EnglishIonPostfix : IStemOperation {
  static immutable(IStemOperation) opCall() pure {
    return new immutable EnglishIonPostfix();
  }

  string get(const string value) pure {
    auto r2 = EnglishAlphabet.region2(value);

    if(!r2.endsWith("ion")) {
      return "";
    }

    if(value.endsWith("tion") || value.endsWith("sion")) {
      return value[0..$-3];
    }

    return "";
  }
}

immutable class EnglishRule5 : IStemOperation {
  static immutable(IStemOperation) opCall() pure {
    return new immutable EnglishRule5();
  }

  string get(const string value) pure {
    auto r1 = EnglishAlphabet.region1(value);
    auto r2 = EnglishAlphabet.region1(r1);

    if(r2.endsWith('l') && value.endsWith("ll")) {
      return value[0..$-1];
    }

    if(r2.endsWith('e')) {
      return value[0..$-1];
    }

    if(r1.endsWith('e')) {
      string beforeE = value[0..value.lastIndexOf('e')];

      if(!EnglishAlphabet.endsWithShortSylable(beforeE)) {
        return value[0..$-1];
      }
    }

    return "";
  }
}

immutable class ReplaceEnglishLiEnding : IStemOperation {
  static immutable(IStemOperation) opCall() pure {
    return new immutable ReplaceEnglishLiEnding();
  }

  string get(const string value) pure {
    if(value.length <= 2) {
      return "";
    }

    if(value.endsWith("ousli") ||
       value.endsWith("abli") ||
       value.endsWith("lessli") ||
       value.endsWith("alli") ||
       value.endsWith("fulli") ||
       value.endsWith("bli") ||
       value.endsWith("entli") ) {
         return "";
    }

    auto r1 = EnglishAlphabet.region1(value);

    if(!r1.endsWith("li")) {
      return "";
    }

    if("cdeghkmnrt".indexOf(value[value.length - 3]) == -1) {
      return "";
    }

    return value[0..$-2];
  }
}

immutable class RemoveEnglishPlural : IStemOperation {
  static immutable(IStemOperation) opCall() pure {
    return new immutable RemoveEnglishPlural();
  }

  string get(const string value) pure {
    if(value.length <= 2) {
      return "";
    }

    if(!value.endsWith('s')) {
      return "";
    }

    if(value.endsWith("ss")) {
      return "";
    }

    if(value.endsWith("us")) {
      return "";
    }

    auto format = value.map!(a => EnglishAlphabet.isVowel(a)).array;

    if(format[0..$-2].canFind(true)) {
      return value[0..$-1];
    }

    return "";
  }
}

alias EnglishAlphabet = Alphabet!(["a", "e", "i", "o", "u", "y"], [ "Y" ]);

class EnStemmer {
  static immutable operations = [
    Or([
      [ Invariant(["sky", "news", "howe", "atlas", "cosmos", "bias", "andes"]) ], // exception 1 or
      [
        InlineReplace(EnglishAlphabet.get!"*Y"("Vy")),
        InlineReplace([ // step 0
          ["'s'", "s"],
          ["'s", ""],
          ["'''", "'"],
          ["''", "'"],
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
                ReplacePostfix([["sses", "ss"]]),
                ReplacePostfix(EnglishAlphabet.get!"**i"("**ied") ~ EnglishAlphabet.get!"**i"("**ies")),
                ReplacePostfix([["ies", "ie"]]),
                RemoveEnglishPlural()
              ]),
              Or([[
                Invariant([ "inning", "outing", "canning", "herring", "earring", "proceed", "exceed", "succeed"])
              ], [
                EnglishRule1b(),
                ReplacePostfix(EnglishAlphabet.get!"*i"("Ny"), 2), // step 1c

                Or([ // Step 2
                  ReplacePostifixFromRegion!EnglishAlphabet(1, [
                    ["ization", "ize"],
                    ["ational", "ate"],
                    ["fulness", "ful"],
                    ["ousness", "ous"],
                    ["iveness", "ive"],
                    ["tional", "tion"],
                    ["lessli", "less"],
                    ["biliti", "ble"],
                    ["iviti", "ive"],
                    ["ousli", "ous"],
                    ["entli", "ent"],
                    ["ation", "ate"],
                    ["fulli", "ful"],
                    ["aliti", "al"],
                    ["alism", "al"],
                    ["enci", "ence"],
                    ["anci", "ance"],
                    ["abli", "able"],
                    ["izer", "ize"],
                    ["ator", "ate"],
                    ["alli", "al"],
                    ["ogi", "og"],
                    ["logi", "log"],
                    ["bli", "ble"]
                  ]),
                  ReplaceEnglishLiEnding()
                ]),

                Or([// Step 3
                  ReplacePostifixFromRegion!EnglishAlphabet(1, [
                    ["ational", "ate"],
                    ["tional", "tion"],
                    ["alize", "al"],
                    ["icate", "ic"],
                    ["iciti", "ic"],
                    ["ical", "ic"],
                    ["ness", ""],
                    ["ful", ""],
                  ]),
                  ReplacePostifixFromRegion!EnglishAlphabet(2, "ative", "")
                ]),

                Or([ // Step 4
                  RemovePostifixFromRegion!EnglishAlphabet(2,
                    ["ement",
                    "ance", "ence", "able", "ible", "ment",
                    "ant" , "ent", "ism", "ate", "iti", "ous", "ive", "ize",
                    "er", "ic", "al"]),
                  EnglishIonPostfix()
                ]),
                EnglishRule5(),
                InlineReplace([["Y", "y"]]),
              ]])
        ]]),
      ]
    ])
  ];

  string get(const string value) pure {
    if(value.length < 3) {
      return value;
    }

    string tmpValue;
    if(value[0] == 'y') {
      tmpValue = "Y" ~ value[1..$];
    } else {
      tmpValue = value;
    }

    auto result = And(operations).get(tmpValue);

    if(result == "") {
      return value;
    }

    return result;
  }
}