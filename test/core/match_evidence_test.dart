import 'package:flutter_test/flutter_test.dart';
import 'package:recallos/core/search/match_evidence.dart';

void main() {
  List<String> marked(MatchEvidence e) => <String>[
    for (final (int, int) s in e.spans) e.excerpt!.substring(s.$1, s.$2),
  ];

  test('the note first, with the matched word marked', () {
    final MatchEvidence e = explainMatch(
      'AC repair',
      notes: 'AC servicing',
      printed: 'CoolAir Solutions\nRepair and servicing',
    )!;
    expect(e.source, EvidenceSource.note);
    expect(e.label, 'Your note');
    expect(e.excerpt, 'AC servicing');
    expect(marked(e), <String>['AC']);
  });

  test('where you met, before the printed text', () {
    final MatchEvidence e = explainMatch(
      'CSE fest',
      place: 'CSE fest at NSU',
      printed: 'CSE Society',
    )!;
    expect(e.source, EvidenceSource.met);
    expect(marked(e), <String>['CSE', 'fest']);
  });

  test('a field, named', () {
    final MatchEvidence e = explainMatch(
      'mirpur',
      fields: <String, List<String>>{
        'Company': <String>['CoolAir Solutions'],
        'Address': <String>['House 5, Road 2, Mirpur'],
      },
    )!;
    expect(e.source, EvidenceSource.field);
    expect(e.label, 'Address');
    expect(marked(e), <String>['Mirpur']);
  });

  test('printed text in no field, cut around the match', () {
    final MatchEvidence e = explainMatch(
      'elephant',
      printed:
          'TechFix Repair Centre\nLaptop and Mobile Servicing, data recovery, '
          'screen replacement, motherboard work\nShop 12, Multiplan Center, '
          'Elephant Road, Dhaka',
    )!;
    expect(e.source, EvidenceSource.printed);
    expect(e.excerpt, startsWith('…'));
    expect(e.excerpt!.length, lessThanOrEqualTo(excerptLength + 12));
    expect(marked(e), <String>['Elephant']);
  });

  test('a finished short word does not mark a longer one', () {
    final MatchEvidence e = explainMatch(
      'ac repair',
      notes: 'Accounts, and a repair now and then',
    )!;
    expect(marked(e), <String>['repair']);
  });

  test('no shared word: the note\'s meaning, or just meaning', () {
    expect(
      explainMatch(
        'who fixes ACs',
        notes: 'air conditioner servicing',
        noteMeaning: true,
      )!.label,
      'Close in meaning to your note',
    );
    final MatchEvidence plain = explainMatch('who fixes ACs')!;
    expect(plain.source, EvidenceSource.meaning);
    expect(plain.excerpt, isNull);
  });

  group('stop words (M7½)', () {
    test('are never shown as the reason', () {
      final MatchEvidence? e = explainMatch(
        'what expires in the next 90 days',
        fields: <String, List<String>>{
          'Counts from': <String>['From the purchase'],
        },
      );
      expect(e!.source, EvidenceSource.meaning);
      expect(e.spans, isEmpty);
    });

    test('do not hide a real word beside them', () {
      final MatchEvidence? e = explainMatch(
        'the AC repair',
        notes: 'AC servicing before summer',
      );
      expect(e!.source, EvidenceSource.note);
      expect(e.excerpt!.substring(e.spans.single.$1, e.spans.single.$2), 'AC');
    });

    test('still count when the query is nothing else', () {
      expect(
        explainMatch('the', printed: 'The Coffee Shop')!.source,
        EvidenceSource.printed,
      );
    });
  });
}
