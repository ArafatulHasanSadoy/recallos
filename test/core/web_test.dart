import 'package:flutter_test/flutter_test.dart';
import 'package:recallos/core/extraction/web.dart';

void main() {
  group('WebExtractor — emails', () {
    test('finds and lowercases a plain address', () {
      final List<EmailMatch> found =
          WebExtractor.extractEmails('Email: Info@MedicaBooks.com.bd');

      expect(found, hasLength(1));
      expect(found.single.normalized, 'info@medicabooks.com.bd');
      expect(found.single.isValid, isTrue);
      expect(found.single.repaired, isFalse);
    });

    test('accepts Bangladeshi second-level domains', () {
      for (final String suffix in <String>[
        'com.bd',
        'net.bd',
        'org.bd',
        'edu.bd',
        'gov.bd',
      ]) {
        final List<EmailMatch> found =
            WebExtractor.extractEmails('contact@example.$suffix');
        expect(found.single.isValid, isTrue, reason: 'failed for .$suffix');
      }
    });

    test('repairs a mangled @ but marks it for review', () {
      // OCR routinely turns @ into (a) on printed cards.
      final List<EmailMatch> found =
          WebExtractor.extractEmails('info(a)medicabooks.com.bd');

      expect(found, hasLength(1));
      expect(found.single.normalized, 'info@medicabooks.com.bd');
      expect(found.single.repaired, isTrue);
      expect(found.single.needsReview, isTrue);
    });

    test('does not double-count an address it already read cleanly', () {
      final List<EmailMatch> found =
          WebExtractor.extractEmails('info@medicabooks.com.bd');
      expect(found, hasLength(1));
    });

    test('de-duplicates the same address written twice', () {
      final List<EmailMatch> found = WebExtractor.extractEmails(
        'Info@Medica.com.bd and info@medica.com.bd',
      );
      expect(found, hasLength(1));
    });

    test('finds nothing in text with no address', () {
      expect(WebExtractor.extractEmails('Medica Books, Dhanmondi'), isEmpty);
      expect(WebExtractor.extractEmails(''), isEmpty);
    });

    test('extracts the domain for employer matching', () {
      expect(
        WebExtractor.domainOfEmail('rahim@medicabooks.com.bd'),
        'medicabooks.com.bd',
      );
      expect(WebExtractor.domainOfEmail('not-an-email'), isNull);
    });
  });

  group('WebExtractor — websites', () {
    test('normalises the ways a site gets printed', () {
      for (final String written in <String>[
        'www.medicabooks.com.bd',
        'https://medicabooks.com.bd',
        'http://www.medicabooks.com.bd',
        'medicabooks.com.bd',
      ]) {
        final List<WebsiteMatch> found = WebExtractor.extractWebsites(written);
        expect(found, hasLength(1), reason: 'failed to read "$written"');
        expect(found.single.domain, 'medicabooks.com.bd');
        expect(found.single.url, startsWith('http'));
      }
    });

    test('does not mistake an email domain for a website', () {
      final List<WebsiteMatch> found =
          WebExtractor.extractWebsites('info@medicabooks.com.bd');
      expect(found, isEmpty);
    });

    test('reads both when a card carries an email and a separate site', () {
      const String card = '''
        Medica Books
        info@medicabooks.com.bd
        www.medicabooks.com.bd
      ''';
      final List<WebsiteMatch> sites = WebExtractor.extractWebsites(card);
      expect(sites, hasLength(1));
      expect(sites.single.domain, 'medicabooks.com.bd');
    });

    test('ignores tokens that merely contain a dot', () {
      // Version numbers, prices, and sentence-ending words must not become URLs.
      for (final String noise in <String>[
        'Ver 2.1',
        'Tk 1500.00',
        'Dhanmondi 27.Dhaka',
      ]) {
        expect(
          WebExtractor.extractWebsites(noise),
          isEmpty,
          reason: '"$noise" must not parse as a website',
        );
      }
    });

    test('keeps the path when one is printed', () {
      final List<WebsiteMatch> found =
          WebExtractor.extractWebsites('facebook.com/medicabooks');
      expect(found.single.domain, 'facebook.com');
      expect(found.single.url, contains('/medicabooks'));
    });
  });
}
