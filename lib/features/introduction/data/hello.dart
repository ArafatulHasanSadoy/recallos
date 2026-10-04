/// "Say hello": the first message after meeting somebody, written from what
/// the wallet already knows and handed to the app that sends it.
///
/// Pure — no database, no plugin — so the wording and the links are tested
/// directly. Nothing here is generated: the message is a fixed sentence with
/// the user's own facts slotted in, shown in full and editable before it goes
/// anywhere, and RecallOS never sends it. It opens WhatsApp, Messages or a
/// mail app with the words in place, and the user presses send there.
library;

import '../../../core/ui/day_words.dart';

/// The apps a hello can be opened in.
enum HelloChannel {
  whatsapp('WhatsApp', 'in WhatsApp', 'for WhatsApp'),
  sms('SMS', 'as a text message', 'as a text message'),
  email('Email', 'as an email', 'as an email');

  const HelloChannel(this.label, this._opens, this.written);

  /// The chip.
  final String label;

  final String _opens;

  /// What the card says afterwards: "Hello written for WhatsApp".
  ///
  /// Written, not opened and never sent. Android may put up an "Open with"
  /// chooser between RecallOS and the app — found on the phone, where both
  /// Messages and WhatsApp take text-message links — and someone who backs
  /// out of it has opened nothing. That they wrote it and handed it on is
  /// the one thing that is true in every case.
  final String written;

  /// The button: "open", never "send", because sending happens elsewhere.
  String get action => 'Open $_opens';
}

/// Where a hello can go for one card.
class HelloReach {
  const HelloReach({this.mobile, this.email});

  /// A mobile number in E.164, for WhatsApp and SMS. A landline can take
  /// neither, and offering them would open an error.
  final String? mobile;
  final String? email;

  List<HelloChannel> get channels => <HelloChannel>[
    if (mobile != null) ...<HelloChannel>[
      HelloChannel.whatsapp,
      HelloChannel.sms,
    ],
    if (email != null) HelloChannel.email,
  ];

  bool get isEmpty => channels.isEmpty;
}

/// The message, before the user changes a word of it.
///
/// "Hi Nusrat, great meeting you at CSE fest at NSU on 29 Sep. This is
/// Arafat from RecallOS. Looking forward to staying in touch."
///
/// Each part is left out rather than guessed when its fact is missing: no
/// name gives "Hello", no place or day gives a plain "great meeting you", and
/// no card of the user's own leaves the message unsigned. The private note —
/// why the user kept the card — is never used; it was written for them, not
/// for the person.
String helloMessage({
  required DateTime now,
  String? theirName,
  String? place,
  DateTime? metOn,
  String? myName,
  String? myCompany,
}) {
  final String? them = theirName == null ? null : greetingName(theirName);
  final String? where = _clean(place);
  final String? when = metOn == null ? null : _metWords(metOn, now);

  final StringBuffer out = StringBuffer(them == null ? 'Hello' : 'Hi $them')
    ..write(', great meeting you');
  if (where != null) out.write(' at $where');
  if (when != null) out.write(' $when');
  out.write('.');

  final String? me = _clean(myName);
  if (me != null) {
    final String? company = _clean(myCompany);
    out.write(' This is $me${company == null ? '' : ' from $company'}.');
  }
  out.write(' Looking forward to staying in touch.');
  return out.toString();
}

/// The email subject, for the one channel that has one.
const String helloSubject = 'Great meeting you';

/// What to call somebody in a first message.
///
/// The first given name, which is how a hello reads in Bangladesh as
/// elsewhere — but a leading "Md." or "Mohammad" is a prefix, not what the
/// person is called, so it is passed over. A professional title stays with
/// the name it belongs to ("Dr. Ahsan"). A name printed in capitals is set in
/// ordinary case, or the greeting shouts. The user sees and can change all of
/// it; this only has to be a sensible first draft.
String? greetingName(String fullName) {
  final List<String> parts = fullName
      .trim()
      .split(RegExp(r'\s+'))
      .where((String p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return null;

  final bool shouting =
      fullName == fullName.toUpperCase() && fullName != fullName.toLowerCase();
  String tidy(String w) =>
      shouting && w.length > 1 ? '${w[0]}${w.substring(1).toLowerCase()}' : w;

  String? title;
  for (final String p in parts) {
    final String key = p.toLowerCase().replaceAll('.', '');
    if (_prefixes.contains(key)) continue;
    if (_titles.contains(key)) {
      title ??= tidy(p);
      continue;
    }
    return title == null ? tidy(p) : '$title ${tidy(p)}';
  }
  // Nothing but prefixes and titles: say the name as it was given.
  return fullName.trim();
}

/// Opens [text] in [channel], addressed to [to]: a mobile number in E.164 for
/// WhatsApp and SMS, an address for email.
///
/// Every value is percent-encoded by hand. `Uri(queryParameters:)` writes a
/// space as `+`, which is right for a web form and wrong here: SMS and mail
/// apps put the plus signs into the message.
Uri helloUri(HelloChannel channel, {required String to, required String text}) {
  final String body = Uri.encodeComponent(text);
  return switch (channel) {
    // wa.me wants the international number as bare digits.
    HelloChannel.whatsapp => Uri.parse(
      'https://wa.me/${to.replaceAll(RegExp(r'[^0-9]'), '')}?text=$body',
    ),
    HelloChannel.sms => Uri.parse('sms:$to?body=$body'),
    HelloChannel.email => Uri.parse(
      'mailto:$to?subject=${Uri.encodeComponent(helloSubject)}&body=$body',
    ),
  };
}

/// "today", "yesterday", "on Tuesday", "on 29 Sep".
String _metWords(DateTime metOn, DateTime now) {
  final int days = daysFrom(now, metOn);
  if (days == 0) return 'today';
  if (days == -1) return 'yesterday';
  if (days < -1 && days > -7) return 'on ${_weekdays[metOn.weekday - 1]}';
  return 'on ${dayMonth(metOn, now)}';
}

String? _clean(String? s) {
  final String? t = s?.trim();
  return t == null || t.isEmpty ? null : t;
}

const List<String> _weekdays = <String>[
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday', //
];

/// Words that come before a name without being what the person is called.
const Set<String> _prefixes = <String>{
  'md', 'mohammad', 'mohammed', 'muhammad', 'mohd', 'mr', 'mrs', 'ms', 'miss',
  'sk', 'sheikh', //
};

/// Titles that travel with the name.
const Set<String> _titles = <String>{'dr', 'prof', 'engr'};
