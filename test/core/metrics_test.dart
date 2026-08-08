import 'package:flutter_test/flutter_test.dart';
import 'package:recallos/core/extraction/metrics.dart';

void main() {
  group('editDistance', () {
    test('is zero for identical strings', () {
      expect(editDistance('Medica Books', 'Medica Books'), 0);
    });

    test('counts single-character edits', () {
      expect(editDistance('kitten', 'sitting'), 3);
      expect(editDistance('', 'abc'), 3);
      expect(editDistance('abc', ''), 3);
    });

    test('counts Bengali by character, not by byte', () {
      // Multi-byte runes must count as one edit each, or CER on Bengali cards
      // would be inflated several times over and the gate would misfire.
      expect(editDistance('মেডিকা', 'মেডিকা'), 0);
      expect(editDistance('বই', 'বি'), 1);
    });
  });

  group('characterErrorRate', () {
    test('is zero for a perfect read', () {
      expect(
        characterErrorRate(reference: 'Medica Books', hypothesis: 'Medica Books'),
        0,
      );
    });

    test('ignores whitespace differences', () {
      expect(
        characterErrorRate(
          reference: 'Medica  Books',
          hypothesis: 'Medica Books',
        ),
        0,
      );
    });

    test('reports 1.0 when nothing was read', () {
      expect(
        characterErrorRate(reference: 'Medica Books', hypothesis: ''),
        1.0,
      );
    });

    test('can exceed 1.0 when the engine invents text', () {
      // Hallucinating is worse than reading nothing, so this is not clamped.
      final double cer = characterErrorRate(
        reference: 'Books',
        hypothesis: 'Books and a great deal of text that was never there',
      );
      expect(cer, greaterThan(1.0));
    });
  });

  group('FieldScorer', () {
    test('scores a clean extraction', () {
      final FieldScorer s = FieldScorer()
        ..record(fieldKey: 'phone', expected: '+8801711223344', actual: '+8801711223344')
        ..record(fieldKey: 'phone', expected: '+8801911556677', actual: '+8801911556677');

      final FieldScore phone = s.scores().single;
      expect(phone.precision, 1.0);
      expect(phone.recall, 1.0);
      expect(phone.f1, 1.0);
    });

    test('a wrong value hurts precision and recall together', () {
      final FieldScorer s = FieldScorer()
        ..record(fieldKey: 'phone', expected: '+8801711223344', actual: '+8801711999999');

      final FieldScore phone = s.scores().single;
      expect(phone.truePositives, 0);
      expect(phone.falsePositives, 1);
      expect(phone.falseNegatives, 1);
      expect(phone.f1, 0);
    });

    test('a missed field costs recall but not precision', () {
      final FieldScorer s = FieldScorer()
        ..record(fieldKey: 'company', expected: 'Medica Books', actual: null);

      final FieldScore company = s.scores().single;
      expect(company.falseNegatives, 1);
      expect(company.falsePositives, 0);
      expect(company.recall, 0);
    });

    test('inventing a field that was not there costs precision', () {
      final FieldScorer s = FieldScorer()
        ..record(fieldKey: 'designation', expected: null, actual: 'Manager');

      final FieldScore d = s.scores().single;
      expect(d.falsePositives, 1);
      expect(d.precision, 0);
    });

    test('correctly extracting nothing is not scored', () {
      // Otherwise every empty field on every card would inflate the numbers.
      final FieldScorer s = FieldScorer()
        ..record(fieldKey: 'website', expected: null, actual: null);
      expect(s.scores(), isEmpty);
    });

    test('comparison ignores case and surrounding whitespace', () {
      final FieldScorer s = FieldScorer()
        ..record(fieldKey: 'company', expected: 'Medica Books', actual: '  medica books ');
      expect(s.scores().single.truePositives, 1);
    });

    test('weights F1 by how often each field appears', () {
      final FieldScorer s = FieldScorer();
      // Phone appears 10 times and is always right.
      for (int i = 0; i < 10; i++) {
        s.record(fieldKey: 'phone', expected: 'p$i', actual: 'p$i');
      }
      // A rare field is always wrong, and must not dominate the headline.
      s.record(fieldKey: 'fax', expected: 'f1', actual: 'wrong');

      expect(s.weightedF1(), greaterThan(0.8));
    });
  });

  group('EngineReport and the Phase 0 gate', () {
    test('summarises latency and failures', () {
      final EngineReport r = EngineReport(engine: 'routed')
        ..addCard(cer: 0.1, durationMs: 100, totalFailure: false)
        ..addCard(cer: 0.3, durationMs: 300, totalFailure: false)
        ..addCard(cer: 1.0, durationMs: 200, totalFailure: true);

      expect(r.cardCount, 3);
      expect(r.meanCer, closeTo(0.466, 0.01));
      expect(r.totalFailureRate, closeTo(0.333, 0.01));
      expect(r.meanDurationMs, closeTo(200, 0.01));
    });

    test('p90 latency tracks the slow tail, not the average', () {
      final EngineReport r = EngineReport(engine: 'tesseract-ben');
      for (int i = 0; i < 9; i++) {
        r.addCard(cer: 0, durationMs: 100, totalFailure: false);
      }
      r.addCard(cer: 0, durationMs: 5000, totalFailure: false);

      expect(r.meanDurationMs, lessThan(1000));
      expect(r.p90DurationMs, greaterThanOrEqualTo(100));
    });

    test('the gate passes on strong Bengali accuracy', () {
      final EngineReport r = EngineReport(engine: 'routed');
      for (int i = 0; i < 10; i++) {
        r.bengaliCards.record(fieldKey: 'company', expected: 'c$i', actual: 'c$i');
      }
      expect(clearsBengaliGate(r), isTrue);
    });

    test('the gate fails when Bengali fields are mostly wrong', () {
      final EngineReport r = EngineReport(engine: 'routed');
      for (int i = 0; i < 10; i++) {
        r.bengaliCards.record(
          fieldKey: 'company',
          expected: 'c$i',
          actual: i < 3 ? 'c$i' : 'garbled',
        );
      }
      expect(clearsBengaliGate(r), isFalse);
      expect(r.bengaliCards.weightedF1(), lessThan(kBengaliGateThreshold));
    });

    test('formats a report without throwing on an empty dataset', () {
      expect(EngineReport(engine: 'mlkit').format(), contains('mlkit'));
    });
  });
}
