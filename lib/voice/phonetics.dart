/// Cross-script phonetic helpers used by the voice command parser.
///
/// Speech engines return the same spoken name in different scripts depending
/// on the recognition language: "Jahanzeb" (Latin), "جهانزيب" (Sindhi/Urdu) or
/// "जहांज़ेब" (Devanagari). [skeleton] reduces all of them to the same short
/// consonant key ("jnsb") so a spoken name can be matched with the name saved
/// in the customer list, whatever script either side uses.
class Phonetics {
  Phonetics._();

  static final Map<String, String> _letters = _buildLetters();

  static Map<String, String> _buildLetters() {
    final m = <String, String>{};
    void add(String chars, String value) {
      for (final rune in chars.runes) {
        m[String.fromCharCode(rune)] = value;
      }
    }

    // Sindhi / Urdu / Arabic script. Vowel letters map to 'a', semi-vowels to
    // 'w' / 'y' (all treated as vowels later). 'C' stands for "ch".
    add('اآأإءئؤعٱ', 'a');
    add('بٻڀ', 'b');
    add('پ', 'p');
    add('ڦف', 'f');
    add('تٽٿٺٹثط', 't');
    add('جڄ', 'j');
    add('ڃڱںنڻ', 'n');
    add('چڇ', 'C');
    add('حهھہۃةە', 'h');
    add('خ', 'k');
    add('دڏڌڊڈڍذ', 'd');
    add('رڙڑ', 'r');
    add('زژسشصضظ', 's');
    add('غڳگ', 'g');
    add('ڪكکق', 'k');
    add('ل', 'l');
    add('م', 'm');
    add('وۆۇ', 'w');
    add('یيىېێےۓ', 'y');

    // Devanagari (Hindi speech recognition).
    add('अआइईउऊएऐओऔऑ', 'a');
    add('कख', 'k');
    add('गघ', 'g');
    add('ङञणन', 'n');
    add('चछ', 'C');
    add('जझ', 'j');
    add('टठतथ', 't');
    add('डढदध', 'd');
    add('पफ', 'p');
    add('बभ', 'b');
    add('म', 'm');
    add('य', 'y');
    add('र', 'r');
    add('ल', 'l');
    add('व', 'w');
    add('शषस', 's');
    add('ह', 'h');
    add('ािीुूेैोौॉ', 'a'); // vowel signs
    add('ंँ', 'n'); // nasal signs
    add('\u093C\u094D\u0903\u093D', ''); // nukta, virama, visarga, avagraha
    return m;
  }

  // Devanagari letters with a nukta, in composed and decomposed form.
  static const List<List<String>> _nukta = [
    ['\u095B', 'z'], ['\u091C\u093C', 'z'],
    ['\u0958', 'k'], ['\u0915\u093C', 'k'],
    ['\u0959', 'k'], ['\u0916\u093C', 'k'],
    ['\u095A', 'g'], ['\u0917\u093C', 'g'],
    ['\u095E', 'f'], ['\u092B\u093C', 'f'],
    ['\u095C', 'r'], ['\u0921\u093C', 'r'],
    ['\u095D', 'r'], ['\u0922\u093C', 'r'],
  ];

  // Arabic harakat, tatweel and zero-width marks carry no information.
  static bool _ignored(int r) =>
      (r >= 0x064B && r <= 0x065F) ||
      r == 0x0670 ||
      (r >= 0x06D6 && r <= 0x06ED) ||
      r == 0x0640 ||
      (r >= 0x200C && r <= 0x200F);

  /// Latin-letter approximation of [input] (any supported script).
  static String translit(String input) {
    var s = input.toLowerCase();
    for (final pair in _nukta) {
      s = s.replaceAll(pair[0], pair[1]);
    }
    final out = StringBuffer();
    for (final rune in s.runes) {
      if (_ignored(rune)) continue;
      final ch = String.fromCharCode(rune);
      final mapped = _letters[ch];
      if (mapped != null) {
        out.write(mapped);
      } else if (rune >= 0x61 && rune <= 0x7A) {
        out.write(ch);
      }
      // digits, spaces, punctuation: dropped
    }
    return out.toString();
  }

  static const List<List<String>> _digraphs = [
    ['ch', 'C'], ['sh', 's'], ['kh', 'k'], ['gh', 'g'], ['th', 't'],
    ['dh', 'd'], ['ph', 'f'], ['zh', 's'], ['bh', 'b'], ['jh', 'j'],
    ['ck', 'k'],
  ];

  /// Consonant skeleton: "Jahanzeb" / "جهانزيب" / "जहांज़ेब" -> "jnsb",
  /// "Ahmed" / "احمد" -> "amd". A leading vowel is kept as 'a', a leading 'h'
  /// is kept, all other vowels and 'h' are dropped, similar letters are folded
  /// (z/s, q/k, c/k ...) and repeated letters collapse.
  static String skeleton(String input) {
    var t = translit(input);
    for (final d in _digraphs) {
      t = t.replaceAll(d[0], d[1]);
    }
    t = t
        .replaceAll('q', 'k')
        .replaceAll('x', 'ks')
        .replaceAll('z', 's')
        .replaceAll('c', 'k')
        .replaceAll('C', 'c');

    final chars = <String>[];
    for (final ch in t.split('')) {
      if ('aeiouyw'.contains(ch)) {
        if (chars.isEmpty) chars.add('a');
      } else if (ch == 'h') {
        if (chars.isEmpty) chars.add('h');
      } else {
        chars.add(ch);
      }
    }
    final res = StringBuffer();
    String? prev;
    for (final ch in chars) {
      if (ch != prev) res.write(ch);
      prev = ch;
    }
    return res.toString();
  }

  /// Levenshtein edit distance.
  static int editDistance(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;
    var prev = List<int>.generate(b.length + 1, (i) => i);
    for (var i = 1; i <= a.length; i++) {
      final cur = List<int>.filled(b.length + 1, 0);
      cur[0] = i;
      for (var j = 1; j <= b.length; j++) {
        final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
        var best = prev[j] + 1;
        if (cur[j - 1] + 1 < best) best = cur[j - 1] + 1;
        if (prev[j - 1] + cost < best) best = prev[j - 1] + cost;
        cur[j] = best;
      }
      prev = cur;
    }
    return prev[b.length];
  }
}
