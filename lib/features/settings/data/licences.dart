import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The open-source work RecallOS is built on, and the licences it came under.
///
/// Every Dart package's licence reaches [LicenseRegistry] on its own, from the
/// NOTICES file Flutter writes at build time. Three things in the app do not,
/// because they are files copied into `assets/` rather than packages:
///
/// - **Archivo** and **Instrument Serif**, the two bundled fonts. The SIL Open
///   Font License lets them ship inside an app on condition that every copy
///   carries the copyright notice and the licence (its condition 2).
/// - **potion-base-8M**, the embedding table behind meaning-based search,
///   released under the MIT License, which asks the same of every copy.
///
/// [registerBundledLicences] adds them, once, before the app starts. The
/// copyright lines are the ones the font files themselves carry (their `name`
/// table, IDs 0 and 13), not ones written from memory.
void registerBundledLicences() {
  if (_registered) return;
  _registered = true;
  LicenseRegistry.addLicense(bundledLicences);
}

bool _registered = false;

/// The three entries, as a stream [LicenseRegistry] can collect. Public so a
/// test can read exactly what the app registers.
Stream<LicenseEntry> bundledLicences() async* {
  yield const LicenseEntryWithLineBreaks(
    <String>['Archivo'],
    'Copyright 2020 The Archivo Project Authors '
    '(https://github.com/Omnibus-Type/Archivo)\n\n$_oflPreamble$kOflText',
  );
  yield const LicenseEntryWithLineBreaks(
    <String>['Instrument Serif'],
    'Copyright 2022 The Instrument Serif Project Authors '
    '(https://github.com/Instrument/instrument-serif)\n\n'
    '$_oflPreamble$kOflText',
  );
  yield const LicenseEntryWithLineBreaks(<String>[
    'potion-base-8M',
  ], kPotionNotice);
}

const String _oflPreamble =
    'This Font Software is licensed under the SIL Open Font License, '
    'Version 1.1. This license is copied below, and is also available with a '
    'FAQ at: https://openfontlicense.org\n\n';

/// The SIL Open Font License, version 1.1, as published. Each heading is its
/// own paragraph: [LicenseEntryWithLineBreaks] joins single line breaks, and
/// on the phone "PREAMBLE" ran into the sentence under it.
const String kOflText = '''
SIL OPEN FONT LICENSE Version 1.1 - 26 February 2007

PREAMBLE

The goals of the Open Font License (OFL) are to stimulate worldwide development of collaborative font projects, to support the font creation efforts of academic and linguistic communities, and to provide a free and open framework in which fonts may be shared and improved in partnership with others.

The OFL allows the licensed fonts to be used, studied, modified and redistributed freely as long as they are not sold by themselves. The fonts, including any derivative works, can be bundled, embedded, redistributed and/or sold with any software provided that any reserved names are not used by derivative works. The fonts and derivatives, however, cannot be released under any other type of license. The requirement for fonts to remain under this license does not apply to any document created using the fonts or their derivatives.

DEFINITIONS

"Font Software" refers to the set of files released by the Copyright Holder(s) under this license and clearly marked as such. This may include source files, build scripts and documentation.

"Reserved Font Name" refers to any names specified as such after the copyright statement(s).

"Original Version" refers to the collection of Font Software components as distributed by the Copyright Holder(s).

"Modified Version" refers to any derivative made by adding to, deleting, or substituting -- in part or in whole -- any of the components of the Original Version, by changing formats or by porting the Font Software to a new environment.

"Author" refers to any designer, engineer, programmer, technical writer or other person who contributed to the Font Software.

PERMISSION & CONDITIONS

Permission is hereby granted, free of charge, to any person obtaining a copy of the Font Software, to use, study, copy, merge, embed, modify, redistribute, and sell modified and unmodified copies of the Font Software, subject to the following conditions:

1) Neither the Font Software nor any of its individual components, in Original or Modified Versions, may be sold by itself.

2) Original or Modified Versions of the Font Software may be bundled, redistributed and/or sold with any software, provided that each copy contains the above copyright notice and this license. These can be included either as stand-alone text files, human-readable headers or in the appropriate machine-readable metadata fields within text or binary files as long as those fields can be easily viewed by the user.

3) No Modified Version of the Font Software may use the Reserved Font Name(s) unless explicit written permission is granted by the corresponding Copyright Holder. This restriction only applies to the primary font name as presented to the users.

4) The name(s) of the Copyright Holder(s) and the Author(s) of the Font Software shall not be used to promote, endorse or advertise any Modified Version, except to acknowledge the contribution(s) of the Copyright Holder(s) and the Author(s) or with their explicit written permission.

5) The Font Software, modified or unmodified, in part or in whole, must be distributed entirely under this license, and must not be distributed under any other license. The requirement for fonts to remain under this license does not apply to any document created using the Font Software.

TERMINATION

This license becomes null and void if any of the above conditions are not met.

DISCLAIMER

THE FONT SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO ANY WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT OF COPYRIGHT, PATENT, TRADEMARK, OR OTHER RIGHT. IN NO EVENT SHALL THE COPYRIGHT HOLDER BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, INCLUDING ANY GENERAL, SPECIAL, INDIRECT, INCIDENTAL, OR CONSEQUENTIAL DAMAGES, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF THE USE OR INABILITY TO USE THE FONT SOFTWARE OR FROM OTHER DEALINGS IN THE FONT SOFTWARE.''';

/// The embedding table's notice. Its model card gives the licence as MIT and
/// names no copyright line of its own, so none is invented here.
const String kPotionNotice = '''
potion-base-8M, by Minish Lab (https://huggingface.co/minishlab/potion-base-8M), a static distillation of BAAI's bge-base-en-v1.5. RecallOS carries it converted to its own format by tool/embeddings/export_potion.py. Released under the MIT License, as its model card states:

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.''';

/// One piece of work and every licence text it came with.
@immutable
class LicencedWork {
  const LicencedWork(this.name, this.licences);

  final String name;

  /// Each licence as its paragraphs, in the order they were registered.
  final List<List<LicenseParagraph>> licences;
}

/// Groups [entries] by the work each names, A to Z, ignoring case. An entry
/// naming two packages is listed under both, as Flutter's own page does.
Future<List<LicencedWork>> collectLicences(Stream<LicenseEntry> entries) async {
  final Map<String, List<List<LicenseParagraph>>> byName =
      <String, List<List<LicenseParagraph>>>{};
  await for (final LicenseEntry e in entries) {
    final List<LicenseParagraph> paragraphs = e.paragraphs.toList();
    for (final String name in e.packages) {
      (byName[name] ??= <List<LicenseParagraph>>[]).add(paragraphs);
    }
  }
  final List<String> names = byName.keys.toList()
    ..sort((String a, String b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return <LicencedWork>[
    for (final String n in names) LicencedWork(n, byName[n]!),
  ];
}

/// Everything the app ships with, read once from [LicenseRegistry].
final licencesProvider = FutureProvider<List<LicencedWork>>(
  (Ref ref) => collectLicences(LicenseRegistry.licenses),
);
