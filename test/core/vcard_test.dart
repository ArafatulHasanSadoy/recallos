import 'package:flutter_test/flutter_test.dart';
import 'package:recallos/core/db/enums.dart';
import 'package:recallos/core/export/vcard.dart';

/// The serialiser that hands a contact to the rest of the phone.
///
/// Worth testing carefully because the failure mode is silent and offsite: a
/// malformed line does not throw here, it produces a file the contacts app
/// either rejects with no explanation or imports wrong, and the user finds out
/// days later when they cannot call somebody.
void main() {
  List<String> linesOf(String vcf) =>
      vcf.split('\r\n').where((String l) => l.isNotEmpty).toList();

  group('structure', () {
    test('opens and closes as a 3.0 card', () {
      final List<String> lines =
          linesOf(buildVCard(const VCardData(displayName: 'Asif Ahmed Peal')));

      expect(lines.first, 'BEGIN:VCARD');
      expect(lines[1], 'VERSION:3.0');
      expect(lines.last, 'END:VCARD');
    });

    test('every line ends CRLF, as the spec requires', () {
      final String vcf = buildVCard(const VCardData(
        displayName: 'Asif Ahmed Peal',
        organization: 'Aquarius Pet Shop',
      ));

      // A bare \n is the single most common reason an importer rejects a file.
      expect(vcf.contains('\n'), isTrue);
      for (final String line in vcf.split('\r\n')) {
        expect(line.contains('\n'), isFalse,
            reason: 'a line was terminated with a bare newline');
      }
    });

    test('several contacts concatenate into one importable file', () {
      final String vcf = buildVCards(const <VCardData>[
        VCardData(displayName: 'One'),
        VCardData(displayName: 'Two'),
      ]);

      expect('BEGIN:VCARD'.allMatches(vcf).length, 2);
      expect('END:VCARD'.allMatches(vcf).length, 2);
    });
  });

  group('fields', () {
    test('carries the job, the company and the endpoints', () {
      final String vcf = buildVCard(const VCardData(
        displayName: 'Asif Ahmed Peal',
        organization: 'Aquarius Pet Shop',
        title: 'Owner',
        contacts: <VCardContact>[
          VCardContact(
              kind: ContactKind.phone, value: '+8801711363991', label: 'mobile'),
          VCardContact(kind: ContactKind.email, value: 'p_eal@yahoo.com'),
        ],
      ));
      final List<String> lines = linesOf(vcf);

      expect(lines, contains('FN:Asif Ahmed Peal'));
      expect(lines, contains('ORG:Aquarius Pet Shop'));
      expect(lines, contains('TITLE:Owner'));
      expect(lines, contains('TEL;TYPE=CELL:+8801711363991'));
      expect(lines, contains('EMAIL;TYPE=INTERNET:p_eal@yahoo.com'));
    });

    test('the note survives the trip', () {
      // The whole product thesis is that the note is the valuable part, so a
      // contact export that drops it exports the wrong half.
      final String vcf = buildVCard(const VCardData(
        displayName: 'Rasel',
        note: 'cheap t-shirt printer from CSE fest',
      ));

      expect(linesOf(vcf), contains('NOTE:cheap t-shirt printer from CSE fest'));
    });

    test('an empty value is left out rather than written blank', () {
      final String vcf = buildVCard(const VCardData(
        displayName: 'Someone',
        organization: '   ',
        contacts: <VCardContact>[
          VCardContact(kind: ContactKind.phone, value: '  '),
        ],
      ));

      expect(vcf.contains('ORG:'), isFalse);
      expect(vcf.contains('TEL'), isFalse);
    });
  });

  group('escaping', () {
    test('a comma in a company name does not split the field', () {
      final String vcf = buildVCard(const VCardData(
        displayName: 'Someone',
        organization: 'Olympus Hospital (Pvt.) Ltd., Dhaka',
      ));

      expect(linesOf(vcf),
          contains(r'ORG:Olympus Hospital (Pvt.) Ltd.\, Dhaka'));
    });

    test('a semicolon in an address does not invent components', () {
      final String vcf = buildVCard(const VCardData(
        displayName: 'Someone',
        address: 'Shop 300; New Market, Dhaka',
      ));

      final String adr =
          linesOf(vcf).firstWhere((String l) => l.startsWith('ADR'));
      // Five structural semicolons, and the one in the text escaped.
      expect(adr, r'ADR;TYPE=WORK:;;Shop 300\; New Market\, Dhaka;;;;');
    });

    test('a multi-line note becomes one line', () {
      final String vcf = buildVCard(const VCardData(
        displayName: 'Someone',
        note: 'first line\nsecond line',
      ));

      expect(linesOf(vcf), contains(r'NOTE:first line\nsecond line'));
    });
  });

  group('duplicates', () {
    test('the same number twice becomes one line', () {
      // Not hypothetical: a person with two businesses usually has both cards
      // carrying both of his numbers, and a contacts app given the same
      // number twice stores it twice.
      final String vcf = buildVCard(const VCardData(
        displayName: 'Md. Abul Bashar Sarker',
        contacts: <VCardContact>[
          VCardContact(kind: ContactKind.phone, value: '01819104376'),
          VCardContact(kind: ContactKind.phone, value: '01709822709'),
        ],
      ));

      expect('TEL'.allMatches(vcf).length, 2);
    });
  });

  group('names', () {
    test('splits the last token as the family name', () {
      final String vcf =
          buildVCard(const VCardData(displayName: 'Md. Abul Bashar Sarker'));

      expect(linesOf(vcf), contains(r'N:Sarker;Md. Abul Bashar;;;'));
      // FN carries it exactly as printed, whatever N guessed.
      expect(linesOf(vcf), contains('FN:Md. Abul Bashar Sarker'));
    });

    test('a single-token name is not split', () {
      final String vcf = buildVCard(const VCardData(displayName: 'Rahman'));
      expect(linesOf(vcf), contains('N:Rahman;;;;'));
    });

    test('a company-only card is named after the company', () {
      // Cards with a shop name and no legible person are common, and a
      // contact called "Unnamed" is useless in an address book.
      final String vcf = buildVCard(const VCardData(
        displayName: '',
        organization: 'Target Center',
      ));

      expect(linesOf(vcf), contains('FN:Target Center'));
    });
  });
}
