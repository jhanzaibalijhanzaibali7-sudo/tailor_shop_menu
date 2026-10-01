import 'phonetics.dart';

/// What the user wants to do.
enum VoiceIntent {
  /// Show the saved measurements ("Ahmed ji maap", "Ahmed ka measurement dikhao").
  showMeasurements,

  /// Open the order list ("Jahanzeb jo order kholo").
  openOrders,

  /// Show how much money is still due ("Jahanzeb te ketro paiso baqi aa").
  showBalance,

  /// Only a name was recognised.
  none,
}

class VoiceCustomerRef {
  final int id;
  final String name;
  const VoiceCustomerRef(this.id, this.name);
}

class VoiceMatch {
  final VoiceCustomerRef customer;

  /// 0..1 – how well the spoken words match the saved name.
  final double score;
  const VoiceMatch(this.customer, this.score);
}

class VoiceCommand {
  /// The text that was parsed.
  final String heard;
  final VoiceIntent intent;

  /// Best match first. More than one entry means the name is ambiguous.
  final List<VoiceMatch> matches;

  /// Words that were neither a customer name nor a command word.
  final List<String> leftover;

  const VoiceCommand({
    required this.heard,
    required this.intent,
    required this.matches,
    required this.leftover,
  });

  bool get hasCustomer => matches.isNotEmpty;
  bool get isAmbiguous => matches.length > 1;
  VoiceMatch? get best => matches.isEmpty ? null : matches.first;

  double get _rank =>
      (best?.score ?? 0) * 2 + (intent != VoiceIntent.none ? 1 : 0);
}

class _Group {
  final Set<String> raw;
  final Set<String> sk;

  _Group(List<String> words)
      : raw = words.toSet(),
        sk = _skeletons(words);

  static Set<String> _skeletons(List<String> words) {
    final out = <String>{};
    for (final w in words) {
      final s = Phonetics.skeleton(w);
      if (s.length >= 2) out.add(s);
    }
    return out;
  }

  bool matches(String token, String skel, {bool fuzzy = false}) {
    if (raw.contains(token)) return true;
    if (skel.length >= 2 && sk.contains(skel)) return true;
    if (fuzzy && skel.length >= 5) {
      for (final k in sk) {
        if (k.length >= 5 && Phonetics.editDistance(skel, k) <= 1) return true;
      }
    }
    return false;
  }
}

class _Cand {
  final String text;
  final String skel;
  final int start;
  final int end;
  const _Cand(this.text, this.skel, this.start, this.end);
}

class _Scored {
  final VoiceCustomerRef customer;
  final double score;
  final Set<int> used;
  const _Scored(this.customer, this.score, this.used);
}

/// Understands spoken commands in Roman Sindhi, Sindhi/Urdu script, Hindi
/// (Devanagari) and English – fully offline.
///
/// Works in two steps:
///  1. find the customer: every saved name is compared with the spoken words
///     by sound (see [Phonetics.skeleton]), so "Jahan zeb", "جهانزيب" and
///     "Jehanzaib" all find the customer "Jahanzeb";
///  2. work out the intent from the remaining words ("maap", "order",
///     "baqi", "ketro paiso" ...).
class VoiceCommandParser {
  VoiceCommandParser._();

  // Roman Sindhi / Urdu / Hindi / English spellings. Sindhi-script and
  // Devanagari spellings of the same words are matched automatically through
  // their phonetic skeleton, so only Latin spellings are listed here.
  static final _Group _balanceStrong = _Group([
    'baqi', 'baki', 'baqy', 'baaqi', 'baaki', 'baqee', 'bakee', 'baqaya',
    'bakaya', 'baqiya', 'balance', 'balans', 'remaining', 'remain', 'remains',
    'due', 'outstanding', 'udhar', 'udhaar', 'qarz', 'karz', 'hisab', 'hisaab',
  ]);

  static final _Group _money = _Group([
    'paiso', 'paisa', 'paise', 'paisaa', 'paysa', 'pese', 'rakam', 'raqam',
    'rupiya', 'rupya', 'rupia', 'rupee', 'rupees', 'amount', 'cash', 'payment',
  ]);

  static final _Group _measure = _Group([
    'map', 'maap', 'maapi', 'maape', 'mapi', 'mape', 'maapo', 'maapon', 'naap',
    'nap', 'measurement', 'measurements', 'measure', 'measures', 'size',
    'sizes',
  ]);

  static final _Group _order = _Group([
    'order', 'orders', 'ordar', 'ordars', 'ordr', 'aardar', 'aarder', 'arder',
    'ardar', 'kam', 'kaam',
  ]);

  // Verbs, question words and polite filler: ignored.
  static final _Group _filler = _Group([
    'kholo', 'khol', 'kholyo', 'kholiyo', 'kholjo', 'kholi', 'kholiye',
    'kholen', 'dikha', 'dikhao', 'dikhayo', 'dikhaiyo', 'dikhai', 'dikhaa',
    'dikhaye', 'dikhar', 'dikhario', 'dikhariyo', 'dekhao', 'dekho', 'dekh',
    'dekhar', 'show', 'open', 'view', 'see', 'check', 'batao', 'bata',
    'batayo', 'bataiyo', 'tell', 'kar', 'karo', 'kari', 'kare', 'kariyo',
    'karyo', 'please', 'plz', 'pls', 'ketro', 'ketra', 'ketri', 'kitna',
    'kitni', 'kitno', 'kita', 'how', 'much', 'kya', 'mujhe', 'muje', 'mukhe',
    'muhinje', 'hai', 'hain', 'ahe', 'aahe', 'aahi', 'ahi', 'aa', 'he',
  ]);

  // Particles such as ka/ki/ke/ko/khe (of/to), ji/jo/je/ja (of), te/ta (on),
  // plus bare "is" words (aa, hai) and do/de: they all reduce to one of these
  // single-letter skeletons and are very short.
  static const Set<String> _tiny = {'k', 'j', 't', 'a', 'h', 'd'};

  static bool _isTiny(String token, String skel) =>
      token.runes.length <= 4 && _tiny.contains(skel);

  static final RegExp _stripMarks =
      RegExp('[\u064B-\u065F\u0670\u06D6-\u06ED\u0640\u200C-\u200F]');
  static final RegExp _separators = RegExp(r'[^\p{L}\p{M}]+', unicode: true);
  static final RegExp _latinOnly = RegExp(r'^[a-z]+$');

  static List<String> tokens(String text) {
    final cleaned = text.toLowerCase().replaceAll(_stripMarks, '');
    return cleaned
        .split(_separators)
        .where((t) => t.isNotEmpty)
        .toList();
  }

  static double _similarity(String u, String su, String n, String sn) {
    if (u == n) return 1.0;
    if (su.length >= 2 && su == sn) return 0.9;
    if (su.length >= 4 &&
        sn.length >= 4 &&
        Phonetics.editDistance(su, sn) <= 1) {
      return 0.7;
    }
    if (u.length >= 5 &&
        _latinOnly.hasMatch(u) &&
        _latinOnly.hasMatch(n) &&
        Phonetics.editDistance(u, n) <= (u.length ~/ 5 < 1 ? 1 : u.length ~/ 5)) {
      return 0.75;
    }
    return 0.0;
  }

  /// Parses one transcript.
  static VoiceCommand parse(String text, List<VoiceCustomerRef> customers) {
    final toks = tokens(text);
    final sks = [for (final t in toks) Phonetics.skeleton(t)];

    // Candidates: every word, plus every pair of neighbouring words joined
    // ("jahan" + "zeb" -> "jahanzeb").
    final cands = <_Cand>[];
    for (var i = 0; i < toks.length; i++) {
      cands.add(_Cand(toks[i], sks[i], i, i));
      if (i + 1 < toks.length) {
        final joined = toks[i] + toks[i + 1];
        cands.add(_Cand(joined, Phonetics.skeleton(joined), i, i + 1));
      }
    }

    final scored = <_Scored>[];
    for (final c in customers) {
      final nameToks = tokens(c.name);
      if (nameToks.isEmpty) continue;
      final used = <int>{};
      var total = 0.0;
      var weight = 0.0;
      for (final nt in nameToks) {
        final nsk = Phonetics.skeleton(nt);
        if (nsk.isEmpty) continue;
        final w = nsk.length;
        var best = 0.0;
        _Cand? bestCand;
        for (final cand in cands) {
          if (used.contains(cand.start) || used.contains(cand.end)) continue;
          if (cand.start == cand.end &&
              _isTiny(cand.text, cand.skel) &&
              nt != cand.text) {
            continue;
          }
          final v = _similarity(cand.text, cand.skel, nt, nsk);
          if (v > best) {
            best = v;
            bestCand = cand;
          }
        }
        weight += w;
        if (bestCand != null) {
          total += best * w;
          used.add(bestCand.start);
          used.add(bestCand.end);
        }
      }
      if (weight == 0) continue;
      final score = total / weight;
      if (score >= 0.5) scored.add(_Scored(c, score, used));
    }

    scored.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      return a.customer.name.length.compareTo(b.customer.name.length);
    });

    var matches = <VoiceMatch>[];
    var consumed = <int>{};
    if (scored.isNotEmpty) {
      final top = scored.first.score;
      matches = scored
          .where((s) => s.score >= top - 0.001)
          .take(5)
          .map((s) => VoiceMatch(s.customer, s.score))
          .toList();
      consumed = scored.first.used;
    }

    // Words not used by the customer name decide the intent.
    final restTokens = <String>[];
    final restSkels = <String>[];
    for (var i = 0; i < toks.length; i++) {
      if (!consumed.contains(i)) {
        restTokens.add(toks[i]);
        restSkels.add(sks[i]);
      }
    }

    bool has(_Group g, {bool fuzzy = false}) {
      for (var i = 0; i < restTokens.length; i++) {
        if (g.matches(restTokens[i], restSkels[i], fuzzy: fuzzy)) return true;
      }
      return false;
    }

    VoiceIntent intent;
    if (has(_balanceStrong)) {
      intent = VoiceIntent.showBalance;
    } else if (has(_measure, fuzzy: true)) {
      intent = VoiceIntent.showMeasurements;
    } else if (has(_order)) {
      intent = VoiceIntent.openOrders;
    } else if (has(_money)) {
      intent = VoiceIntent.showBalance;
    } else {
      intent = VoiceIntent.none;
    }

    final leftover = <String>[];
    for (var i = 0; i < restTokens.length; i++) {
      final t = restTokens[i];
      final s = restSkels[i];
      final isNoise = _isTiny(t, s) ||
          _filler.matches(t, s) ||
          _balanceStrong.matches(t, s) ||
          _money.matches(t, s) ||
          _measure.matches(t, s, fuzzy: true) ||
          _order.matches(t, s);
      if (!isNoise) leftover.add(t);
    }

    return VoiceCommand(
      heard: text,
      intent: intent,
      matches: matches,
      leftover: leftover,
    );
  }

  /// Speech engines return several alternative transcripts. Parse all of them
  /// and keep the one that found a customer and an intent.
  static VoiceCommand parseBest(
      List<String> transcripts, List<VoiceCustomerRef> customers) {
    VoiceCommand? best;
    var bestRank = -1.0;
    for (final t in transcripts) {
      if (t.trim().isEmpty) continue;
      final cmd = parse(t, customers);
      if (cmd._rank > bestRank) {
        best = cmd;
        bestRank = cmd._rank;
      }
    }
    return best ??
        VoiceCommand(
          heard: transcripts.isEmpty ? '' : transcripts.first,
          intent: VoiceIntent.none,
          matches: const [],
          leftover: const [],
        );
  }
}
