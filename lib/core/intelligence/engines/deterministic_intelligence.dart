import 'dart:typed_data';

import '../text_intelligence.dart';

/// Semantic understanding with no model at all.
///
/// This is not a stub. Platform on-device AI — Apple Foundation Models, Gemini
/// Nano — is confined to recent flagships: Pixel 9/10, Galaxy S25/S26, iPhones
/// new enough for iOS 26. On the mid-range Android phones that dominate the
/// target market, **this is the implementation that will actually run**, so it
/// has to produce a usable app on its own rather than degrade to nothing.
///
/// What it gives up is inference. What it keeps is everything the user typed:
/// notes, tags and printed text all remain searchable through FTS5, which is
/// the half of retrieval that never needed a model.
class DeterministicIntelligence implements TextIntelligence {
  const DeterministicIntelligence();

  @override
  String get id => 'deterministic';

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<bool> isEmbeddingAvailable() async => false;

  /// Keyword cues for the built-in categories.
  ///
  /// Crude next to a language model, and deliberately so — a wrong category is
  /// worse than none, because it silently distorts ranking. Anything that does
  /// not match confidently returns null.
  static const Map<String, List<String>> _categoryCues = <String, List<String>>{
    'printing': <String>[
      'print', 'printing', 'press', 'banner', 'flex', 'signage', 't-shirt',
      'tshirt', 'screen print', 'offset', 'digital print',
    ],
    'books': <String>['book', 'books', 'library', 'stationery', 'publisher'],
    'food': <String>[
      'restaurant', 'cafe', 'catering', 'bakery', 'sweets', 'biryani', 'food',
    ],
    'electronics': <String>[
      'electronics', 'computer', 'laptop', 'mobile', 'repair', 'hardware',
    ],
    'clothing': <String>[
      'apparel', 'garment', 'fashion', 'tailor', 'boutique', 'hoodie',
      'shirt', 'wholesale clothing', 'paikari',
    ],
    'events': <String>[
      'event', 'decor', 'decoration', 'wedding', 'sound', 'lighting', 'led',
      'stage', 'photography',
    ],
    'medical': <String>[
      'doctor', 'clinic', 'hospital', 'pharmacy', 'medical', 'dental',
      'diagnostic',
    ],
    'construction': <String>[
      'construction', 'engineer', 'contractor', 'interior', 'architect',
      'furniture', 'electrician', 'plumber',
    ],
    'transport': <String>[
      'transport', 'courier', 'logistics', 'delivery', 'cargo', 'rent a car',
    ],
  };

  /// The built-in category vocabulary, shared with the platform engine so both
  /// classify into the same space.
  static List<String> get categories => _categoryCues.keys.toList();

  @override
  Future<String?> classify(String text, List<String> labels) async {
    final String lower = text.toLowerCase();

    String? best;
    int bestHits = 0;
    for (final String label in labels) {
      final List<String> cues = _categoryCues[label] ?? <String>[label];
      final int hits =
          cues.where((String cue) => lower.contains(cue)).length;
      if (hits > bestHits) {
        bestHits = hits;
        best = label;
      }
    }
    return best;
  }

  /// Phrases that reliably signal an attribute, mapped to the value they imply.
  ///
  /// Only high-precision cues. Guessing that "quality" means good quality would
  /// invent facts the user never stated.
  static const Map<String, Map<String, List<String>>> _attributeCues =
      <String, Map<String, List<String>>>{
    'price_tier': <String, List<String>>{
      'cheap': <String>['cheap', 'affordable', 'low price', 'reasonable',
          'budget', 'komdame', 'kom dame'],
      'expensive': <String>['expensive', 'costly', 'premium', 'pricey'],
    },
    'min_order': <String, List<String>>{
      'low': <String>['low quantity', 'small order', 'kom quantity',
          'minimum order', 'small quantity', 'few pieces'],
      'wholesale': <String>['wholesale', 'paikari', 'bulk'],
    },
    'delivery_reliability': <String, List<String>>{
      'late': <String>['late', 'delayed', 'slow delivery', 'deri'],
      'fast': <String>['fast', 'quick', 'on time', 'same day'],
    },
    'quality': <String, List<String>>{
      'good': <String>['good quality', 'quality good', 'excellent', 'great'],
      'poor': <String>['poor quality', 'bad quality', 'low quality'],
    },
  };

  @override
  Future<List<Attr>> extractAttributes(String note) async {
    final String lower = note.toLowerCase();
    final List<Attr> found = <Attr>[];

    for (final MapEntry<String, Map<String, List<String>>> attr
        in _attributeCues.entries) {
      for (final MapEntry<String, List<String>> value in attr.value.entries) {
        if (value.value.any(lower.contains)) {
          found.add(Attr(
            key: attr.key,
            value: value.key,
            // Modest by construction: a keyword hit is weaker evidence than a
            // model reading the sentence, and the score should say so.
            confidence: 0.6,
          ));
          break;
        }
      }
    }
    return found;
  }

  /// Builds a profile out of what is already written, without inventing
  /// anything.
  ///
  /// The note carries the user's own words, which is the most valuable text in
  /// the record. Concatenating it with the card text is not clever, but it is
  /// honest, and FTS5 indexes it perfectly well.
  @override
  Future<CapabilityProfile?> buildProfile({
    required String cardText,
    String? userNote,
  }) async {
    final String combined =
        <String>[cardText, ?userNote].join('\n').trim();
    if (combined.isEmpty) return null;

    final String? category =
        await classify(combined, _categoryCues.keys.toList());

    return CapabilityProfile(
      canonicalEnglish: combined,
      services: const <String>[],
      categories: <String>[?category],
      model: id,
    );
  }

  /// Passes the query through untouched.
  ///
  /// Without a model there is nothing to gloss with, and rewriting a query with
  /// keyword rules would lose more than it gains. FTS5 gets the raw string,
  /// which for an English query is exactly what it wants anyway.
  @override
  Future<QueryIntent> normalizeQuery(String raw) async =>
      QueryIntent.passthrough(raw);

  @override
  Future<Float32List> embed(String text, {required EmbedKind kind}) async {
    throw const IntelligenceUnavailable(
      'No embedding model on this device; search falls back to FTS5 keywords.',
    );
  }

  @override
  Future<String?> draftMessage({
    required String request,
    required String recipientContext,
  }) async =>
      null;

  @override
  Future<void> dispose() async {}
}
