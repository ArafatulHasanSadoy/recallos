import 'package:flutter_test/flutter_test.dart';
import 'package:recallos/features/introduction/data/hello.dart';

/// A3's words and links, without a screen.
///
/// The message is a fixed sentence with the user's facts slotted in, so every
/// branch is checkable here: what it says with everything known, and what it
/// leaves out — never invents — when a fact is missing.
void main() {
  // Saturday 3 October 2026; 29 September was the Tuesday before.
  final DateTime now = DateTime(2026, 10, 3, 21, 40);

  group('the message', () {
    test('uses their name, where and when you met, and your card', () {
      expect(
        helloMessage(
          now: now,
          theirName: 'Nusrat Jahan',
          place: 'CSE fest at NSU',
          metOn: DateTime(2026, 9, 29),
          myName: 'Arafat Hasan',
          myCompany: 'RecallOS',
        ),
        'Hi Nusrat, great meeting you at CSE fest at NSU on Tuesday. '
        'This is Arafat Hasan from RecallOS. '
        'Looking forward to staying in touch.',
      );
    });

    test('says the day the way a person would', () {
      String met(DateTime d) => helloMessage(now: now, metOn: d);
      expect(met(DateTime(2026, 10, 3)), contains('meeting you today.'));
      expect(met(DateTime(2026, 10, 2)), contains('meeting you yesterday.'));
      expect(met(DateTime(2026, 9, 28)), contains('meeting you on Monday.'));
      expect(met(DateTime(2026, 9, 20)), contains('meeting you on 20 Sep.'));
      expect(met(DateTime(2025, 12, 1)), contains('on 1 Dec 2025.'));
    });

    test('leaves out what it does not know rather than guessing', () {
      expect(
        helloMessage(now: now),
        'Hello, great meeting you. Looking forward to staying in touch.',
      );
      expect(
        helloMessage(now: now, theirName: 'Nusrat Jahan', myName: '  '),
        'Hi Nusrat, great meeting you. Looking forward to staying in touch.',
        reason: 'a blank name on your card is no name',
      );
      expect(
        helloMessage(now: now, myName: 'Arafat Hasan'),
        contains('This is Arafat Hasan.'),
        reason: 'no company, no "from"',
      );
    });
  });

  group('what to call them', () {
    test('the first given name, past a prefix, with a title kept', () {
      expect(greetingName('Nusrat Jahan'), 'Nusrat');
      expect(greetingName('Md. Shafiqul Islam'), 'Shafiqul');
      expect(greetingName('Mohammad Rahim Uddin'), 'Rahim');
      expect(greetingName('Dr. Ahsan Habib'), 'Dr. Ahsan');
      expect(greetingName('Md.'), 'Md.');
    });

    test('a name printed in capitals is not shouted back', () {
      expect(greetingName('KASEL AHMED APON'), 'Kasel');
      expect(greetingName('DR. AHSAN HABIB'), 'Dr. Ahsan');
    });
  });

  group('the links', () {
    const String text = 'Hi Nusrat, tea & talk? 100% — see you';

    test('WhatsApp gets bare digits and the words intact', () {
      final Uri u = helloUri(
        HelloChannel.whatsapp,
        to: '+8801812445566',
        text: text,
      );
      expect(u.host, 'wa.me');
      expect(u.path, '/8801812445566');
      expect(u.queryParameters['text'], text);
    });

    test('SMS and mail never turn spaces into plus signs', () {
      final Uri sms = helloUri(
        HelloChannel.sms,
        to: '+8801812445566',
        text: text,
      );
      expect(sms.scheme, 'sms');
      expect(sms.path, '+8801812445566');
      expect(sms.query, isNot(contains('+')));
      expect(Uri.decodeComponent(sms.query.substring('body='.length)), text);

      final Uri mail = helloUri(
        HelloChannel.email,
        to: 'nusrat@bengalevents.com',
        text: text,
      );
      expect(mail.scheme, 'mailto');
      expect(mail.path, 'nusrat@bengalevents.com');
      expect(mail.query, isNot(contains('+')));
      final Map<String, String> q = <String, String>{
        for (final String kv in mail.query.split('&'))
          kv.split('=').first: Uri.decodeComponent(kv.split('=').last),
      };
      expect(q['subject'], helloSubject);
      expect(q['body'], text);
    });
  });

  test('only the channels a card can take are offered', () {
    expect(const HelloReach().isEmpty, isTrue);
    expect(const HelloReach(email: 'a@b.com').channels, <HelloChannel>[
      HelloChannel.email,
    ]);
    expect(
      const HelloReach(mobile: '+8801812445566', email: 'a@b.com').channels,
      HelloChannel.values,
    );
  });
}
