import 'dart:math' as math;
import 'dart:typed_data';

import 'wordpiece.dart';

/// Thrown when the matrix asset is missing, truncated, or from another format
/// version. Always a build/packaging error, never a runtime condition.
class EmbeddingAssetError implements Exception {
  const EmbeddingAssetError(this.message);
  final String message;
  @override
  String toString() => 'EmbeddingAssetError: $message';
}

/// Model2Vec static embeddings.
///
/// The entire runtime is: tokenise, look up each token's row, average,
/// normalise. There is no neural network and no forward pass — the model is a
/// lookup table distilled from a sentence transformer. That is what lets
/// semantic search run on a 3 GB phone at roughly a millisecond per string,
/// instead of being a flagship-only feature.
///
/// Weights are stored int8 with a per-row float32 scale, which costs ~7.7 MB
/// for 29,528 tokens × 256 dims and measured 0.99994 worst-case cosine against
/// the float32 reference.
class StaticEmbedder {
  StaticEmbedder._({
    required this._tokenizer,
    required this._weights,
    required this._scales,
    required this.rows,
    required this.dimensions,
  });

  /// Parses the `matrix.bin` produced by `tool/embeddings/export_potion.py`.
  ///
  /// Layout, all little-endian:
  /// ```
  /// magic   8 bytes  "RCLM2V\0\0"
  /// version u32
  /// rows    u32
  /// dims    u32
  /// scales  rows * f32
  /// weights rows * dims * i8
  /// ```
  factory StaticEmbedder.fromBytes({
    required Uint8List matrixBytes,
    required WordPieceTokenizer tokenizer,
  }) {
    const List<int> magic = <int>[0x52, 0x43, 0x4C, 0x4D, 0x32, 0x56, 0, 0];
    if (matrixBytes.length < 20) {
      throw const EmbeddingAssetError('matrix.bin is too short to be valid');
    }
    for (int i = 0; i < magic.length; i++) {
      if (matrixBytes[i] != magic[i]) {
        throw const EmbeddingAssetError('matrix.bin has a bad magic header');
      }
    }

    final ByteData header = ByteData.sublistView(matrixBytes, 8, 20);
    final int version = header.getUint32(0, Endian.little);
    final int rows = header.getUint32(4, Endian.little);
    final int dims = header.getUint32(8, Endian.little);

    if (version != 1) {
      throw EmbeddingAssetError('matrix.bin version $version is not supported');
    }

    const int scalesOffset = 20;
    final int weightsOffset = scalesOffset + rows * 4;
    final int expected = weightsOffset + rows * dims;
    if (matrixBytes.length != expected) {
      throw EmbeddingAssetError(
        'matrix.bin is ${matrixBytes.length} bytes, expected $expected '
        'for $rows x $dims',
      );
    }
    if (rows != tokenizer.vocabSize) {
      throw EmbeddingAssetError(
        'matrix has $rows rows but the vocabulary has ${tokenizer.vocabSize} '
        'tokens — assets are out of sync',
      );
    }

    // Views over the original buffer rather than copies. A Dart List<double>
    // of 7.5M boxed values would cost roughly 8x the memory, which is exactly
    // the sort of thing that kills the app on the devices this exists for.
    return StaticEmbedder._(
      tokenizer: tokenizer,
      weights: Int8List.sublistView(matrixBytes, weightsOffset),
      scales: Float32List.sublistView(
        Uint8List.fromList(
          matrixBytes.sublist(scalesOffset, weightsOffset),
        ),
      ),
      rows: rows,
      dimensions: dims,
    );
  }

  final WordPieceTokenizer _tokenizer;
  final Int8List _weights;
  final Float32List _scales;

  final int rows;
  final int dimensions;

  /// Identifier recorded in `embeddings.model`, so vectors from different
  /// models are never compared.
  static const String modelId = 'potion-base-8M-i8';

  /// Embeds [text] as a unit-length vector.
  ///
  /// Returns zeros for text that produces no tokens — empty input, or a string
  /// of characters the normaliser strips entirely. Callers should treat a zero
  /// vector as "no signal" rather than as a point in the space; [isUsable]
  /// makes that check explicit.
  Float32List embed(String text) {
    final List<int> ids = _tokenizer.encode(text);
    final Float32List out = Float32List(dimensions);
    if (ids.isEmpty) return out;

    for (final int id in ids) {
      if (id < 0 || id >= rows) continue;

      final int base = id * dimensions;
      final double scale = _scales[id];
      for (int d = 0; d < dimensions; d++) {
        out[d] += _weights[base + d] * scale;
      }
    }

    final double inv = 1.0 / ids.length;
    double sumSquares = 0;
    for (int d = 0; d < dimensions; d++) {
      final double v = out[d] * inv;
      out[d] = v;
      sumSquares += v * v;
    }

    final double norm = math.sqrt(sumSquares);
    if (norm > 0) {
      for (int d = 0; d < dimensions; d++) {
        out[d] /= norm;
      }
    }
    return out;
  }

  /// True when [vector] carries actual signal rather than being the zero
  /// vector returned for untokenisable input.
  static bool isUsable(Float32List vector) {
    for (final double v in vector) {
      if (v != 0) return true;
    }
    return false;
  }

  /// Cosine similarity. Both vectors are expected to be unit length, so this is
  /// a dot product; the result is clamped because float error can push it a
  /// hair outside [-1, 1].
  static double cosine(Float32List a, Float32List b) {
    if (a.length != b.length) {
      throw ArgumentError('vector length ${a.length} != ${b.length}');
    }
    double dot = 0;
    for (int i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
    }
    return dot.clamp(-1.0, 1.0);
  }

  /// Packs a vector for the `embeddings.vector` BLOB column.
  static Uint8List toBlob(Float32List vector) =>
      Uint8List.sublistView(vector);

  /// Unpacks a stored BLOB.
  ///
  /// Copies rather than viewing: SQLite may hand back a buffer whose offset is
  /// not 4-byte aligned, which `Float32List.sublistView` rejects outright.
  static Float32List fromBlob(Uint8List blob) {
    final Float32List out = Float32List(blob.length ~/ 4);
    final ByteData view = ByteData.sublistView(blob);
    for (int i = 0; i < out.length; i++) {
      out[i] = view.getFloat32(i * 4, Endian.little);
    }
    return out;
  }
}
