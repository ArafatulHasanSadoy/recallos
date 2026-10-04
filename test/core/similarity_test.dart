import 'package:flutter_test/flutter_test.dart';
import 'package:recallos/core/identity/resolution.dart';
import 'package:recallos/core/identity/similarity.dart';

/// The measure that decides whether two OCR reads are the same name.
///
/// Its whole job is to separate two cases that look alike numerically: one
/// word mangled by the engine, versus two different businesses that share a
/// family name. The threshold has to fall between them, so both are pinned
/// here with the real strings that motivated it.
void main() {
  group('edit distance', () {
    test('counts the obvious cases', () {
      expect(editDistance('abc', 'abc'), 0);
      expect(editDistance('', 'abc'), 3);
      expect(editDistance('abc', ''), 3);
      expect(editDistance('kitten', 'sitting'), 3);
    });

    test('is symmetric', () {
      expect(editDistance('target', 'ctargei'),
          editDistance('ctargei', 'target'));
    });
  });

  group('plausible names', () {
    test('a real name passes', () {
      for (final String name in <String>[
        'Md. Abul Bashar Sarker',
        'Asif Ahmed Peal',
        'A. K. M. Rahman',
        'Peal',
      ]) {
        expect(looksLikePersonName(name), isTrue, reason: name);
      }
    });

    test('an address that landed in the name field does not', () {
      // A real read, off the email row of a shop card whose text ran
      // together. Promoted, it becomes a contact named after an email.
      expect(looksLikePersonName('OE-mgil: targetbrand2015@gm'), isFalse);
      expect(looksLikePersonName('targetbrand2015@gmail.com'), isFalse);
      expect(looksLikePersonName('www.techlandbd.com'), isTrue,
          reason: 'a bare domain has no @ or colon and reads as a name; the '
              'website extractor is what keeps it out of this field');
    });

    test('a label that came along with its colon does not', () {
      expect(looksLikePersonName('Cell: 01711363991'), isFalse);
      expect(looksLikePersonName('E-mail: someone'), isFalse);
    });

    test('something mostly digits does not', () {
      expect(looksLikePersonName('220/D 1216'), isFalse);
      expect(looksLikePersonName(''), isFalse);
      expect(looksLikePersonName(null), isFalse);
    });
  });

  group('name similarity', () {
    test('an OCR variant of one word still reads as the same name', () {
      // Two reads of the same shop sign, minutes apart. This is the pair the
      // whole feature exists for, and exact equality finds nothing in it.
      final double score = nameSimilarity(
        normalizeOrgName('TARGET, CENTER,'),
        normalizeOrgName('CTARGEI. CENTER'),
      );

      expect(score, greaterThan(proposeSimilarity));
    });

    test('two businesses sharing a family name stay apart', () {
      final double score = nameSimilarity(
        normalizeOrgName('Rahman Traders'),
        normalizeOrgName('Rahman Motors'),
      );

      expect(score, lessThan(proposeSimilarity),
          reason: 'these are two different shops and must not be proposed');
    });

    test('a shared word alone is not a match', () {
      // "Hospital" appears on half the cards in a medical district.
      final double score = nameSimilarity(
        normalizeOrgName('Olympus Hospital'),
        normalizeOrgName('Green Hospital'),
      );
      expect(score, lessThan(proposeSimilarity));
    });

    test('a longer name is not matched by one of its words', () {
      final double score = nameSimilarity(
        normalizeOrgName('Target'),
        normalizeOrgName('Target Center Dhaka Limited'),
      );
      // Dividing by the longer token count is what stops this scoring 1.0.
      expect(score, lessThan(proposeSimilarity));
    });

    test('identical names score 1', () {
      expect(nameSimilarity('aquarius pet shop', 'aquarius pet shop'), 1);
    });

    test('null is never similar to anything', () {
      expect(nameSimilarity(null, 'anything'), 0);
      expect(nameSimilarity('anything', null), 0);
    });

    test('word order does not matter', () {
      // Extraction takes tokens off a card in layout order, which is not
      // always reading order.
      expect(
        nameSimilarity('center target', 'target center'),
        1,
      );
    });
  });

  group('platform hosts', () {
    // A card that gives its Facebook page where a website goes is the norm on
    // a Bangladeshi shop card, not an edge case.
    test('a platform host is not a business domain', () {
      expect(isPlatformDomain('youtube.com'), isTrue);
      expect(isPlatformDomain('facebook.com'), isTrue);
      expect(isPlatformDomain('wa.me'), isTrue);
      expect(isPlatformDomain('gmail.com'), isTrue);
    });

    test('subdomains of one count too', () {
      // The extractor keeps the host as printed, only stripping `www.`.
      expect(isPlatformDomain('m.facebook.com'), isTrue);
      expect(isPlatformDomain('sites.google.com'), isTrue);
    });

    test("a business's own domain is left alone", () {
      expect(isPlatformDomain('azadfisheries.com.bd'), isFalse);
      expect(isPlatformDomain('olympushospital.com'), isFalse);
      // A name that merely contains a platform's is not that platform.
      expect(isPlatformDomain('myfacebookrepairs.com'), isFalse);
    });

    test('nothing is not a platform', () {
      expect(isPlatformDomain(null), isFalse);
      expect(isPlatformDomain(''), isFalse);
    });

    test('only a real domain survives as an identity', () {
      expect(identityDomain('azadfisheries.com.bd'), 'azadfisheries.com.bd');
      // Null, not dropped from the card — the URL is still worth tapping, it
      // just says nothing about which company this is.
      expect(identityDomain('youtube.com'), isNull);
    });
  });

  group('matching organizations on a domain', () {
    test('a shared business domain links them', () {
      expect(
        scoreOrganization(
          cardDomain: 'azadfisheries.com.bd',
          candidateDomain: 'azadfisheries.com.bd',
          cardName: 'Azad Fisheries',
          candidateName: 'Azad Fisheries Ltd',
        ).score,
        1.0,
      );
    });

    test('a shared platform host links nothing', () {
      // Two unrelated shops that both printed a Facebook page. Scoring this
      // 1.0 merged them with no prompt, because a domain match links outright.
      final MatchVerdict v = scoreOrganization(
        cardDomain: 'facebook.com',
        candidateDomain: 'facebook.com',
        cardName: 'Azad Fisheries',
        candidateName: 'Karim Electronics',
      );

      expect(v.score, lessThan(MatchVerdict.proposeThreshold));
      expect(v.signals, isEmpty);
    });
  });

  group('matching organizations on an address', () {
    // The pair found on the phone: two demo cards, two unrelated businesses a
    // few roads apart, proposed as one company "matched on the same address".
    // The words agree and only the road number differs — which a string
    // measure weighs at one token in four, and which is the whole address.
    test('Road 11 and Road 5 in one area are two addresses', () {
      expect(
        isSameAddress('Road 11, Banani, Dhaka', 'Road 5, Banani, Dhaka'),
        isFalse,
      );

      final MatchVerdict v = scoreOrganization(
        cardDomain: null,
        candidateDomain: null,
        cardName: 'Bengal Event Solutions',
        candidateName: 'Moments Studio',
        cardAddress: 'Road 11, Banani, Dhaka',
        candidateAddress: 'Road 5, Banani, Dhaka',
      );
      expect(v.signals, isNot(contains('the same address')));
      expect(v.score, lessThan(MatchVerdict.proposeThreshold),
          reason: 'two different names on two different roads are not a '
              'question worth asking');
    });

    test('the same address printed twice is the same address', () {
      expect(
        isSameAddress('House 7, Road 2, Banani, Dhaka',
            'House 7, Road 2, Banani, Dhaka'),
        isTrue,
      );
      // Punctuation, case and zero-padding are how it was printed, not where.
      expect(
        isSameAddress('House#7, Road-02, BANANI', 'house 7 road 2 banani'),
        isTrue,
      );
    });

    test('OCR damage to the words does not split one address', () {
      expect(
        isSameAddress('House 12, Road 5, Sector 7, Uttara, Dhaka',
            'House 12, Road 5, Sector 7, Utara, Dhaka'),
        isTrue,
      );
      // The two reads of one shop sign that motivated address matching.
      expect(
        isSameAddress(
            'Shop No:300, Dhaka New Market', 'O Shop No:300, Dhaka New Markel'),
        isTrue,
      );
    });

    test('the same numbers in another order are another door', () {
      // House 7 on Road 2 and House 2 on Road 7: nothing but the order says
      // which number is the house.
      expect(
        isSameAddress('House 7, Road 2, Banani', 'House 2, Road 7, Banani'),
        isFalse,
      );
    });

    test('a number missing from one of them is not the same door', () {
      expect(
        isSameAddress('Road 11, Banani', 'House 5, Road 11, Banani'),
        isFalse,
      );
    });

    test('Bangla numerals are the numbers they write', () {
      // Stripped as punctuation, `রোড ১১` and `রোড ৫` were both nothing, and
      // any two addresses on one street were the same address.
      expect(isSameAddress('Road ১১, Banani', 'Road 11, Banani'), isTrue);
      expect(isSameAddress('Road ১১, Banani', 'Road ৫, Banani'), isFalse);
    });

    test('an area with no number is not a door', () {
      // Every business in Banani is in "Banani, Dhaka".
      expect(isSameAddress('Banani, Dhaka', 'Banani, Dhaka'), isFalse);
    });

    test('numbers with no words beside them are not an address', () {
      expect(isSameAddress('11/2', '11/2'), isFalse);
      expect(isSameAddress(null, 'Road 11, Banani'), isFalse);
    });

    test('similar names on neighbouring roads are asked about, not linked', () {
      // Under the old rule the address "matched", and a similar name plus the
      // same address scored 0.95 — over the link threshold, so two businesses
      // were joined without anybody being asked.
      final MatchVerdict v = scoreOrganization(
        cardDomain: null,
        candidateDomain: null,
        cardName: 'Pixel Studio',
        candidateName: 'Pixel Studios',
        cardAddress: 'House 7, Road 2, Banani, Dhaka',
        candidateAddress: 'House 9, Road 2, Banani, Dhaka',
      );

      expect(v.score, lessThan(MatchVerdict.linkThreshold),
          reason: 'nothing merges without the user');
      expect(v.score, greaterThanOrEqualTo(MatchVerdict.proposeThreshold),
          reason: 'the similar name is still worth asking about');
      expect(v.signals, <String>['a similar name']);
    });

    test('a similar name at the same door still links', () {
      final MatchVerdict v = scoreOrganization(
        cardDomain: null,
        candidateDomain: null,
        cardName: 'TARGET, CENTER,',
        candidateName: 'CTARGEI. CENTER',
        cardAddress: 'Shop No:300, Dhaka New Market',
        candidateAddress: 'O Shop No:300, Dhaka New Markel',
      );
      expect(v.score, greaterThanOrEqualTo(MatchVerdict.linkThreshold));
      expect(v.signals, contains('the same address'));
    });
  });
}
