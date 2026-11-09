import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:recallos/core/extraction/card_extractor.dart';
import 'package:recallos/core/extraction/document_lines.dart';
import 'package:recallos/core/intelligence/ocr_engine.dart';

import '../support/ocr_layout.dart';

/// Builds a block laid out like a line of text on a card.
///
/// `height` stands in for font size, which is the signal the name/company
/// heuristic actually uses.
OcrBlock block(
  String text, {
  double top = 0,
  double height = 20,
  double confidence = 0.9,
  Script script = Script.latin,
}) {
  return OcrBlock(
    text: text,
    rect: Rect.fromLTWH(10, top, 300, height),
    confidence: confidence,
    script: script,
  );
}

void main() {
  group('CardFieldExtractor — a well-formed card', () {
    late CardExtraction result;

    setUp(() {
      result = CardFieldExtractor.extract(<OcrBlock>[
        block('Medica Books Ltd', top: 10, height: 34),
        block('Rahim Uddin', top: 60, height: 26),
        block('Senior Sales Manager', top: 92, height: 16),
        block('Mob: 01711-223344', top: 120, height: 16),
        block('info@medicabooks.com.bd', top: 142, height: 16),
        block('www.medicabooks.com.bd', top: 164, height: 16),
        block('House 42, Road 7, Dhanmondi, Dhaka', top: 186, height: 16),
      ]);
    });

    test('finds the phone and normalises it', () {
      final ExtractedField? phone = result.firstOfKey(FieldKeys.phone);
      expect(phone, isNotNull);
      expect(phone!.normalizedValue, '+8801711223344');
    });

    test('finds the email and the website without confusing them', () {
      expect(
        result.firstOfKey(FieldKeys.email)?.normalizedValue,
        'info@medicabooks.com.bd',
      );
      expect(
        result.firstOfKey(FieldKeys.website)?.normalizedValue,
        'medicabooks.com.bd',
      );
    });

    test('separates the person from the organization', () {
      expect(result.firstOfKey(FieldKeys.personName)?.value, 'Rahim Uddin');
      expect(result.firstOfKey(FieldKeys.company)?.value, 'Medica Books Ltd');
    });

    test('reads the designation', () {
      expect(
        result.firstOfKey(FieldKeys.designation)?.value,
        'Senior Sales Manager',
      );
    });

    test('joins the address', () {
      expect(
        result.firstOfKey(FieldKeys.address)?.value,
        contains('Dhanmondi'),
      );
    });

    test('every field carries the region it came from', () {
      for (final ExtractedField f in result.fields) {
        expect(f.regionRect, isNotNull, reason: '${f.fieldKey} lost its rect');
        expect(f.regionRect, matches(RegExp(r'^\d+,\d+,\d+,\d+$')));
      }
    });

    test('counts as useful', () {
      expect(result.isUseful, isTrue);
      expect(result.unassignedBlockIndices, isEmpty);
    });
  });

  group('CardFieldExtractor — the Bengali card case', () {
    // The important one. ML Kit cannot read Bengali, so the company name comes
    // back as unreadable — but phone, email and website are Latin on nearly
    // every Bangladeshi card, so the valuable fields still land.
    test('still extracts contact details when the Bengali name is lost', () {
      final CardExtraction result = CardFieldExtractor.extract(<OcrBlock>[
        block('', top: 10, height: 34, script: Script.bengali, confidence: 0.2),
        block('Rahim Uddin', top: 60, height: 26),
        block('01711-223344', top: 120, height: 16),
        block('info@medicabooks.com.bd', top: 142, height: 16),
      ]);

      expect(
        result.firstOfKey(FieldKeys.phone)?.normalizedValue,
        '+8801711223344',
      );
      expect(result.firstOfKey(FieldKeys.email), isNotNull);
      expect(result.isUseful, isTrue);
    });

    test('matches a company line against its own domain', () {
      final CardExtraction result = CardFieldExtractor.extract(<OcrBlock>[
        block('Medica Books', top: 10, height: 30),
        block('Rahim Uddin', top: 50, height: 28),
        block('info@medicabooks.com.bd', top: 100, height: 16),
      ]);

      // "Medica Books" has no Ltd/Traders suffix; the domain is what identifies
      // it as the organization.
      expect(result.firstOfKey(FieldKeys.company)?.value, 'Medica Books');
      expect(result.firstOfKey(FieldKeys.personName)?.value, 'Rahim Uddin');
    });
  });

  group('CardFieldExtractor — failure and recovery', () {
    test('an empty card yields an empty extraction rather than throwing', () {
      final CardExtraction result = CardFieldExtractor.extract(
        const <OcrBlock>[],
      );

      expect(result.isEmpty, isTrue);
      expect(result.isUseful, isFalse);
      expect(result.unassignedBlockIndices, isEmpty);
    });

    test('unclaimed blocks are offered for tap-to-assign', () {
      final CardExtraction result = CardFieldExtractor.extract(<OcrBlock>[
        block('Rahim Uddin', top: 10, height: 30),
        block('Medica Books Ltd', top: 50, height: 28),
        // Neither pattern nor keyword claims these.
        block('Est. 1998', top: 100, height: 14),
        block('Quality Guaranteed', top: 120, height: 14),
      ]);

      expect(result.unassignedBlockIndices, isNotEmpty);
      expect(result.unassignedBlockIndices, containsAll(<int>[2, 3]));
    });

    test('a card with only a phone number is still useful', () {
      final CardExtraction result = CardFieldExtractor.extract(<OcrBlock>[
        block('01711-223344', top: 10, height: 20),
      ]);
      expect(result.isUseful, isTrue);
    });

    test('low OCR confidence carries through to the field', () {
      final CardExtraction result = CardFieldExtractor.extract(<OcrBlock>[
        block('01711-223344', top: 10, height: 20, confidence: 0.35),
      ]);
      expect(result.firstOfKey(FieldKeys.phone)!.confidence, lessThan(0.5));
    });

    test('unknown OCR confidence is treated as middling, not as certain', () {
      final CardExtraction result = CardFieldExtractor.extract(<OcrBlock>[
        block(
          '01711-223344',
          top: 10,
          height: 20,
          confidence: OcrBlock.confidenceUnknown,
        ),
      ]);
      final double c = result.firstOfKey(FieldKeys.phone)!.confidence;
      expect(c, lessThan(1.0));
      expect(c, greaterThan(0.0));
    });
  });

  group('CardFieldExtractor — cross-field checks', () {
    test('flags a name identical to the company', () {
      final CardExtraction result = CardFieldExtractor.extract(<OcrBlock>[
        block('Medica Books Ltd', top: 10, height: 30),
        block('Medica Books Ltd', top: 50, height: 28),
        block('01711-223344', top: 90, height: 16),
      ]);

      final ExtractedField? name = result.firstOfKey(FieldKeys.personName);
      if (name != null) {
        expect(name.issue, 'same_as_company');
        expect(name.needsReview, isTrue);
      }
    });

    test('flags a name that is really an address line', () {
      final CardExtraction result = CardFieldExtractor.extract(<OcrBlock>[
        block('House 42, Dhanmondi', top: 10, height: 30),
        block('01711-223344', top: 60, height: 16),
      ]);

      final ExtractedField? name = result.firstOfKey(FieldKeys.personName);
      // Either the address rule claimed it, or the name rule flagged it. What
      // must not happen is it being presented as a confident person name.
      if (name != null) {
        expect(name.needsReview, isTrue);
      }
    });

    test('does not mistake a company containing "MD" for a designation', () {
      // Whole-word matching is what keeps "Mdina" from reading as "MD".
      final CardExtraction result = CardFieldExtractor.extract(<OcrBlock>[
        block('Mdina Traders', top: 10, height: 30),
        block('01711-223344', top: 60, height: 16),
      ]);
      expect(result.firstOfKey(FieldKeys.designation), isNull);
    });
  });

  group('CardFieldExtractor — multiple values', () {
    test('keeps every distinct phone number on the card', () {
      final CardExtraction result = CardFieldExtractor.extract(<OcrBlock>[
        block('Rahim Uddin', top: 10, height: 30),
        block('Office: 01711-223344', top: 60, height: 16),
        block('Cell: 01911-556677', top: 82, height: 16),
      ]);

      final List<String?> numbers = result
          .ofKey(FieldKeys.phone)
          .map((ExtractedField f) => f.normalizedValue)
          .toList();
      expect(numbers, hasLength(2));
      expect(
        numbers,
        containsAll(<String>['+8801711223344', '+8801911556677']),
      );
    });

    test('collapses the same number written twice', () {
      final CardExtraction result = CardFieldExtractor.extract(<OcrBlock>[
        block('Cell: 01711-223344', top: 10, height: 16),
        block('WhatsApp: +880 1711 223344', top: 32, height: 16),
      ]);
      expect(result.ofKey(FieldKeys.phone), hasLength(1));
    });
  });

  // "Provenance travels with every fact": a number printed in international
  // form and shown in national form is still the number on the card. Only a
  // digit the card never carried is an inference.
  group('CardFieldExtractor — reformatted versus restored phones', () {
    ExtractedField phoneFrom(String line) => CardFieldExtractor.extract(
      <OcrBlock>[block(line, top: 10, height: 16)],
    ).firstOfKey(FieldKeys.phone)!;

    test('an international print shown nationally is not a restoration', () {
      final ExtractedField phone = phoneFrom('+880 1711-223344');

      expect(phone.value, '01711223344');
      expect(phone.normalizedValue, '+8801711223344');
      expect(phone.issue, isNull);
      expect(phone.needsReview, isFalse);
      // What the card printed survives next to the display form.
      expect(phone.rawText, '+880 1711-223344');
    });

    test('a lost leading zero is restored and flagged for review', () {
      final ExtractedField phone = phoneFrom('1711223344');

      expect(phone.value, '01711223344');
      expect(phone.normalizedValue, '+8801711223344');
      expect(phone.issue, 'digit_restored');
      expect(phone.needsReview, isTrue);
      expect(phone.rawText, '1711223344');
    });

    test('a local number with separators is not a restoration', () {
      final ExtractedField phone = phoneFrom('01711-223344');

      expect(phone.value, '01711223344');
      expect(phone.issue, isNull);
      expect(phone.needsReview, isFalse);
      expect(phone.rawText, '01711-223344');
    });
  });

  // A brand word set large over a smaller descriptor is one business name
  // printed as two lines. Read separately, the keyword test picks the
  // descriptor as the company — it beats the size ranking outright — and the
  // brand is then left over to be filed as a person. Both facts come out wrong.
  group('CardFieldExtractor — stacked logotype', () {
    test('reads a brand over its descriptor as one company', () {
      final CardExtraction result = CardFieldExtractor.extract(<OcrBlock>[
        block('AQUARIUS', top: 10, height: 40),
        block('Pet Shop', top: 56, height: 18),
        block('01711-223344', top: 100, height: 16),
        block('Shop 12, Mirpur, Dhaka', top: 122, height: 16),
      ]);

      expect(result.firstOfKey(FieldKeys.company)?.value, 'AQUARIUS Pet Shop');
    });

    test('invents no person from the brand word', () {
      final CardExtraction result = CardFieldExtractor.extract(<OcrBlock>[
        block('AQUARIUS', top: 10, height: 40),
        block('Pet Shop', top: 56, height: 18),
        block('01711-223344', top: 100, height: 16),
      ]);

      expect(result.firstOfKey(FieldKeys.personName), isNull);
    });

    test('marks every merged block as claimed', () {
      final CardExtraction result = CardFieldExtractor.extract(<OcrBlock>[
        block('AQUARIUS', top: 10, height: 40),
        block('Pet Shop', top: 56, height: 18),
      ]);

      // Both lines belong to the company, so neither may resurface as
      // unassigned text or the detail screen shows the name twice.
      expect(result.firstOfKey(FieldKeys.company)?.sourceBlockIndices, <int>[
        0,
        1,
      ]);
      expect(result.unassignedBlockIndices, isEmpty);
    });

    test('leaves a person above their employer alone', () {
      // The same vertical arrangement, but the two lines are set at similar
      // weights — peers rather than a logotype and its descriptor.
      final CardExtraction result = CardFieldExtractor.extract(<OcrBlock>[
        block('Rahim Uddin', top: 10, height: 30),
        block('Medica Books Ltd', top: 50, height: 28),
        block('01711-223344', top: 90, height: 16),
      ]);

      expect(result.firstOfKey(FieldKeys.company)?.value, 'Medica Books Ltd');
      expect(result.firstOfKey(FieldKeys.personName)?.value, 'Rahim Uddin');
    });

    test(
      'leaves a small company line alone when a job title names a person',
      () {
        // Descriptor-sized company under a large name, which would otherwise
        // merge — except the designation proves a human is on this card.
        final CardExtraction result = CardFieldExtractor.extract(<OcrBlock>[
          block('MD. KARIM', top: 10, height: 40),
          block('Karim Traders Ltd', top: 56, height: 18),
          block('Proprietor', top: 80, height: 14),
          block('01711-223344', top: 110, height: 16),
        ]);

        expect(
          result.firstOfKey(FieldKeys.company)?.value,
          'Karim Traders Ltd',
        );
        expect(result.firstOfKey(FieldKeys.personName)?.value, 'MD. KARIM');
      },
    );

    test('does not join lines set far apart', () {
      final CardExtraction result = CardFieldExtractor.extract(<OcrBlock>[
        block('AQUARIUS', top: 10, height: 40),
        // Half the card away — a separate piece of information, not a subtitle.
        block('Pet Shop', top: 220, height: 18),
        block('01711-223344', top: 260, height: 16),
      ]);

      expect(
        result.firstOfKey(FieldKeys.company)?.value,
        isNot(contains('AQUARIUS')),
      );
    });
  });

  // A shop card is a brand, a line about the trade, a number and an address.
  // A company keyword in the brand ("Centre") says the business is known; it
  // says nothing about a human being, and must not turn the line under it into
  // one.
  group('CardFieldExtractor — shop card with a tagline', () {
    List<OcrBlock> shopCard(String tagline) => <OcrBlock>[
      block('TechFix Repair Centre', top: 10, height: 60),
      block(tagline, top: 80, height: 26),
      block('+880 1617-223311', top: 116, height: 28),
      block('Shop 14, Elephant Road, Dhaka', top: 154, height: 28),
    ];

    for (final String tagline in <String>[
      'Laptop and Mobile Servicing',
      'Repair and servicing since 2012',
      'All brands repaired',
      'Laptop, mobile and printer repair',
      'Open 10am to 9pm',
    ]) {
      test('invents no person from "$tagline"', () {
        final CardExtraction result = CardFieldExtractor.extract(
          shopCard(tagline),
        );

        expect(result.firstOfKey(FieldKeys.personName), isNull);
        expect(
          result.firstOfKey(FieldKeys.company)?.value,
          'TechFix Repair Centre',
        );
        // Not lost either: the line stays in the tap-to-assign picker.
        expect(result.unassignedBlockIndices, <int>[1]);
      });
    }

    test('invents no person from a card with no tagline', () {
      final CardExtraction result = CardFieldExtractor.extract(<OcrBlock>[
        block('TechFix Repair Centre', top: 10, height: 60),
        block('+880 1617-223311', top: 80, height: 28),
        block('www.techfixbd.com', top: 116, height: 28),
        block('Shop 14, Elephant Road, Dhaka', top: 154, height: 28),
      ]);

      expect(result.firstOfKey(FieldKeys.personName), isNull);
    });

    test('a tagline set as large as the brand is still not a person', () {
      // Weight cannot tell these apart; the words can. Names do not carry
      // conjunctions or years.
      final CardExtraction result = CardFieldExtractor.extract(<OcrBlock>[
        block('TechFix Repair Centre', top: 10, height: 30),
        block('Repair and servicing since 2012', top: 48, height: 28),
        block('+880 1617-223311', top: 90, height: 16),
      ]);

      expect(result.firstOfKey(FieldKeys.personName), isNull);
    });

    test('a descriptor set well under the brand is not a person', () {
      // Title case, no connectives — shaped like a name. Only its size says it
      // is a line about the shop rather than a peer of it.
      final CardExtraction result = CardFieldExtractor.extract(
        shopCard('Genuine Spare Parts'),
      );

      expect(result.firstOfKey(FieldKeys.personName), isNull);
    });

    test('a tagline is not a person even when a job title is on the card', () {
      // The owner's name is in Bengali and unreadable, so the title proves a
      // person exists but the only Latin line left over is the tagline.
      final CardExtraction result = CardFieldExtractor.extract(<OcrBlock>[
        block('', top: 0, height: 30, script: Script.bengali, confidence: 0.2),
        block('TechFix Repair Centre', top: 40, height: 40),
        block('Laptop and Mobile Servicing', top: 86, height: 20),
        block('Proprietor', top: 112, height: 14),
        block('01617-223311', top: 132, height: 14),
      ]);

      expect(result.firstOfKey(FieldKeys.designation)?.value, 'Proprietor');
      expect(result.firstOfKey(FieldKeys.personName), isNull);
    });

    test(
      'a person named under their employer still counts, without a title',
      () {
        // The ordinary spread between a name and the company it works for — the
        // same weights as the well-formed card above, minus its job title.
        final CardExtraction result = CardFieldExtractor.extract(<OcrBlock>[
          block('Medica Books Ltd', top: 10, height: 34),
          block('Rahim Uddin', top: 60, height: 26),
          block('01711-223344', top: 100, height: 16),
          block('House 42, Road 7, Dhanmondi, Dhaka', top: 122, height: 16),
        ]);

        expect(result.firstOfKey(FieldKeys.company)?.value, 'Medica Books Ltd');
        expect(result.firstOfKey(FieldKeys.personName)?.value, 'Rahim Uddin');
      },
    );

    test('a name set smaller still counts, without a title or email', () {
      final CardExtraction result = CardFieldExtractor.extract(<OcrBlock>[
        block('Acme Trading', top: 10, height: 30),
        block('Kamal Hossain', top: 55, height: 22),
        block('01711-223344', top: 90, height: 14),
      ]);

      expect(result.firstOfKey(FieldKeys.personName)?.value, 'Kamal Hossain');
    });
  });

  // Businesses across Bangladesh are named after where they are. A place word
  // in the card's headline type is part of the name, not the address.
  group('CardFieldExtractor — brand named after a place', () {
    test('keeps the brand out of the address', () {
      final CardExtraction result = CardFieldExtractor.extract(<OcrBlock>[
        block('Dhaka Tech Repair', top: 10, height: 60),
        block('Laptop and Mobile Servicing', top: 80, height: 26),
        block('+880 1617-223311', top: 116, height: 28),
        block('Shop 14, Elephant Road, Dhaka', top: 154, height: 28),
      ]);

      expect(result.firstOfKey(FieldKeys.company)?.value, 'Dhaka Tech Repair');
      expect(
        result.firstOfKey(FieldKeys.address)?.value,
        'Shop 14, Elephant Road, Dhaka',
      );
      expect(result.firstOfKey(FieldKeys.personName), isNull);
    });

    test('still reads a unit number in headline type as the address', () {
      final CardExtraction result = CardFieldExtractor.extract(<OcrBlock>[
        block('House 42, Dhanmondi', top: 10, height: 30),
        block('01711-223344', top: 60, height: 16),
      ]);

      expect(
        result.firstOfKey(FieldKeys.address)?.value,
        'House 42, Dhanmondi',
      );
    });

    test('still reads the address on a card set all in one size', () {
      // No headline, so nothing is exempt: every line is as prominent as the
      // brand, and a place word keeps meaning an address.
      final CardExtraction result = CardFieldExtractor.extract(<OcrBlock>[
        block('Acme Traders', top: 10, height: 20),
        block('Gulshan Avenue', top: 36, height: 20),
        block('Dhaka', top: 62, height: 20),
        block('01711-223344', top: 88, height: 20),
      ]);

      expect(
        result.firstOfKey(FieldKeys.address)?.value,
        'Gulshan Avenue, Dhaka',
      );
      expect(result.firstOfKey(FieldKeys.company)?.value, 'Acme Traders');
    });
  });

  // Found 21 Oct on a rendered card: "House" (as in "House 7") and "Dhaka"
  // are address words, so a company called "Dhaka Print House" was joined
  // onto the address, and with no company line left the person's name was
  // promoted to company.
  group('CardFieldExtractor — a company named "… House"', () {
    test('a person-first card keeps the name, the title and the company', () {
      final CardExtraction result = CardFieldExtractor.extract(<OcrBlock>[
        block('Farhana Akter', top: 10, height: 34),
        block('Sales Lead', top: 52, height: 16),
        block('Dhaka Print House', top: 76, height: 22),
        block('01711-223344', top: 108, height: 16),
        block('House 12, Road 5, Mirpur, Dhaka', top: 130, height: 16),
      ]);

      expect(result.firstOfKey(FieldKeys.personName)?.value, 'Farhana Akter');
      expect(result.firstOfKey(FieldKeys.designation)?.value, 'Sales Lead');
      expect(result.firstOfKey(FieldKeys.company)?.value, 'Dhaka Print House');
      expect(
        result.firstOfKey(FieldKeys.address)?.value,
        'House 12, Road 5, Mirpur, Dhaka',
      );
    });

    test('without a job title, the person is still not the company', () {
      final CardExtraction result = CardFieldExtractor.extract(<OcrBlock>[
        block('Farhana Akter', top: 10, height: 30),
        block('Gulshan Fashion House', top: 50, height: 26),
        block('01711-223344', top: 86, height: 16),
      ]);

      expect(
        result.firstOfKey(FieldKeys.company)?.value,
        'Gulshan Fashion House',
      );
      expect(result.firstOfKey(FieldKeys.personName)?.value, 'Farhana Akter');
      expect(result.firstOfKey(FieldKeys.address), isNull);
    });

    test('a place-named business under its person is a company', () {
      final CardExtraction result = CardFieldExtractor.extract(<OcrBlock>[
        block('Dr. Kamal Hossain', top: 10, height: 30),
        block('Gulshan Pharmacy', top: 50, height: 24),
        block('01711-223344', top: 84, height: 16),
      ]);

      expect(result.firstOfKey(FieldKeys.company)?.value, 'Gulshan Pharmacy');
      expect(result.firstOfKey(FieldKeys.address), isNull);
    });

    test('addresses that look like it are still addresses', () {
      for (final String address in <String>[
        'House 7, Dhanmondi',
        'House 12, Road 5, Mirpur, Dhaka',
        'Print House, Dhaka',
        'Gulshan Avenue',
        'Banani Road 11',
        'Mirpur-1216',
        'Dhaka',
      ]) {
        expect(
          CardFieldExtractor.looksLikeAddress(address),
          isTrue,
          reason: address,
        );
      }
      for (final String business in <String>[
        'Dhaka Print House',
        'Gulshan Fashion House',
        'Gulshan Pharmacy',
        'Uttara Traders Ltd.',
      ]) {
        expect(
          CardFieldExtractor.looksLikeAddress(business),
          isFalse,
          reason: business,
        );
        expect(CardFieldExtractor.namesABusiness(business), isTrue);
      }
    });
  });

  group('a capital I read as a small l', () {
    String? value(CardExtraction e, String key) => e.firstOfKey(key)?.value;
    CardExtraction read(List<Object> rows) =>
        CardFieldExtractor.extract(paper(rows));

    test('the name is kept, and spelled right', () {
      final CardExtraction e = read(<Object>[
        'Rafiq lslam',
        'Marketing Director',
        'Bengal Esports Ltd',
        'rafiq@bengalesports.example',
      ]);
      expect(value(e, FieldKeys.personName), 'Rafiq Islam');
    });

    test('other names that start with I', () {
      for (final (String read_, String name) in <(String, String)>[
        ('Mohammad lqbal', 'Mohammad Iqbal'),
        ('lmran Hossain', 'Imran Hossain'),
        ('lbrahim Khalil', 'Ibrahim Khalil'),
        ('Sadia lsmail', 'Sadia Ismail'),
      ]) {
        final CardExtraction e = read(<Object>[
          read_,
          'Manager',
          'Acme Ltd',
          'x@acme.example',
        ]);
        expect(value(e, FieldKeys.personName), name);
      }
    });

    test('a company keyword is matched once repaired', () {
      expect(
        read(<Object>[
          'lspahani lndustries',
          '+880 1711 555 012',
        ]).firstOfKey(FieldKeys.company)?.value,
        'Ispahani Industries',
      );
    });

    test('what is really an l stays one', () {
      expect(repairLeadingI('Lloyd lbs ltd lamp'), 'Lloyd lbs ltd lamp');
      expect(repairLeadingI('llama'), 'llama');
    });

    test('an address is left as it was read', () {
      expect(repairLeadingI('lmran@acme.example'), 'lmran@acme.example');
      expect(repairLeadingI('www.lmnop.example'), 'www.lmnop.example');
      expect(repairLeadingI('lmnop.example'), 'lmnop.example');
    });
  });
}
