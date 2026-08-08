import 'dart:typed_data';

/// A single fact derived from a user's note, carrying where it came from.
///
/// Source-aware provenance is the thing that stops an AI guess from being
/// displayed as if it were printed on the card.
class Attr {
  const Attr({
    required this.key,
    required this.value,
    required this.confidence,
  });

  /// Snake_case, drawn from a controlled vocabulary so it can be filtered on,
  /// e.g. `price_tier`, `min_order`, `delivery_reliability`.
  final String key;
  final String value;
  final double confidence;

  @override
  String toString() => '$key=$value (${confidence.toStringAsFixed(2)})';
}

/// Embeddings are asymmetric: the same text embeds differently depending on
/// whether it is being stored or searched for. EmbeddingGemma and most modern
/// retrieval models expect a prompt prefix that says which side you are on.
enum EmbedKind { document, query }

/// A code-mixed query reduced to something searchable.
///
/// This is the heart of Banglish retrieval. Rather than hoping a multilingual
/// embedder handles romanised Bangla well — it does not — both the card side
/// and the query side are normalised to English before embedding.
class QueryIntent {
  const QueryIntent({
    required this.raw,
    required this.englishGloss,
    this.category,
    this.constraints = const <String, String>{},
  });

  /// Exactly what the user typed, preserved for keyword search and for the
  /// retrieval ablation (raw-vs-normalised) in the evaluation harness.
  final String raw;

  /// "Kom quantity te cheap CSE Fest T-shirt print korbe ke?"
  ///   -> "who prints CSE Fest t-shirts cheaply in low quantity"
  final String englishGloss;

  final String? category;

  /// e.g. `{price: cheap, quantity: low}`.
  final Map<String, String> constraints;

  /// When the model is unavailable we fall back to the raw string. Search still
  /// works — it just runs keyword-only, which is the Tier C path.
  factory QueryIntent.passthrough(String raw) =>
      QueryIntent(raw: raw, englishGloss: raw);

  @override
  String toString() => 'QueryIntent("$raw" -> "$englishGloss")';
}

/// A card's services and character, written in English so it embeds well.
///
/// Generated once at save time from the printed text plus the user's note, then
/// stored alongside the originals rather than replacing them.
class CapabilityProfile {
  const CapabilityProfile({
    required this.canonicalEnglish,
    required this.services,
    required this.categories,
    required this.model,
  });

  final String canonicalEnglish;
  final List<String> services;
  final List<String> categories;

  /// Which model produced this, so profiles can be regenerated when a better
  /// model arrives without re-deriving the ones that are already good.
  final String model;

  @override
  String toString() => 'CapabilityProfile(${categories.join(", ")})';
}

/// Thrown when a model is not available on this device.
///
/// Callers are expected to catch this and degrade — never to surface it raw.
class IntelligenceUnavailable implements Exception {
  const IntelligenceUnavailable(this.reason);
  final String reason;
  @override
  String toString() => 'IntelligenceUnavailable: $reason';
}

/// Semantic understanding: classification, attribute extraction, query
/// normalisation, embeddings.
///
/// Deliberately narrow. Each method asks for a short, constrained output,
/// because that is what small on-device models are reliable at — a 1B model
/// asked for nested JSON is not a foundation you can build on. Field extraction
/// (phone, email, URL, name) is *not* here: that is deterministic Dart.
abstract interface class TextIntelligence {
  /// Stable identifier, recorded alongside anything this produces.
  String get id;

  /// Whether generative calls can run right now. When false, callers fall back:
  /// classification skips, notes stay unstructured, queries pass through raw.
  Future<bool> isAvailable();

  /// Whether [embed] can run. Tracked separately because the embedding model is
  /// much smaller than the generative one, so a device can often do semantic
  /// search while being unable to run generation.
  Future<bool> isEmbeddingAvailable();

  /// Pick one label from [labels]. Returns null when nothing fits — an honest
  /// null beats a confident wrong category.
  Future<String?> classify(String text, List<String> labels);

  /// Pull structured attributes out of a free-text or transcribed voice note.
  Future<List<Attr>> extractAttributes(String note);

  /// Build the English capability profile used for indexing.
  Future<CapabilityProfile?> buildProfile({
    required String cardText,
    String? userNote,
  });

  /// Normalise a Bangla / Banglish / English query into a searchable intent.
  /// Implementations should return [QueryIntent.passthrough] rather than throw
  /// when the model is missing.
  Future<QueryIntent> normalizeQuery(String raw);

  /// Embed [text]. Length is implementation-defined but must be stable for a
  /// given [id]; stored vectors record their model so mixed dimensions never
  /// get compared.
  Future<Float32List> embed(String text, {required EmbedKind kind});

  /// Draft an outreach message the user reviews before sending. RecallOS never
  /// sends anything on the user's behalf.
  Future<String?> draftMessage({
    required String request,
    required String recipientContext,
  });

  Future<void> dispose();
}
