import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:recallos/core/intelligence/embedding/static_embedder.dart';
import 'package:recallos/core/intelligence/embedding/wordpiece.dart';

/// Loads the real assets from disk rather than through rootBundle, so these run
/// as plain unit tests on the host with no Flutter binding.
({WordPieceTokenizer tokenizer, StaticEmbedder embedder}) _load() {
  final WordPieceTokenizer tokenizer = WordPieceTokenizer.fromAssets(
    vocabText: File('assets/embedding/vocab.txt').readAsStringSync(),
    normalizerJson: File('assets/embedding/normalizer.json').readAsStringSync(),
  );
  return (
    tokenizer: tokenizer,
    embedder: StaticEmbedder.fromBytes(
      matrixBytes: File('assets/embedding/matrix.bin').readAsBytesSync(),
      tokenizer: tokenizer,
    ),
  );
}

Float32List _decodeVector(String base64Vector) {
  final Uint8List bytes = base64Decode(base64Vector);
  final Float32List out = Float32List(bytes.length ~/ 4);
  final ByteData view = ByteData.sublistView(bytes);
  for (int i = 0; i < out.length; i++) {
    out[i] = view.getFloat32(i * 4, Endian.little);
  }
  return out;
}

void main() {
  late WordPieceTokenizer tokenizer;
  late StaticEmbedder embedder;

  setUpAll(() {
    final loaded = _load();
    tokenizer = loaded.tokenizer;
    embedder = loaded.embedder;
  });

  group('assets', () {
    test('matrix matches the vocabulary', () {
      expect(embedder.rows, tokenizer.vocabSize);
      expect(embedder.rows, 29528);
      expect(embedder.dimensions, 256);
    });

    test('a truncated matrix is rejected rather than read as garbage', () {
      final Uint8List full =
          File('assets/embedding/matrix.bin').readAsBytesSync();
      expect(
        () => StaticEmbedder.fromBytes(
          matrixBytes: Uint8List.sublistView(full, 0, full.length - 100),
          tokenizer: tokenizer,
        ),
        throwsA(isA<EmbeddingAssetError>()),
      );
    });

    test('a bad header is rejected', () {
      expect(
        () => StaticEmbedder.fromBytes(
          matrixBytes: Uint8List(64),
          tokenizer: tokenizer,
        ),
        throwsA(isA<EmbeddingAssetError>()),
      );
    });
  });

  // The point of this file. A hand-written tokenizer that diverges from the one
  // that produced the vectors degrades retrieval silently — rankings get a
  // little worse and nothing errors. These fixtures come from the Python
  // reference via tool/embeddings/export_potion.py.
  group('parity with the Python reference', () {
    late List<dynamic> samples;

    setUpAll(() {
      final Map<String, dynamic> fixture = jsonDecode(
        File('test/fixtures/embedding_parity.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      samples = fixture['samples'] as List<dynamic>;
    });

    test('tokenises every sample identically', () {
      for (final dynamic raw in samples) {
        final Map<String, dynamic> s = raw as Map<String, dynamic>;
        final String text = s['text'] as String;

        expect(
          tokenizer.tokenize(text),
          (s['tokens'] as List<dynamic>).cast<String>(),
          reason: 'tokens diverged for ${jsonEncode(text)}',
        );
        expect(
          tokenizer.encode(text),
          (s['ids'] as List<dynamic>).cast<int>(),
          reason: 'ids diverged for ${jsonEncode(text)}',
        );
      }
    });

    test('produces the same vectors', () {
      for (final dynamic raw in samples) {
        final Map<String, dynamic> s = raw as Map<String, dynamic>;
        final String text = s['text'] as String;

        final Float32List expected = _decodeVector(s['vector'] as String);
        final Float32List actual = embedder.embed(text);

        expect(actual.length, expected.length);
        for (int i = 0; i < expected.length; i++) {
          expect(
            actual[i],
            closeTo(expected[i], 1e-4),
            reason: 'dim $i diverged for ${jsonEncode(text)}',
          );
        }
      }
    });
  });

  group('tokenizer behaviour', () {
    test('lowercases and strips accents', () {
      expect(tokenizer.tokenize('Cheap T-Shirt PRINTING'),
          <String>['cheap', 't', '-', 'shirt', 'printing']);
      expect(tokenizer.tokenize('Médica'), tokenizer.tokenize('Medica'));
    });

    test('splits punctuation into its own tokens', () {
      expect(tokenizer.tokenize('info@medica.com'),
          contains('@'));
      expect(tokenizer.tokenize('a,b'), <String>['a', ',', 'b']);
    });

    test('uses the ## prefix for continuations', () {
      final List<String> pieces = tokenizer.tokenize('Médica Bóoks');
      expect(pieces.any((String p) => p.startsWith('##')), isTrue);
    });

    test('returns nothing for empty or whitespace-only input', () {
      expect(tokenizer.tokenize(''), isEmpty);
      expect(tokenizer.tokenize('   '), isEmpty);
      expect(tokenizer.tokenize('\n\t'), isEmpty);
    });

    test('an absurdly long word collapses to a single unknown token', () {
      expect(tokenizer.tokenize('a' * 200), <String>['[UNK]']);
    });
  });

  group('embedding', () {
    test('vectors are unit length', () {
      for (final String text in <String>[
        'cheap t-shirt printing',
        'a',
        'Medica Books Dhanmondi',
      ]) {
        final Float32List v = embedder.embed(text);
        double sum = 0;
        for (final double x in v) {
          sum += x * x;
        }
        expect(sum, closeTo(1.0, 1e-5), reason: 'not normalised: $text');
      }
    });

    test('untokenisable input yields an unusable zero vector', () {
      final Float32List v = embedder.embed('');
      expect(StaticEmbedder.isUsable(v), isFalse);
      expect(StaticEmbedder.isUsable(embedder.embed('cheap printing')), isTrue);
    });

    // The reason the 8 MB is worth carrying: these strings share almost no
    // words, so lexical search alone would never connect them.
    test('captures meaning across different wording', () {
      final Float32List query = embedder.embed('who prints shirts cheaply');
      final Float32List related =
          embedder.embed('screen printing press, low cost');
      final Float32List unrelated =
          embedder.embed('dental clinic appointment');

      final double relatedScore = StaticEmbedder.cosine(query, related);
      final double unrelatedScore = StaticEmbedder.cosine(query, unrelated);

      expect(relatedScore, greaterThan(0.3));
      expect(relatedScore, greaterThan(unrelatedScore + 0.25));
    });

    test('identical text is maximally similar to itself', () {
      final Float32List a = embedder.embed('Medica Books');
      expect(StaticEmbedder.cosine(a, a), closeTo(1.0, 1e-5));
    });

    test('survives a database round trip', () {
      final Float32List original = embedder.embed('wholesale winter hoodie');
      final Float32List restored =
          StaticEmbedder.fromBlob(StaticEmbedder.toBlob(original));

      expect(restored.length, original.length);
      expect(StaticEmbedder.cosine(original, restored), closeTo(1.0, 1e-6));
    });

    test('survives a round trip through an unaligned buffer', () {
      // SQLite can hand back a BLOB at an arbitrary offset; a Float32List view
      // over that would throw, so fromBlob must copy.
      final Float32List original = embedder.embed('Sonar Bangla Press');
      final Uint8List blob = StaticEmbedder.toBlob(original);

      final Uint8List shifted = Uint8List(blob.length + 1)
        ..setRange(1, blob.length + 1, blob);
      final Float32List restored =
          StaticEmbedder.fromBlob(Uint8List.sublistView(shifted, 1));

      expect(StaticEmbedder.cosine(original, restored), closeTo(1.0, 1e-6));
    });

    test('is fast enough to run per keystroke', () {
      // The whole premise is that this is a lookup, not inference. If a single
      // embedding ever costs milliseconds, something has regressed badly.
      const int iterations = 200;
      final Stopwatch clock = Stopwatch()..start();
      for (int i = 0; i < iterations; i++) {
        embedder.embed('cheap t-shirt printing for small orders $i');
      }
      clock.stop();

      final double perCall = clock.elapsedMicroseconds / iterations;
      expect(perCall, lessThan(5000), reason: '${perCall.round()}us per embed');
    });
  });
}
