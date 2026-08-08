import 'dart:typed_data';

import 'package:flutter_local_ai/flutter_local_ai.dart';

import '../text_intelligence.dart';
import 'deterministic_intelligence.dart';

/// Semantic understanding via the OS's own on-device model.
///
/// Apple Foundation Models on iOS 26+, Gemini Nano through ML Kit GenAI on
/// Android. Nothing to download, nothing to pay for, and no data leaves the
/// device — the zero-egress property holds by construction.
///
/// **Availability is the catch.** Gemini Nano runs on recent flagships only
/// (Pixel 9/10, Galaxy S25/S26, and top-tier OnePlus/OPPO/Xiaomi/vivo), and
/// Apple's needs an iPhone new enough for iOS 26. Most phones in the target
/// market have neither. Every method therefore falls through to
/// [DeterministicIntelligence] rather than failing, and [isAvailable] reports
/// the truth so the UI can say what is degraded.
///
/// **No embeddings.** Neither platform exposes a text embedding API, so
/// [embed] is unavailable here too. Semantic retrieval is achieved instead by
/// having the model expand queries and enrich stored profiles, with FTS5 doing
/// the matching — see [normalizeQuery].
class PlatformIntelligence implements TextIntelligence {
  PlatformIntelligence({TextIntelligence? fallback})
      : _fallback = fallback ?? const DeterministicIntelligence();

  final TextIntelligence _fallback;
  final FlutterLocalAi _ai = FlutterLocalAi();

  bool? _available;
  bool _initialized = false;

  @override
  String get id => 'platform-ai';

  @override
  Future<bool> isAvailable() async {
    if (_available != null) return _available!;
    try {
      _available = await _ai.isAvailable();
    } on Object {
      _available = false;
    }
    return _available!;
  }

  /// Always false. No on-device platform API offers embeddings today.
  @override
  Future<bool> isEmbeddingAvailable() async => false;

  /// Explains why the model is unusable, for the settings screen.
  Future<String?> unavailableReason() async {
    if (await isAvailable()) return null;
    try {
      return await _ai.availabilityReason();
    } on Object {
      return 'On-device AI is not supported on this device.';
    }
  }

  Future<bool> _ready() async {
    if (!await isAvailable()) return false;
    if (_initialized) return true;
    try {
      await _ai.initialize(
        instructions: 'You help organise business cards. Answer with the exact '
            'format requested and nothing else. Never invent details that are '
            'not present in the input.',
      );
      _initialized = true;
    } on Object {
      _available = false;
      return false;
    }
    return _initialized;
  }

  /// One short generation, or null if anything goes wrong.
  ///
  /// Returning null rather than throwing is deliberate: every caller has a
  /// working fallback, and a scan must never fail because a model was busy.
  Future<String?> _ask(String prompt) async {
    if (!await _ready()) return null;
    try {
      final String out =
          await _ai.generateTextSimple(prompt: prompt, maxTokens: 220);
      final String trimmed = out.trim();
      return trimmed.isEmpty ? null : trimmed;
    } on Object {
      return null;
    }
  }

  @override
  Future<String?> classify(String text, List<String> labels) async {
    // Line-oriented, single-token answers — not JSON. Android's Gemini Nano
    // has no structured-output mode at all, and small models are far more
    // reliable at "reply with one word" than at emitting a schema.
    final String? answer = await _ask(
      'Pick the single best category for this business card.\n'
      'Reply with exactly one of these words and nothing else:\n'
      '${labels.join(", ")}\n\n'
      'Card:\n$text',
    );
    if (answer == null) return _fallback.classify(text, labels);

    final String cleaned = answer.toLowerCase().split(RegExp(r'[\s,.\n]')).first;
    // Trust it only if it actually answered from the list. Models improvise.
    return labels.contains(cleaned)
        ? cleaned
        : await _fallback.classify(text, labels);
  }

  @override
  Future<List<Attr>> extractAttributes(String note) async {
    final String? answer = await _ask(
      'Read this note about a business and list only the facts it states.\n'
      'Use exactly this format, one per line, nothing else:\n'
      'key: value\n\n'
      'Allowed keys: price_tier, min_order, delivery_reliability, quality, '
      'service, location\n'
      'If the note does not state something, leave that key out.\n\n'
      'Note: $note',
    );
    if (answer == null) return _fallback.extractAttributes(note);

    const Set<String> allowed = <String>{
      'price_tier', 'min_order', 'delivery_reliability', 'quality',
      'service', 'location',
    };

    final List<Attr> parsed = <Attr>[];
    for (final String line in answer.split('\n')) {
      final int colon = line.indexOf(':');
      if (colon <= 0) continue;

      final String key = line.substring(0, colon).trim().toLowerCase();
      final String value = line.substring(colon + 1).trim();
      if (!allowed.contains(key) || value.isEmpty) continue;

      parsed.add(Attr(key: key, value: value, confidence: 0.8));
    }
    // An empty parse usually means the model ignored the format. The keyword
    // pass is worse but predictable, so it is a better answer than nothing.
    return parsed.isEmpty ? await _fallback.extractAttributes(note) : parsed;
  }

  /// Writes the searchable description of what a card can do for you.
  ///
  /// This is where retrieval quality is actually won. With no embeddings, the
  /// index is FTS5 — so the model's job is to widen the vocabulary a card can
  /// be found by, turning "Sonar Bangla Press" plus "did our fest shirts
  /// cheaply" into text that also contains *t-shirt printing*, *custom
  /// apparel*, *small orders*. Classic document expansion: pay the cost once at
  /// save time, and every later keyword search benefits.
  @override
  Future<CapabilityProfile?> buildProfile({
    required String cardText,
    String? userNote,
  }) async {
    final String combined =
        <String>[cardText, ?userNote].join('\n').trim();
    if (combined.isEmpty) return null;

    final String? answer = await _ask(
      'Describe what this business offers, for a search index.\n'
      'Write one short sentence, then a line starting "keywords:" listing '
      'the words someone might search to find it, comma separated.\n'
      'Only use information given below. Do not invent services.\n\n'
      '$combined',
    );
    if (answer == null) {
      return _fallback.buildProfile(cardText: cardText, userNote: userNote);
    }

    final List<String> services = <String>[];
    final StringBuffer prose = StringBuffer();
    for (final String line in answer.split('\n')) {
      final String trimmed = line.trim();
      if (trimmed.toLowerCase().startsWith('keywords:')) {
        services.addAll(
          trimmed
              .substring(9)
              .split(',')
              .map((String s) => s.trim().toLowerCase())
              .where((String s) => s.isNotEmpty),
        );
      } else if (trimmed.isNotEmpty) {
        prose.writeln(trimmed);
      }
    }

    final String? category =
        await classify(combined, DeterministicIntelligence.categories);

    return CapabilityProfile(
      // The original text is kept alongside the expansion. The model widens
      // what a card matches; it must never replace what the card actually says.
      canonicalEnglish: '${prose.toString().trim()}\n$combined'.trim(),
      services: services,
      categories: <String>[?category],
      model: id,
    );
  }

  /// Expands a query into the words a matching card might carry.
  ///
  /// The mirror of [buildProfile]: with no vectors, "who prints shirts cheaply"
  /// only finds a card if some shared word exists. So the model supplies
  /// synonyms — *printing*, *press*, *custom apparel* — and FTS5 does the rest.
  @override
  Future<QueryIntent> normalizeQuery(String raw) async {
    final String? answer = await _ask(
      'A user is searching their saved business cards.\n'
      'Rewrite their request as search keywords: the words a matching card or '
      'note would contain. Include obvious synonyms.\n'
      'Reply with one line of comma-separated keywords and nothing else.\n\n'
      'Request: $raw',
    );
    if (answer == null) return QueryIntent.passthrough(raw);

    final List<String> keywords = answer
        .split(RegExp(r'[,\n]'))
        .map((String s) => s.trim())
        .where((String s) => s.isNotEmpty && s.length < 40)
        .toList();

    if (keywords.isEmpty) return QueryIntent.passthrough(raw);

    return QueryIntent(
      raw: raw,
      // The user's own words stay first. Expansion widens the net; it must not
      // outweigh what they actually typed.
      englishGloss: <String>[raw, ...keywords].join(' '),
    );
  }

  @override
  Future<Float32List> embed(String text, {required EmbedKind kind}) async {
    throw const IntelligenceUnavailable(
      'Neither Apple Foundation Models nor Gemini Nano exposes embeddings. '
      'Retrieval uses query expansion over FTS5 instead.',
    );
  }

  @override
  Future<String?> draftMessage({
    required String request,
    required String recipientContext,
  }) async {
    return _ask(
      'Write a short, polite WhatsApp enquiry. Plain text, no preamble, '
      'no placeholders to fill in.\n\n'
      'What is needed: $request\n'
      'Who it is going to: $recipientContext',
    );
  }

  @override
  Future<void> dispose() async {
    _initialized = false;
    await _fallback.dispose();
  }
}
