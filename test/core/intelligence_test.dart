import 'package:flutter_test/flutter_test.dart';
import 'package:recallos/core/intelligence/engines/deterministic_intelligence.dart';
import 'package:recallos/core/intelligence/text_intelligence.dart';

void main() {
  const DeterministicIntelligence engine = DeterministicIntelligence();

  group('DeterministicIntelligence — availability', () {
    test('is always available, but never for embeddings', () async {
      // The whole point: this is what runs when no platform model exists.
      expect(await engine.isAvailable(), isTrue);
      expect(await engine.isEmbeddingAvailable(), isFalse);
    });

    test('embed throws a typed error callers can catch and degrade on',
        () async {
      expect(
        () => engine.embed('anything', kind: EmbedKind.query),
        throwsA(isA<IntelligenceUnavailable>()),
      );
    });
  });

  group('DeterministicIntelligence — classification', () {
    test('recognises categories from printed card text', () async {
      final Map<String, String> cases = <String, String>{
        'Sonar Bangla Press — offset printing and banner': 'printing',
        'Medica Books, medical publisher': 'books',
        'Dhaka Diagnostic Clinic — dental': 'medical',
        'GameWave Events: stage lighting and LED decor': 'events',
      };

      for (final MapEntry<String, String> c in cases.entries) {
        expect(
          await engine.classify(c.key, DeterministicIntelligence.categories),
          c.value,
          reason: 'misclassified "${c.key}"',
        );
      }
    });

    test('returns null rather than guessing when nothing matches', () async {
      // A wrong category silently distorts ranking, so no answer beats a bad one.
      expect(
        await engine.classify(
          'Rahim Uddin, 01711223344',
          DeterministicIntelligence.categories,
        ),
        isNull,
      );
    });

    test('only ever answers from the labels it was given', () async {
      final String? result =
          await engine.classify('offset printing press', <String>['food']);
      expect(result, anyOf(isNull, 'food'));
    });
  });

  group('DeterministicIntelligence — attributes from notes', () {
    test('reads price and order size out of a real note', () async {
      final List<Attr> attrs = await engine.extractAttributes(
        'Cheap for small orders. Printed our CSE Fest shirts. '
        'Quality good but delivery was two days late.',
      );

      final Map<String, String> byKey = <String, String>{
        for (final Attr a in attrs) a.key: a.value,
      };
      expect(byKey['price_tier'], 'cheap');
      expect(byKey['min_order'], 'low');
      expect(byKey['delivery_reliability'], 'late');
      expect(byKey['quality'], 'good');
    });

    test('handles the romanised words that show up in real notes', () async {
      // Banglish is out of scope as a *language* feature, but these specific
      // words appear constantly in otherwise-English notes, so the high-value
      // ones are worth matching.
      final List<Attr> attrs =
          await engine.extractAttributes('paikari rate, kom quantity o kore');

      final Map<String, String> byKey = <String, String>{
        for (final Attr a in attrs) a.key: a.value,
      };
      expect(byKey['min_order'], anyOf('wholesale', 'low'));
    });

    test('invents nothing from a note that states nothing', () async {
      expect(await engine.extractAttributes('Met at the CSE fair.'), isEmpty);
    });

    test('scores keyword hits below what a model would claim', () async {
      final List<Attr> attrs =
          await engine.extractAttributes('very cheap printing');
      expect(attrs.single.confidence, lessThan(0.8));
    });
  });

  group('DeterministicIntelligence — profiles and queries', () {
    test('keeps the user note in the indexed text', () async {
      // With no embeddings, FTS5 is the whole index — so the note has to be in
      // the indexed string or it is unsearchable.
      final CapabilityProfile? profile = await engine.buildProfile(
        cardText: 'Sonar Bangla Press',
        userNote: 'cheap t-shirt printing for small orders',
      );

      expect(profile, isNotNull);
      expect(profile!.canonicalEnglish, contains('Sonar Bangla Press'));
      expect(profile.canonicalEnglish, contains('cheap t-shirt printing'));
      expect(profile.categories, contains('printing'));
      expect(profile.model, 'deterministic');
    });

    test('returns null for an empty card', () async {
      expect(
        await engine.buildProfile(cardText: '   ', userNote: null),
        isNull,
      );
    });

    test('passes queries through unchanged', () async {
      final QueryIntent intent =
          await engine.normalizeQuery('who prints shirts cheaply');

      expect(intent.raw, 'who prints shirts cheaply');
      expect(intent.englishGloss, 'who prints shirts cheaply');
    });

    test('offers no drafted message without a model', () async {
      expect(
        await engine.draftMessage(request: 'need 80 shirts', recipientContext: 'x'),
        isNull,
      );
    });
  });

  group('QueryIntent', () {
    test('passthrough keeps the raw text as the gloss', () {
      final QueryIntent intent = QueryIntent.passthrough('rare anatomy book');
      expect(intent.englishGloss, 'rare anatomy book');
      expect(intent.constraints, isEmpty);
    });
  });
}
