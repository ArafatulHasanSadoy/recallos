import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;

import '../embedding/static_embedder.dart';
import '../embedding/wordpiece.dart';
import '../text_intelligence.dart';

/// Adds real embeddings to whatever engine handles generation.
///
/// A decorator rather than another engine: generation and embedding come from
/// completely different places on this stack. Generation is the platform's
/// model when the device has one, keyword rules when it does not. Embedding is
/// an 8 MB lookup table that works everywhere. Composing them keeps each class
/// doing one thing:
///
/// ```dart
/// StaticEmbeddingIntelligence(
///   inner: PlatformIntelligence(),   // generation, may be unavailable
///   embedder: embedder,              // embeddings, always available
/// )
/// ```
///
/// The practical consequence is the point of the whole exercise: a cheap phone
/// with no platform AI still gets full semantic search, because the half that
/// matters for retrieval never depended on the model.
class StaticEmbeddingIntelligence implements TextIntelligence {
  StaticEmbeddingIntelligence({
    required this.inner,
    required this.embedder,
  });

  /// Loads the bundled assets and wraps [inner].
  ///
  /// Costs a few milliseconds — the matrix is mapped as a view, not copied —
  /// but it does read ~8 MB off disk, so call it once at startup rather than
  /// per search.
  static Future<StaticEmbeddingIntelligence> load({
    required TextIntelligence inner,
  }) async {
    final String vocab =
        await rootBundle.loadString('assets/embedding/vocab.txt');
    final String normalizer =
        await rootBundle.loadString('assets/embedding/normalizer.json');
    final ByteData matrix =
        await rootBundle.load('assets/embedding/matrix.bin');

    final WordPieceTokenizer tokenizer = WordPieceTokenizer.fromAssets(
      vocabText: vocab,
      normalizerJson: normalizer,
    );

    return StaticEmbeddingIntelligence(
      inner: inner,
      embedder: StaticEmbedder.fromBytes(
        matrixBytes: matrix.buffer.asUint8List(
          matrix.offsetInBytes,
          matrix.lengthInBytes,
        ),
        tokenizer: tokenizer,
      ),
    );
  }

  /// Handles everything except embedding.
  final TextIntelligence inner;

  /// Always available, whatever [inner] can or cannot do.
  final StaticEmbedder embedder;

  @override
  String get id => '${inner.id}+${StaticEmbedder.modelId}';

  /// Reports the inner engine's availability, because that is what governs
  /// generation. Embedding availability is asked separately and is always true.
  @override
  Future<bool> isAvailable() => inner.isAvailable();

  @override
  Future<bool> isEmbeddingAvailable() async => true;

  @override
  Future<Float32List> embed(String text, {required EmbedKind kind}) async {
    // potion-base-8M is a symmetric model: queries and documents share one
    // space with no prompt prefix, so [kind] is accepted for interface
    // compatibility and deliberately unused. Asymmetric models would branch here.
    return embedder.embed(text);
  }

  @override
  Future<String?> classify(String text, List<String> labels) =>
      inner.classify(text, labels);

  @override
  Future<List<Attr>> extractAttributes(String note) =>
      inner.extractAttributes(note);

  @override
  Future<CapabilityProfile?> buildProfile({
    required String cardText,
    String? userNote,
  }) =>
      inner.buildProfile(cardText: cardText, userNote: userNote);

  @override
  Future<QueryIntent> normalizeQuery(String raw) => inner.normalizeQuery(raw);

  @override
  Future<String?> draftMessage({
    required String request,
    required String recipientContext,
  }) =>
      inner.draftMessage(
        request: request,
        recipientContext: recipientContext,
      );

  @override
  Future<void> dispose() => inner.dispose();
}
