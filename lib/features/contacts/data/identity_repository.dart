import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/db/enums.dart';
import '../../../core/extraction/card_extractor.dart';
import '../../../core/identity/resolution.dart';
import '../../../core/identity/similarity.dart';
import '../../capture/data/card_repository.dart';

final identityRepositoryProvider = Provider<IdentityRepository>(
  (Ref ref) => IdentityRepository(ref.watch(databaseProvider)),
);

/// Live list of people, most recently seen first.
final peopleProvider = StreamProvider<List<PersonSummary>>(
  (Ref ref) => ref.watch(identityRepositoryProvider).watchPeople(),
);

/// Live list of companies, most recently seen first.
final organizationsProvider = StreamProvider<List<OrgSummary>>(
  (Ref ref) => ref.watch(identityRepositoryProvider).watchOrganizations(),
);

/// One company and everything hanging off it.
final organizationDetailProvider =
    StreamProvider.family<OrgDetail?, int>((Ref ref, int id) {
  return ref.watch(identityRepositoryProvider).watchOrganization(id);
});

/// Pairs the graph thinks might be the same person, still awaiting a verdict.
final duplicateCandidatesProvider = StreamProvider<List<DuplicatePair>>(
  (Ref ref) => ref.watch(identityRepositoryProvider).watchDuplicates(),
);

/// One person and everything hanging off them.
final personDetailProvider =
    StreamProvider.family<PersonDetail?, int>((Ref ref, int id) {
  return ref.watch(identityRepositoryProvider).watchPerson(id);
});

/// A person as a contacts-list row.
class PersonSummary {
  const PersonSummary({
    required this.id,
    required this.displayName,
    required this.cardCount,
    this.subtitle,
  });

  final int id;
  final String displayName;

  /// Their current job, or their most reachable endpoint — whichever exists.
  final String? subtitle;

  /// How many cards mention them. Two or more is the case the identity graph
  /// exists for.
  final int cardCount;
}

/// A company as a contacts-list row.
class OrgSummary {
  const OrgSummary({
    required this.id,
    required this.name,
    required this.cardCount,
    required this.peopleCount,
    this.subtitle,
  });

  final int id;
  final String name;

  /// Its domain or its address — whichever we have.
  final String? subtitle;

  final int cardCount;
  final int peopleCount;
}

/// A person's job at one organization, with the endpoints that belong to it.
class RoleDetail {
  const RoleDetail({
    required this.roleId,
    required this.orgId,
    required this.orgName,
    this.title,
    this.contacts = const <ContactPoint>[],
  });

  final int roleId;
  final int orgId;
  final String orgName;
  final String? title;

  /// The numbers and addresses reached *through this job*. A person with three
  /// businesses has a different set under each, which is the whole reason
  /// roles exist rather than a flat contact table.
  final List<ContactPoint> contacts;
}

class PersonDetail {
  const PersonDetail({
    required this.person,
    required this.roles,
    required this.looseContacts,
    required this.cardIds,
    this.mergedFrom = const <PersonSummary>[],
  });

  final Person person;
  final List<RoleDetail> roles;

  /// Endpoints not tied to any particular job.
  final List<ContactPoint> looseContacts;

  final List<int> cardIds;

  /// Rows the user said were really this person.
  ///
  /// Surfaced so that a merge can be undone. The screen that offers to combine
  /// two contacts promises they can be separated again, and a promise with
  /// nowhere to act on it is worse than not making it.
  final List<PersonSummary> mergedFrom;
}

/// What kind of thing a pair is about.
///
/// Three, because they fail in different ways and the user answers a different
/// question about each: two contacts, two companies, or the same piece of
/// paper photographed twice.
enum DuplicateKind { person, organization, card }

/// One side of a proposed duplicate, in the terms the prompt needs.
class DuplicateSide {
  const DuplicateSide({
    required this.id,
    required this.title,
    this.subtitle,
    this.imagePath,
    this.detail,
  });

  final int id;
  final String title;
  final String? subtitle;

  /// For cards: the picture, which is the only way to tell two scans apart.
  final String? imagePath;

  /// A third line — how many cards, or when it was captured.
  final String? detail;
}

/// Two rows the graph could not tell apart, and why it thinks so.
class DuplicatePair {
  const DuplicatePair({
    required this.id,
    required this.kind,
    required this.a,
    required this.b,
    required this.score,
    required this.signals,
  });

  final int id;
  final DuplicateKind kind;
  final DuplicateSide a;
  final DuplicateSide b;
  final double score;

  /// The signals that fired, so the prompt explains itself rather than
  /// asserting. "Same name" is a very different claim from "same phone".
  final List<String> signals;
}

class OrgDetail {
  const OrgDetail({
    required this.organization,
    required this.branches,
    required this.contacts,
    required this.people,
    required this.cardIds,
  });

  final Organization organization;
  final List<OrgBranch> branches;

  /// Endpoints that belong to the company rather than to any one person —
  /// what a card with a shop name and a number but no legible name leaves.
  final List<ContactPoint> contacts;

  final List<PersonSummary> people;
  final List<int> cardIds;
}

/// Turns extracted card fields into the people, organizations and roles behind
/// them.
///
/// Deliberately a separate repository with its own `backfill`, mirroring
/// `SearchRepository`: promotion is a second projection of the same card rows,
/// it has to be re-runnable over history, and it fails independently of saving
/// a card. A card that cannot be resolved into a person is still a card.
class IdentityRepository {
  IdentityRepository(this._db);

  final AppDatabase _db;

  /// Bumped whenever the matching rules change.
  ///
  /// The graph is derived from card fields, so a change to how names are
  /// compared or what counts as an endpoint makes everything already stored
  /// out of date. Those rules run during promotion and nowhere else, which
  /// means without this a new rule would apply to cards scanned afterwards
  /// and never to the library that already exists — where the duplicates and
  /// the wrong contacts people actually have are sitting.
  /// 4 — a company is no longer created from a website alone, and a platform
  /// host such as `youtube.com` or `facebook.com` no longer counts as one.
  static const int rulesVersion = 4;

  static const String _rulesKey = 'identity_rules_version';

  /// Rebuilds one card's contribution to the graph.
  ///
  /// Idempotent by construction: the card's own `contact_points` rows are
  /// dropped and rewritten, and everything else is find-or-create. That
  /// matters because `attachExtraction` deletes and re-inserts unverified
  /// fields on every re-run — anything that merely appended here would grow a
  /// duplicate endpoint per retry.
  Future<void> promote(int cardId) async {
    final CardFacts facts = await _factsOf(cardId);

    _pendingOrgProposals.clear();
    await _db.transaction(() async {
      // This card's previous claims go first, whatever happens next. A
      // corrected phone number must not leave the old one behind.
      await (_db.delete(_db.contactPoints)
            ..where(($ContactPointsTable c) => c.sourceCardId.equals(cardId)))
          .go();

      if (facts.isEmpty) {
        await _unlink(cardId);
        await _collectGarbage();
        return;
      }

      final int? orgId = await _resolveOrganization(facts);
      final int? personId = await _resolvePerson(facts, cardId);
      final int? roleId = (personId != null && orgId != null)
          ? await _findOrCreateRole(
              personId: personId, orgId: orgId, title: facts.designation)
          : null;

      // Endpoints hang off the person when there is one — with the role that
      // reached them — and off the company otherwise. A card with a name on it
      // is a person's card; the number on it is how you reach *them*, in that
      // job.
      final bool toPerson = personId != null;
      if (toPerson || orgId != null) {
        for (final ContactFact c in facts.contacts) {
          await _db.into(_db.contactPoints).insert(
                ContactPointsCompanion.insert(
                  ownerType: toPerson ? 'person' : 'organization',
                  ownerId: toPerson ? personId : orgId!,
                  kind: c.kind,
                  value: c.value,
                  normalizedValue: Value<String?>(c.normalized),
                  roleId: Value<int?>(roleId),
                  sourceCardId: Value<int?>(cardId),
                  source: c.source,
                ),
              );
        }
      }

      if (orgId != null && facts.address != null) {
        await _findOrCreateBranch(orgId, facts.address!);
      }

      await (_db.update(_db.cards)..where(($CardsTable c) => c.id.equals(cardId)))
          .write(CardsCompanion(
        personId: Value<int?>(personId),
        orgId: Value<int?>(orgId),
        roleId: Value<int?>(roleId),
        updatedAt: Value<DateTime>(DateTime.now()),
      ));

      if (personId != null) await _syncPersonName(personId);
      await _proposeDuplicateCards(cardId, facts,
          personId: personId, orgId: orgId);
      await _collectGarbage();
    });
  }

  /// Drops a card's entities before the card itself goes.
  ///
  /// The `contact_points` cascade would take its rows anyway; this is what
  /// clears the people and organizations that had nothing else holding them
  /// up. Call it *before* deleting the card, while the links still resolve.
  Future<void> detach(int cardId) async {
    await _db.transaction(() async {
      await (_db.delete(_db.contactPoints)
            ..where(($ContactPointsTable c) => c.sourceCardId.equals(cardId)))
          .go();
      await _unlink(cardId);
      await _collectGarbage();
    });
  }

  /// Promotes every card that has never been through this.
  ///
  /// Cards saved before the identity graph was written have fields but no
  /// entities, and would otherwise never appear under Contacts at all — the
  /// same trap `SearchRepository.backfill` exists to avoid.
  Future<void> backfill() async {
    // Also a sweep. Entities are torn down at the point a card is deleted,
    // but that is a call a future delete path could forget; running it here
    // means the worst case is stale rows until the next launch rather than
    // permanently.
    await _collectGarbage();
    await _dropImplausiblePeople();

    // Rules changed since this graph was built: rebuild it rather than leave
    // the old library judged by the old rules and everything after it by the
    // new ones.
    if (await _storedRulesVersion() != rulesVersion) {
      // Re-promoted in place, not unhooked first. Unhooking would take the
      // user's own decisions with it: a merge lives on the rows, but which
      // card belongs to which contact is what makes a merged pair hold
      // together, and rebuilding from nothing re-derives that by name alone.
      // Promotion already drops what the current rules would not produce —
      // a person on a card that names nobody goes on its own — so there is
      // nothing to gain by clearing first and a merge to lose.
      final List<QueryRow> all = await _db
          .customSelect('SELECT id FROM cards WHERE deleted_at IS NULL '
              'ORDER BY captured_at ASC')
          .get();
      for (final QueryRow r in all) {
        await promote(r.read<int>('id'));
      }
      await _db.into(_db.settings).insertOnConflictUpdate(
            SettingsCompanion.insert(
              key: _rulesKey,
              value: rulesVersion.toString(),
            ),
          );
      _notifyGraphChanged();
      return;
    }

    final List<QueryRow> rows = await _db.customSelect(
      'SELECT id FROM cards WHERE deleted_at IS NULL AND ('
      // Never promoted.
      '  (person_id IS NULL AND org_id IS NULL)'
      // Or promoted under rules that have since changed. The graph is a
      // derived projection of card fields, so a rule that tightens what
      // becomes an endpoint leaves rows behind that the current rules could
      // not produce — an endpoint with no canonical form is one such, since
      // validated values always have one. Re-promoting those cards is what
      // stops a tightened rule applying only to cards scanned after it.
      '  OR id IN (SELECT source_card_id FROM contact_points '
      '            WHERE source_card_id IS NOT NULL '
      '            AND normalized_value IS NULL)'
      // Or carrying a company that resolved to no organization. That is the
      // shape a rules change leaves behind, and it is broken on its own
      // terms besides: a card naming a shop should always be reachable from
      // that shop.
      '  OR (org_id IS NULL AND id IN '
      "       (SELECT card_id FROM card_fields WHERE field_key = 'company'))"
      ') ORDER BY captured_at DESC',
    ).get();

    for (final QueryRow row in rows) {
      await promote(row.read<int>('id'));
    }
  }

  /// Removes people made from something that was never a name.
  ///
  /// The rule that stops them being created only runs on promotion, so rows
  /// made before it — a contact called `OE-mgil: targetbrand2015@gm`, taken
  /// off the email row of a shop card — would sit in the address book until
  /// their card happened to be edited. Self-limiting: once they are gone
  /// there is nothing left for it to find.
  Future<void> _dropImplausiblePeople() async {
    final List<Person> everyone = await _db.select(_db.people).get();
    for (final Person p in everyone) {
      if (looksLikePersonName(p.displayName)) continue;
      // Unhook rather than delete outright, and let garbage collection make
      // the call — the row may still be holding a merge together.
      await (_db.update(_db.cards)
            ..where(($CardsTable c) => c.personId.equals(p.id)))
          .write(const CardsCompanion(
        personId: Value<int?>(null),
        roleId: Value<int?>(null),
      ));
      await (_db.delete(_db.contactPoints)
            ..where(($ContactPointsTable c) =>
                c.ownerType.equals('person') & c.ownerId.equals(p.id)))
          .go();
    }
    await _collectGarbage();
    _notifyGraphChanged();
  }

  Future<int?> _storedRulesVersion() async {
    final Setting? row = await (_db.select(_db.settings)
          ..where(($SettingsTable t) => t.key.equals(_rulesKey)))
        .getSingleOrNull();
    return row == null ? null : int.tryParse(row.value);
  }

  // -------------------------------------------------------------------------
  // Resolution
  // -------------------------------------------------------------------------

  /// Finds the organization this card belongs to, or makes one.
  ///
  /// Two scans of one shop sign are the commonest duplicate this app makes, so
  /// the address is weighed alongside the name: OCR damage to a company name
  /// is routine, but two shops do not share a door.
  ///
  /// **A company needs a name off the card.** A website used to be enough, and
  /// the domain became the name — which is how `youtube.com` ended up in the
  /// contacts list as a business, from a fish shop that printed its channel
  /// link. A domain is not a company: at best it is a company's address, at
  /// worst it is a platform's. Where there is no name, the honest answer is
  /// that this card does not tell us which business it belongs to. The website
  /// stays on the card and stays tappable, and if a later card from the same
  /// business carries the name, the organization is created then and this
  /// domain fills in behind it.
  Future<int?> _resolveOrganization(CardFacts facts) async {
    final String? name = facts.company?.trim();
    if (name == null || name.isEmpty) return null;

    // A platform host is not this company's domain, so it must never become
    // the key that links two organizations. See [isPlatformDomain].
    final String? domain = identityDomain(facts.websiteDomain);

    final String? address = normalizeOrgName(facts.address);
    final List<Organization> candidates = await (_db.select(_db.organizations)
          ..where(($OrganizationsTable t) => t.mergedIntoId.isNull()))
        .get();

    for (final Organization o in candidates) {
      final MatchVerdict v = scoreOrganization(
        cardDomain: domain,
        candidateDomain: o.websiteDomain,
        cardName: name,
        candidateName: o.name,
        cardAddress: address,
        candidateAddress: normalizeOrgName(await _addressOf(o.id)),
      );
      // Alike, but not enough to act on alone. The user decides.
      if (v.score >= MatchVerdict.proposeThreshold &&
          v.score < MatchVerdict.linkThreshold) {
        _pendingOrgProposals.add((o.id, v));
      }
      if (v.score >= MatchVerdict.linkThreshold) {
        // A card that carried the domain fills in one saved without it.
        if (domain != null && o.websiteDomain == null) {
          await (_db.update(_db.organizations)
                ..where(($OrganizationsTable t) => t.id.equals(o.id)))
              .write(OrganizationsCompanion(
            website: Value<String?>(facts.website),
            websiteDomain: Value<String?>(domain),
            updatedAt: Value<DateTime>(DateTime.now()),
          ));
        }
        return o.id;
      }
    }

    final int created = await _db.into(_db.organizations).insert(
          OrganizationsCompanion.insert(
            name: name,
            website: Value<String?>(facts.website),
            websiteDomain: Value<String?>(domain),
          ),
        );

    // Anything that looked alike but not alike enough becomes a question now
    // that there is a second row to ask it about.
    for (final (int other, MatchVerdict v) in _pendingOrgProposals) {
      await _proposeDuplicate(created, other, v, subject: 'organization');
    }
    _pendingOrgProposals.clear();
    return created;
  }

  /// Candidates noticed while resolving, held until there is a row to pair
  /// them with. Cleared on every resolve, so nothing leaks between cards.
  final List<(int, MatchVerdict)> _pendingOrgProposals = <(int, MatchVerdict)>[];

  Future<String?> _addressOf(int orgId) async {
    final List<QueryRow> rows = await _db.customSelect(
      'SELECT address FROM org_branches WHERE org_id = ? '
      'ORDER BY is_primary DESC, id ASC LIMIT 1',
      variables: <Variable<Object>>[Variable<int>(orgId)],
    ).get();
    return rows.isEmpty ? null : rows.first.read<String?>('address');
  }

  /// Finds the person this card belongs to, or makes one.
  ///
  /// Links only on a shared phone or email. A matching name is recorded as a
  /// duplicate candidate and left for the user — see the note at the top of
  /// `resolution.dart` for why that asymmetry is deliberate.
  Future<int?> _resolvePerson(CardFacts facts, int cardId) async {
    final String? name = facts.personName?.trim();
    final List<String> keys = facts.matchKeys.toList();

    // No name on the card, no person behind it. The numbers belong to the
    // company instead.
    //
    // Matching on the endpoints alone looks tempting — the phone is on file,
    // so somebody must own it — but it makes deleting a name impossible. A
    // user who opens a card, clears a person that was never really there and
    // saves is telling us this card is not about anybody; if the phone then
    // resolves straight back to that person, the contact never goes away and
    // the correction appears to do nothing. A card that genuinely belongs to
    // someone has their name on it, and re-adding the name re-links it.
    if (name == null || name.isEmpty) return null;

    if (keys.isNotEmpty) {
      final List<QueryRow> hits = await _db.customSelect(
        'SELECT owner_id AS id, COUNT(*) AS n FROM contact_points '
        'WHERE owner_type = ? AND is_active = 1 '
        'AND normalized_value IN (${List<String>.filled(keys.length, '?').join(',')}) '
        'GROUP BY owner_id ORDER BY n DESC, id ASC',
        variables: <Variable<Object>>[
          Variable<String>('person'),
          for (final String k in keys) Variable<String>(k),
        ],
      ).get();

      if (hits.isNotEmpty) {
        // Through the pointer: a card matching somebody who has since been
        // merged belongs to whoever they were merged into, not to a row that
        // no longer stands for anyone.
        final int personId = await _survivorOf(hits.first.read<int>('id'));
        // More than one existing person shares this card's endpoints. That is
        // a real merge question, not something to answer silently.
        for (final QueryRow other in hits.skip(1)) {
          await _proposeDuplicate(
            personId,
            other.read<int>('id'),
            const MatchVerdict(
              score: 1.0,
              signals: <String>['shared contacts'],
            ),
          );
        }
        return personId;
      }
    }

    // No endpoint matched, but this card already belongs to somebody — keep
    // them. Re-promotion happens on every correction and every rules change,
    // and re-deriving identity from scratch each time would quietly undo the
    // user's own decisions: a card the user merged into another contact would
    // resolve back out by name, land on a fresh row, and reappear as a new
    // duplicate of the person they had just finished combining.
    final CardRow? row = await (_db.select(_db.cards)
          ..where(($CardsTable c) => c.id.equals(cardId)))
        .getSingleOrNull();
    final int? already = row?.personId;
    if (already != null) return _survivorOf(already);

    final int created = await _db.into(_db.people).insert(
          PeopleCompanion.insert(displayName: name),
        );

    // Nobody shared an endpoint, but somebody shares the name. Offer it.
    final List<Person> everyone = await _db.select(_db.people).get();
    for (final Person p in everyone) {
      if (p.id == created) continue;
      final MatchVerdict v = scorePerson(
        sharedKeys: const <String>[],
        cardName: name,
        candidateName: p.displayName,
      );
      if (v.score >= MatchVerdict.proposeThreshold) {
        await _proposeDuplicate(created, p.id, v);
      }
    }
    return created;
  }

  /// Keeps a contact's name in step with the cards it was made from.
  ///
  /// Extraction picks the best candidate on the card, and on a card with the
  /// job title set larger than the name that candidate is the job title. The
  /// user corrects it on the review screen before saving — and nothing
  /// happened, because the card still carries the same phone, so resolution
  /// matched the contact it had already made and moved on. The old, wrong
  /// name stayed on the contact forever.
  ///
  /// Filling only a blank name was the earlier behaviour and it is not enough:
  /// the name is not blank, it is wrong.
  ///
  /// Only acts when the stored name matches none of the cards, so it corrects
  /// what has gone stale without overwriting a name that is still true of one
  /// of them. A name the user confirmed wins over one the engine guessed, and
  /// the most recent card wins after that.
  Future<void> _syncPersonName(int personId) async {
    final Person? person = await (_db.select(_db.people)
          ..where(($PeopleTable t) => t.id.equals(personId)))
        .getSingleOrNull();
    if (person == null) return;

    final List<QueryRow> rows = await _db.customSelect(
      'SELECT f.value AS value FROM card_fields f '
      'JOIN cards c ON c.id = f.card_id '
      r"WHERE f.field_key = 'person_name' AND f.value_kind = 'text' "
      'AND c.person_id = ? AND c.deleted_at IS NULL '
      'ORDER BY f.verified_by_user DESC, c.captured_at DESC',
      variables: <Variable<Object>>[Variable<int>(personId)],
    ).get();

    final List<String> names = <String>[
      for (final QueryRow r in rows)
        if (looksLikePersonName(r.read<String>('value')))
          r.read<String>('value').trim(),
    ];
    if (names.isEmpty) return;
    if (names.contains(person.displayName.trim())) return;

    await (_db.update(_db.people)
          ..where(($PeopleTable t) => t.id.equals(personId)))
        .write(PeopleCompanion(
      displayName: Value<String>(names.first),
      updatedAt: Value<DateTime>(DateTime.now()),
    ));
  }

  Future<int> _findOrCreateRole({
    required int personId,
    required int orgId,
    String? title,
  }) async {
    // Across the whole merge group, not just this row. After two contacts are
    // combined, a card belonging to the row that was merged away re-promotes
    // onto the survivor — and looking for the role under the survivor alone
    // does not find the one already sitting on the tombstone, so the same job
    // is created twice and the contact grows a business it does not have.
    final List<int> ids = await _identitiesOf(personId);
    final Role? existing = await (_db.select(_db.roles)
          ..where(($RolesTable r) => r.personId.isIn(ids) & r.orgId.equals(orgId))
          ..limit(1))
        .getSingleOrNull();

    if (existing != null) {
      if (existing.title == null && title != null && title.trim().isNotEmpty) {
        await (_db.update(_db.roles)
              ..where(($RolesTable r) => r.id.equals(existing.id)))
            .write(RolesCompanion(
          title: Value<String?>(title.trim()),
          updatedAt: Value<DateTime>(DateTime.now()),
        ));
      }
      return existing.id;
    }

    return _db.into(_db.roles).insert(
          RolesCompanion.insert(
            personId: personId,
            orgId: orgId,
            title: Value<String?>(title?.trim()),
          ),
        );
  }

  Future<void> _findOrCreateBranch(int orgId, String address) async {
    final List<OrgBranch> existing = await (_db.select(_db.orgBranches)
          ..where(($OrgBranchesTable b) => b.orgId.equals(orgId)))
        .get();
    final String flat = address.trim().toLowerCase();
    for (final OrgBranch b in existing) {
      if ((b.address ?? '').trim().toLowerCase() == flat) return;
    }
    await _db.into(_db.orgBranches).insert(
          OrgBranchesCompanion.insert(
            orgId: orgId,
            address: Value<String?>(address.trim()),
            isPrimary: Value<bool>(existing.isEmpty),
          ),
        );
  }

  /// Notices when this card is a second scan of one already saved.
  ///
  /// The commonest duplicate this app produces is not two people with the same
  /// name — it is the same piece of paper photographed twice, which leaves two
  /// tiles in the library showing the same card and no hint that they are the
  /// same thing.
  ///
  /// The test is deliberately *not* that the two cards carry identical sets of
  /// numbers. That was the first attempt and it caught nothing: two scans of
  /// one card almost never extract the same set, because the read that made
  /// the second scan worth taking is exactly the one that goes differently.
  /// One pass gets both numbers, the next drops a digit from one of them and
  /// the sets no longer match.
  ///
  /// What actually separates the cases is *who the cards are about*. Two
  /// colleagues at one firm share the office line but have different names on
  /// their cards; two scans of one card agree on the name, or have no name at
  /// all. So: the same company, at least one endpoint in common, and nothing
  /// contradicting about the person.
  Future<void> _proposeDuplicateCards(
    int cardId,
    CardFacts facts, {
    int? personId,
    int? orgId,
  }) async {
    final Set<String> mine = facts.matchKeys.toSet();
    if (mine.isEmpty) return;
    if (personId == null && orgId == null) return;

    final List<QueryRow> others = await _db.customSelect(
      'SELECT id FROM cards WHERE deleted_at IS NULL AND id != ? '
      'AND ((person_id IS NOT NULL AND person_id = ?) '
      '  OR (org_id IS NOT NULL AND org_id = ?))',
      variables: <Variable<Object>>[
        Variable<int>(cardId),
        Variable<int>(personId ?? -1),
        Variable<int>(orgId ?? -1),
      ],
    ).get();

    for (final QueryRow r in others) {
      final int other = r.read<int>('id');
      final CardFacts theirs = await _factsOf(other);

      final Set<String> shared = mine.intersection(theirs.matchKeys.toSet());
      if (shared.isEmpty) continue;

      // One card names somebody and the other does not: a personal card and a
      // company card from the same firm, not two photographs of one thing.
      if ((facts.personName == null) != (theirs.personName == null)) continue;

      if (facts.personName != null && theirs.personName != null) {
        final double alike = nameSimilarity(
          normalizePersonName(facts.personName),
          normalizePersonName(theirs.personName),
        );
        // Different people at the same company, sharing a switchboard.
        if (alike < proposeSimilarity) continue;
      }

      await _proposeDuplicate(
        cardId,
        other,
        MatchVerdict(
          score: 0.85,
          signals: <String>[
            shared.length == 1
                ? 'the same number'
                : '${shared.length} of the same numbers',
            if (facts.personName != null) 'the same name' else 'the same company',
          ],
        ),
        subject: 'card',
      );
    }
  }

  Future<void> _proposeDuplicate(
    int a,
    int b,
    MatchVerdict v, {
    String subject = 'person',
  }) async {
    final int lo = a < b ? a : b;
    final int hi = a < b ? b : a;
    if (lo == hi) return;

    final DuplicateCandidate? already = await (_db.select(_db.duplicateCandidates)
          ..where(($DuplicateCandidatesTable d) =>
              d.subjectType.equals(subject) &
              d.aId.equals(lo) &
              d.bId.equals(hi)))
        .getSingleOrNull();
    // A candidate the user already ruled on does not come back.
    if (already != null) return;

    await _db.into(_db.duplicateCandidates).insert(
          DuplicateCandidatesCompanion.insert(
            subjectType: subject,
            aId: lo,
            bId: hi,
            score: v.score,
            signalsJson: Value<String?>(jsonEncode(v.signals)),
          ),
        );
  }

  // -------------------------------------------------------------------------
  // Duplicate review
  // -------------------------------------------------------------------------

  /// The pairs still waiting on a human, of every kind.
  Stream<List<DuplicatePair>> watchDuplicates() {
    return _db
        .customSelect(
          'SELECT id, subject_type, a_id, b_id, score, signals_json '
          r"FROM duplicate_candidates WHERE status = 'pending' "
          'ORDER BY score DESC, id ASC',
          readsFrom: <ResultSetImplementation<dynamic, dynamic>>{
            _db.duplicateCandidates,
            _db.people,
            _db.organizations,
            _db.cards,
          },
        )
        .watch()
        .asyncMap((List<QueryRow> rows) async {
          final List<DuplicatePair> out = <DuplicatePair>[];
          for (final QueryRow r in rows) {
            final DuplicateKind? kind = switch (r.read<String>('subject_type')) {
              'person' => DuplicateKind.person,
              'organization' => DuplicateKind.organization,
              'card' => DuplicateKind.card,
              _ => null,
            };
            if (kind == null) continue;

            final DuplicateSide? a = await _sideOf(kind, r.read<int>('a_id'));
            final DuplicateSide? b = await _sideOf(kind, r.read<int>('b_id'));
            // A pair whose halves no longer both exist is not a question any
            // more; garbage collection clears the row.
            if (a == null || b == null) continue;

            final String? raw = r.read<String?>('signals_json');
            out.add(DuplicatePair(
              id: r.read<int>('id'),
              kind: kind,
              a: a,
              b: b,
              score: r.read<double>('score'),
              signals: raw == null
                  ? const <String>[]
                  : (jsonDecode(raw) as List<dynamic>).cast<String>(),
            ));
          }
          return out;
        });
  }

  Future<DuplicateSide?> _sideOf(DuplicateKind kind, int id) async {
    switch (kind) {
      case DuplicateKind.person:
        final PersonSummary? p = await _summaryOf(id);
        return p == null
            ? null
            : DuplicateSide(
                id: p.id,
                title: p.displayName,
                subtitle: p.subtitle,
                detail: p.cardCount == 1 ? '1 card' : '${p.cardCount} cards',
              );

      case DuplicateKind.organization:
        final Organization? o = await (_db.select(_db.organizations)
              ..where(($OrganizationsTable t) =>
                  t.id.equals(id) & t.mergedIntoId.isNull()))
            .getSingleOrNull();
        if (o == null) return null;
        final List<QueryRow> n = await _db.customSelect(
          'SELECT COUNT(*) AS n FROM cards '
          'WHERE org_id = ? AND deleted_at IS NULL',
          variables: <Variable<Object>>[Variable<int>(id)],
        ).get();
        final int count = n.isEmpty ? 0 : n.first.read<int>('n');
        return DuplicateSide(
          id: o.id,
          title: o.name,
          subtitle: await _addressOf(o.id) ?? o.websiteDomain,
          detail: count == 1 ? '1 card' : '$count cards',
        );

      case DuplicateKind.card:
        final CardRow? c = await (_db.select(_db.cards)
              ..where(($CardsTable t) =>
                  t.id.equals(id) & t.deletedAt.isNull()))
            .getSingleOrNull();
        if (c == null) return null;
        final CardFacts facts = await _factsOf(id);
        return DuplicateSide(
          id: c.id,
          // The picture is the only reliable way to tell two scans apart, so
          // the text here is support for it rather than the other way round.
          title: facts.company ?? facts.personName ?? 'Unread card',
          subtitle: facts.personName ?? facts.address,
          imagePath: c.thumbPath ?? c.imagePath,
          detail: _describeWhen(c.capturedAt),
        );
    }
  }

  static String _describeWhen(DateTime at) {
    final Duration ago = DateTime.now().difference(at);
    if (ago.inMinutes < 60) return 'just now';
    if (ago.inHours < 24) return '${ago.inHours}h ago';
    return '${ago.inDays}d ago';
  }

  Future<PersonSummary?> _summaryOf(int personId) async {
    final Person? p = await (_db.select(_db.people)
          ..where(($PeopleTable t) =>
              t.id.equals(personId) & t.mergedIntoId.isNull()))
        .getSingleOrNull();
    if (p == null) return null;

    final List<QueryRow> count = await _db.customSelect(
      'SELECT COUNT(*) AS n FROM cards '
      'WHERE person_id = ? AND deleted_at IS NULL',
      variables: <Variable<Object>>[Variable<int>(personId)],
    ).get();

    return PersonSummary(
      id: p.id,
      displayName: p.displayName,
      cardCount: count.isEmpty ? 0 : count.first.read<int>('n'),
      subtitle: await _subtitleFor(personId),
    );
  }

  /// Records that two rows are one person.
  ///
  /// Nothing moves. [loser] keeps its roles, endpoints and cards and gains a
  /// pointer at [survivor]; every read follows it. That is what makes this
  /// undoable — a merge that relocated rows could not know afterwards which of
  /// them had been whose, so [unmerge] would be guessing.
  Future<void> merge({required int survivor, required int loser}) async {
    if (survivor == loser) return;
    await _db.transaction(() async {
      await (_db.update(_db.people)
            ..where(($PeopleTable t) => t.id.equals(loser)))
          .write(PeopleCompanion(
        mergedIntoId: Value<int?>(survivor),
        updatedAt: Value<DateTime>(DateTime.now()),
      ));
      // Anything that pointed at the loser now points at the survivor, so a
      // chain never grows past one hop.
      await (_db.update(_db.people)
            ..where(($PeopleTable t) => t.mergedIntoId.equals(loser)))
          .write(PeopleCompanion(mergedIntoId: Value<int?>(survivor)));

      await _settle(survivor, loser, 'linked');
    });
  }

  /// Records that two companies are one.
  Future<void> mergeOrganizations({
    required int survivor,
    required int loser,
  }) async {
    if (survivor == loser) return;
    await _db.transaction(() async {
      await (_db.update(_db.organizations)
            ..where(($OrganizationsTable t) => t.id.equals(loser)))
          .write(OrganizationsCompanion(
        mergedIntoId: Value<int?>(survivor),
        updatedAt: Value<DateTime>(DateTime.now()),
      ));
      await (_db.update(_db.organizations)
            ..where(($OrganizationsTable t) => t.mergedIntoId.equals(loser)))
          .write(OrganizationsCompanion(mergedIntoId: Value<int?>(survivor)));

      await _settle(survivor, loser, 'linked', subject: 'organization');
    });
  }

  /// Separates a company merged into another.
  Future<void> unmergeOrganization(int orgId) async {
    await (_db.update(_db.organizations)
          ..where(($OrganizationsTable t) => t.id.equals(orgId)))
        .write(const OrganizationsCompanion(mergedIntoId: Value<int?>(null)));
  }

  Future<void> keepOrganizationsSeparate({
    required int a,
    required int b,
  }) =>
      _settle(a, b, 'rejected', subject: 'organization');

  Future<void> keepCardsSeparate({required int a, required int b}) =>
      _settle(a, b, 'rejected', subject: 'card');

  /// Removes the second scan of a card the library already has.
  ///
  /// Soft-deleted rather than destroyed, so it lands in Recently deleted and
  /// the decision is reversible — the same treatment a swipe gets, and for the
  /// same reason: this is the one action in the review list that removes
  /// something rather than joining two things.
  Future<void> discardDuplicateCard({
    required int keep,
    required int discard,
  }) async {
    await _settle(keep, discard, 'linked', subject: 'card');
    await (_db.update(_db.cards)
          ..where(($CardsTable c) => c.id.equals(discard)))
        .write(CardsCompanion(
      deletedAt: Value<DateTime?>(DateTime.now()),
      updatedAt: Value<DateTime>(DateTime.now()),
    ));
    // Its contribution to the graph goes with it, or the company it created
    // outlives the scan it came from.
    await (_db.delete(_db.contactPoints)
          ..where(($ContactPointsTable c) => c.sourceCardId.equals(discard)))
        .go();
    await _unlink(discard);
    await _collectGarbage();
  }

  /// Every row that stands for this company, the survivor included.
  Future<List<int>> _orgIdentitiesOf(int orgId) async {
    final List<QueryRow> merged = await _db.customSelect(
      'SELECT id FROM organizations WHERE merged_into_id = ?',
      variables: <Variable<Object>>[Variable<int>(orgId)],
    ).get();
    return <int>[orgId, for (final QueryRow r in merged) r.read<int>('id')];
  }

  /// Separates a person merged into another.
  Future<void> unmerge(int personId) async {
    await (_db.update(_db.people)
          ..where(($PeopleTable t) => t.id.equals(personId)))
        .write(const PeopleCompanion(mergedIntoId: Value<int?>(null)));
  }

  /// Records that two rows are two different people, permanently.
  Future<void> keepSeparate({required int a, required int b}) =>
      _settle(a, b, 'rejected');

  Future<void> _settle(
    int a,
    int b,
    String status, {
    String subject = 'person',
  }) async {
    final int lo = a < b ? a : b;
    final int hi = a < b ? b : a;
    await (_db.update(_db.duplicateCandidates)
          ..where(($DuplicateCandidatesTable d) =>
              d.subjectType.equals(subject) &
              d.aId.equals(lo) &
              d.bId.equals(hi)))
        .write(DuplicateCandidatesCompanion(
      status: Value<String>(status),
      updatedAt: Value<DateTime>(DateTime.now()),
    ));
  }

  /// Follows a merge pointer to the row that stands for this person.
  Future<int> _survivorOf(int personId) async {
    final Person? p = await (_db.select(_db.people)
          ..where(($PeopleTable t) => t.id.equals(personId)))
        .getSingleOrNull();
    return p?.mergedIntoId ?? personId;
  }

  /// Every row that stands for this person, the survivor included.
  Future<List<int>> _identitiesOf(int personId) async {
    final List<QueryRow> merged = await _db.customSelect(
      'SELECT id FROM people WHERE merged_into_id = ?',
      variables: <Variable<Object>>[Variable<int>(personId)],
    ).get();
    return <int>[
      personId,
      for (final QueryRow r in merged) r.read<int>('id'),
    ];
  }

  // -------------------------------------------------------------------------
  // Teardown
  // -------------------------------------------------------------------------

  Future<void> _unlink(int cardId) async {
    await (_db.update(_db.cards)..where(($CardsTable c) => c.id.equals(cardId)))
        .write(const CardsCompanion(
      personId: Value<int?>(null),
      orgId: Value<int?>(null),
      roleId: Value<int?>(null),
    ));
  }

  /// Removes entities nothing points at any more.
  ///
  /// Order matters — roles before people and organizations, branches before
  /// organizations — because the foreign keys are on and would otherwise
  /// refuse. Endpoints the user typed in themselves survive: they have no
  /// `source_card_id`, so deleting the card they were added beside must not
  /// take them.
  Future<void> _collectGarbage() async {
    // A deleted card contributes nothing, from the moment it is deleted.
    //
    // Deleting soft-deletes first and only tears the graph down when the undo
    // window closes, so a card deleted and never purged — the app closed, the
    // battery went — left its endpoints behind, and those endpoints held its
    // company in the contacts list for good. Two cards in the library and
    // three companies beside them, with nothing to explain the third.
    await _db.customStatement(
      'DELETE FROM contact_points WHERE source_card_id IN '
      '(SELECT id FROM cards WHERE deleted_at IS NOT NULL)',
    );

    // Which people and companies nothing points at any more. Worked out
    // before anything is deleted, because roles and branches reference both
    // and have to go first — the foreign keys are on.
    final Set<int> deadPeople = await _deadEntities(
      table: 'people',
      cardColumn: 'person_id',
      ownerType: 'person',
    );
    final Set<int> deadOrgs = await _deadEntities(
      table: 'organizations',
      cardColumn: 'org_id',
      ownerType: 'organization',
    );

    if (deadPeople.isNotEmpty || deadOrgs.isNotEmpty) {
      // Unhook every reference before deleting anything, **including from
      // cards that are only soft-deleted**. Those rows still exist and still
      // hold foreign keys, so a card sitting in Recently deleted was enough
      // to make the whole collection fail on a constraint — and because this
      // runs at the top of `backfill`, one such card stopped the graph being
      // maintained at all. Nothing downstream of it ran.
      //
      // Losing the links costs nothing: restoring a card re-promotes it and
      // rebuilds whatever it needs.
      final String doomedRoles =
          'SELECT id FROM roles WHERE person_id IN (${_list(deadPeople)}) '
          'OR org_id IN (${_list(deadOrgs)})';
      await _db.customStatement(
        'UPDATE cards SET role_id = NULL WHERE role_id IN ($doomedRoles)',
      );
      await _db.customStatement(
        'UPDATE contact_points SET role_id = NULL '
        'WHERE role_id IN ($doomedRoles)',
      );
      await _db.customStatement(
        'UPDATE cards SET person_id = NULL '
        'WHERE person_id IN (${_list(deadPeople)})',
      );
      await _db.customStatement(
        'UPDATE cards SET org_id = NULL WHERE org_id IN (${_list(deadOrgs)})',
      );

      await _db.customStatement(
        'DELETE FROM roles WHERE '
        'person_id IN (${_list(deadPeople)}) OR org_id IN (${_list(deadOrgs)})',
      );
    }
    if (deadOrgs.isNotEmpty) {
      await _db.customStatement(
        'DELETE FROM org_branches WHERE org_id IN (${_list(deadOrgs)})',
      );
    }

    // Then the rows themselves, tombstones before the survivors they point
    // at, so nothing is ever left referring to a row that has gone.
    await _deleteEntities('people', deadPeople);
    await _deleteEntities('organizations', deadOrgs);

    // Roles nothing points at, among those still standing.
    await _db.customStatement(
      'DELETE FROM roles WHERE id NOT IN '
      '(SELECT role_id FROM cards WHERE role_id IS NOT NULL) '
      'AND id NOT IN '
      '(SELECT role_id FROM contact_points WHERE role_id IS NOT NULL) '
      // A role on a row the user merged away is one of the businesses the
      // combined contact is *made of*. Its card now points at the survivor,
      // so nothing else holds it up — and collecting it would delete a
      // business the merge was supposed to preserve.
      'AND person_id NOT IN '
      '(SELECT id FROM people WHERE merged_into_id IS NOT NULL)',
    );
    await _db.customStatement(
      'DELETE FROM org_branches WHERE org_id NOT IN '
      '(SELECT id FROM organizations)',
    );

    // Questions about rows that no longer exist are not questions.
    for (final (String subject, String table) in <(String, String)>[
      ('person', 'people'),
      ('organization', 'organizations'),
      ('card', 'cards'),
    ]) {
      await _db.customStatement(
        'DELETE FROM duplicate_candidates WHERE subject_type = ? AND '
        '(a_id NOT IN (SELECT id FROM $table) OR '
        ' b_id NOT IN (SELECT id FROM $table))',
        <Object?>[subject],
      );
    }

    _notifyGraphChanged();
  }

  static String _list(Set<int> ids) =>
      ids.isEmpty ? '-1' : ids.join(',');

  /// Tells Drift the graph changed under it.
  ///
  /// Every stream on this data is a `customSelect(...).watch()`, and Drift
  /// re-runs those when it *observes* a write to one of the tables they name.
  /// It observes writes made through its own query builder; a raw
  /// `customStatement` is opaque to it. Garbage collection is almost entirely
  /// raw SQL — the recursive merge-group work does not express well any other
  /// way — so without this the rows go and the screen does not notice.
  ///
  /// That is a nastier failure than it sounds. The database ends up correct
  /// and the contacts list keeps showing a company that is no longer in it,
  /// which reads as the cleanup being broken when it has already run.
  void _notifyGraphChanged() {
    _db.notifyUpdates(<TableUpdate>{
      TableUpdate.onTable(_db.people),
      TableUpdate.onTable(_db.organizations),
      TableUpdate.onTable(_db.roles),
      TableUpdate.onTable(_db.orgBranches),
      TableUpdate.onTable(_db.contactPoints),
      TableUpdate.onTable(_db.cards),
      TableUpdate.onTable(_db.duplicateCandidates),
    });
  }

  /// People or companies nothing points at any more.
  ///
  /// Merge-aware, and that is the whole difficulty. A merged pair is one
  /// entity in two rows: the survivor, and the tombstone that records the
  /// decision. Judging them separately gets it wrong in both directions —
  /// collect the tombstone and the merge silently comes apart, protect it
  /// unconditionally and the pair becomes immortal. The second is a real
  /// residue: two scans of a shop sign, combined, then both cards deleted, and
  /// the company stays in the list forever with nothing behind it.
  ///
  /// So the unit is the group, not the row. A group survives while *anything*
  /// in it is held up by a live card or an endpoint, and goes entirely when
  /// nothing is. Worked out in Dart rather than SQL because the "held up
  /// through a pointer" part is unreadable as a query, and there are only ever
  /// a handful of rows.
  Future<Set<int>> _deadEntities({
    required String table,
    required String cardColumn,
    required String ownerType,
  }) async {
    final List<QueryRow> rows = await _db
        .customSelect('SELECT id, merged_into_id FROM $table')
        .get();
    if (rows.isEmpty) return const <int>{};

    // Deleted cards do not hold anything up: they are recoverable, and
    // restoring one re-promotes it and rebuilds whatever it needs.
    final Set<int> held = <int>{
      for (final QueryRow r in await _db
          .customSelect('SELECT DISTINCT $cardColumn AS id FROM cards '
              'WHERE $cardColumn IS NOT NULL AND deleted_at IS NULL')
          .get())
        r.read<int>('id'),
      for (final QueryRow r in await _db.customSelect(
        'SELECT DISTINCT owner_id AS id FROM contact_points '
        'WHERE owner_type = ?',
        variables: <Variable<Object>>[Variable<String>(ownerType)],
      ).get())
        r.read<int>('id'),
    };

    // Group every row under whichever row stands for it.
    final Map<int, int> survivorOf = <int, int>{
      for (final QueryRow r in rows)
        r.read<int>('id'): r.read<int?>('merged_into_id') ?? r.read<int>('id'),
    };

    final Set<int> liveGroups = <int>{
      for (final int id in held)
        if (survivorOf.containsKey(id)) survivorOf[id]!,
    };

    return <int>{
      for (final MapEntry<int, int> e in survivorOf.entries)
        if (!liveGroups.contains(e.value)) e.key,
    };
  }

  /// Deletes rows tombstone-first, so none is left pointing at a missing row.
  Future<void> _deleteEntities(String table, Set<int> ids) async {
    if (ids.isEmpty) return;
    await _db.customStatement(
      'DELETE FROM $table WHERE merged_into_id IS NOT NULL '
      'AND id IN (${_list(ids)})',
    );
    await _db.customStatement(
      'DELETE FROM $table WHERE id IN (${_list(ids)})',
    );
  }

  // -------------------------------------------------------------------------
  // Reads
  // -------------------------------------------------------------------------

  Stream<List<PersonSummary>> watchPeople() {
    return _db
        .customSelect(
          'SELECT p.id AS id, p.display_name AS display_name, '
          'COUNT(DISTINCT c.id) AS card_count, '
          'MAX(c.captured_at) AS last_seen '
          'FROM people p '
          'LEFT JOIN cards c ON c.person_id = p.id AND c.deleted_at IS NULL '
          // A person merged into somebody else is not a separate contact any
          // more. The row stays so the merge can be undone; it just stops
          // being listed.
          'WHERE p.merged_into_id IS NULL '
          'GROUP BY p.id ORDER BY last_seen DESC, p.id DESC',
          readsFrom: <ResultSetImplementation<dynamic, dynamic>>{
            _db.people,
            _db.cards,
            _db.roles,
          },
        )
        .watch()
        .asyncMap((List<QueryRow> rows) async {
          final List<PersonSummary> out = <PersonSummary>[];
          for (final QueryRow r in rows) {
            final int id = r.read<int>('id');
            out.add(PersonSummary(
              id: id,
              displayName: r.read<String>('display_name'),
              cardCount: r.read<int>('card_count'),
              subtitle: await _subtitleFor(id),
            ));
          }
          return out;
        });
  }

  Stream<List<OrgSummary>> watchOrganizations() {
    return _db
        .customSelect(
          'SELECT o.id AS id, o.name AS name, o.website_domain AS domain, '
          '(SELECT address FROM org_branches b WHERE b.org_id = o.id '
          ' ORDER BY b.is_primary DESC, b.id ASC LIMIT 1) AS address, '
          'COUNT(DISTINCT c.id) AS card_count, '
          'COUNT(DISTINCT c.person_id) AS people_count, '
          'MAX(c.captured_at) AS last_seen '
          'FROM organizations o '
          'LEFT JOIN cards c ON c.org_id = o.id AND c.deleted_at IS NULL '
          // A company merged into another stops being its own row.
          'WHERE o.merged_into_id IS NULL '
          'GROUP BY o.id ORDER BY last_seen DESC, o.id DESC',
          readsFrom: <ResultSetImplementation<dynamic, dynamic>>{
            _db.organizations,
            _db.orgBranches,
            _db.cards,
          },
        )
        .watch()
        .map((List<QueryRow> rows) => <OrgSummary>[
              for (final QueryRow r in rows)
                OrgSummary(
                  id: r.read<int>('id'),
                  name: r.read<String>('name'),
                  subtitle:
                      r.read<String?>('address') ?? r.read<String?>('domain'),
                  cardCount: r.read<int>('card_count'),
                  peopleCount: r.read<int>('people_count'),
                ),
            ]);
  }

  /// What to show under a name: their job if we know it, otherwise a number.
  Future<String?> _subtitleFor(int personId) async {
    final List<int> ids = await _identitiesOf(personId);
    final List<QueryRow> roles = await _db.customSelect(
      'SELECT r.title AS title, o.name AS org FROM roles r '
      'JOIN organizations o ON o.id = r.org_id '
      'WHERE r.person_id IN (${List<String>.filled(ids.length, '?').join(',')}) '
      'ORDER BY r.is_current DESC, r.id ASC',
      variables: <Variable<Object>>[for (final int id in ids) Variable<int>(id)],
    ).get();

    if (roles.isNotEmpty) {
      final QueryRow first = roles.first;
      final String? title = first.read<String?>('title');
      final String org = first.read<String>('org');
      final String head = title == null ? org : '$title · $org';
      // Two businesses is the case worth advertising in the list.
      return roles.length > 1 ? '$head  +${roles.length - 1} more' : head;
    }

    final ContactPoint? cp = await (_db.select(_db.contactPoints)
          ..where(($ContactPointsTable c) =>
              c.ownerType.equals('person') & c.ownerId.equals(personId))
          ..limit(1))
        .getSingleOrNull();
    return cp?.value;
  }

  Stream<PersonDetail?> watchPerson(int personId) {
    return _db
        .customSelect(
          'SELECT id FROM people WHERE id = ?',
          variables: <Variable<Object>>[Variable<int>(personId)],
          readsFrom: <ResultSetImplementation<dynamic, dynamic>>{
            _db.people,
            _db.roles,
            _db.organizations,
            _db.contactPoints,
            _db.cards,
          },
        )
        .watch()
        .asyncMap((List<QueryRow> rows) async {
          if (rows.isEmpty) return null;
          return _personDetail(personId);
        });
  }

  Future<PersonDetail?> _personDetail(int personId) async {
    final Person? person = await (_db.select(_db.people)
          ..where(($PeopleTable t) => t.id.equals(personId)))
        .getSingleOrNull();
    if (person == null) return null;

    // Everything belonging to any row merged into this one. A merge moves no
    // data, so this is where the two halves come back together.
    final List<int> ids = await _identitiesOf(personId);
    final String placeholders = List<String>.filled(ids.length, '?').join(',');

    final List<ContactPoint> all = await (_db.select(_db.contactPoints)
          ..where(($ContactPointsTable c) =>
              c.ownerType.equals('person') & c.ownerId.isIn(ids)))
        .get();

    final List<QueryRow> roleRows = await _db.customSelect(
      'SELECT r.id AS id, r.title AS title, o.id AS org_id, o.name AS org '
      'FROM roles r JOIN organizations o ON o.id = r.org_id '
      'WHERE r.person_id IN ($placeholders) '
      'ORDER BY r.is_current DESC, r.id ASC',
      variables: <Variable<Object>>[for (final int id in ids) Variable<int>(id)],
    ).get();

    final List<RoleDetail> roles = <RoleDetail>[
      for (final QueryRow r in roleRows)
        RoleDetail(
          roleId: r.read<int>('id'),
          orgId: r.read<int>('org_id'),
          orgName: r.read<String>('org'),
          title: r.read<String?>('title'),
          contacts: _dedupe(all.where((ContactPoint c) => c.roleId == r.read<int>('id'))),
        ),
    ];

    final List<QueryRow> cardRows = await _db.customSelect(
      'SELECT id FROM cards WHERE person_id IN ($placeholders) '
      'AND deleted_at IS NULL ORDER BY captured_at DESC',
      variables: <Variable<Object>>[for (final int id in ids) Variable<int>(id)],
    ).get();

    final List<PersonSummary> mergedFrom = <PersonSummary>[];
    for (final int id in ids) {
      if (id == personId) continue;
      final Person? other = await (_db.select(_db.people)
            ..where(($PeopleTable t) => t.id.equals(id)))
          .getSingleOrNull();
      if (other == null) continue;
      mergedFrom.add(PersonSummary(
        id: other.id,
        displayName: other.displayName,
        cardCount: 0,
        subtitle: await _roleNameOf(other.id),
      ));
    }

    return PersonDetail(
      person: person,
      roles: roles,
      looseContacts: _dedupe(all.where((ContactPoint c) => c.roleId == null)),
      cardIds: <int>[for (final QueryRow r in cardRows) r.read<int>('id')],
      mergedFrom: mergedFrom,
    );
  }

  Stream<OrgDetail?> watchOrganization(int orgId) {
    return _db
        .customSelect(
          'SELECT id FROM organizations WHERE id = ?',
          variables: <Variable<Object>>[Variable<int>(orgId)],
          readsFrom: <ResultSetImplementation<dynamic, dynamic>>{
            _db.organizations,
            _db.orgBranches,
            _db.contactPoints,
            _db.roles,
            _db.cards,
          },
        )
        .watch()
        .asyncMap((List<QueryRow> rows) async {
          if (rows.isEmpty) return null;
          return _orgDetail(orgId);
        });
  }

  Future<OrgDetail?> _orgDetail(int orgId) async {
    final Organization? org = await (_db.select(_db.organizations)
          ..where(($OrganizationsTable t) => t.id.equals(orgId)))
        .getSingleOrNull();
    if (org == null) return null;

    // Everything belonging to any row merged into this one — two scans of the
    // same shop sign have to come back together here.
    final List<int> ids = await _orgIdentitiesOf(orgId);
    final String placeholders = List<String>.filled(ids.length, '?').join(',');
    final List<Variable<Object>> vars = <Variable<Object>>[
      for (final int id in ids) Variable<int>(id),
    ];

    final List<OrgBranch> branches = await (_db.select(_db.orgBranches)
          ..where(($OrgBranchesTable b) => b.orgId.isIn(ids))
          ..orderBy(<OrderClauseGenerator<$OrgBranchesTable>>[
            ($OrgBranchesTable b) => OrderingTerm.desc(b.isPrimary),
          ]))
        .get();

    final List<ContactPoint> contacts = await (_db.select(_db.contactPoints)
          ..where(($ContactPointsTable c) =>
              c.ownerType.equals('organization') & c.ownerId.isIn(ids)))
        .get();

    final List<QueryRow> peopleRows = await _db.customSelect(
      'SELECT DISTINCT p.id AS id, p.display_name AS display_name '
      'FROM people p JOIN roles r ON r.person_id = p.id '
      'WHERE r.org_id IN ($placeholders) ORDER BY p.display_name',
      variables: vars,
    ).get();

    final List<PersonSummary> people = <PersonSummary>[];
    for (final QueryRow r in peopleRows) {
      final int id = r.read<int>('id');
      people.add(PersonSummary(
        id: id,
        displayName: r.read<String>('display_name'),
        cardCount: 0,
        subtitle: await _roleTitleAt(id, orgId),
      ));
    }

    final List<QueryRow> cardRows = await _db.customSelect(
      'SELECT id FROM cards WHERE org_id IN ($placeholders) '
      'AND deleted_at IS NULL ORDER BY captured_at DESC',
      variables: vars,
    ).get();

    return OrgDetail(
      organization: org,
      branches: branches,
      contacts: _dedupe(contacts),
      people: people,
      cardIds: <int>[for (final QueryRow r in cardRows) r.read<int>('id')],
    );
  }

  /// The company a merged-away row came in under, to tell two of them apart.
  Future<String?> _roleNameOf(int personId) async {
    final List<QueryRow> rows = await _db.customSelect(
      'SELECT o.name AS org FROM roles r '
      'JOIN organizations o ON o.id = r.org_id '
      'WHERE r.person_id = ? ORDER BY r.id ASC LIMIT 1',
      variables: <Variable<Object>>[Variable<int>(personId)],
    ).get();
    return rows.isEmpty ? null : rows.first.read<String>('org');
  }

  Future<String?> _roleTitleAt(int personId, int orgId) async {
    final Role? role = await (_db.select(_db.roles)
          ..where(($RolesTable r) =>
              r.personId.equals(personId) & r.orgId.equals(orgId)))
        .getSingleOrNull();
    return role?.title;
  }

  /// One row per distinct endpoint.
  ///
  /// Two cards asserting the same number produce two rows on purpose — that is
  /// what makes a single card's contribution refreshable — so the collapsing
  /// happens here, at the point of display.
  List<ContactPoint> _dedupe(Iterable<ContactPoint> points) {
    final Map<String, ContactPoint> seen = <String, ContactPoint>{};
    for (final ContactPoint c in points) {
      seen.putIfAbsent('${c.kind}|${c.normalizedValue ?? c.value}', () => c);
    }
    return seen.values.toList();
  }

  // -------------------------------------------------------------------------
  // Facts
  // -------------------------------------------------------------------------

  /// Reads a card's current fields as identity facts.
  Future<CardFacts> _factsOf(int cardId) async {
    final List<CardField> fields = await (_db.select(_db.cardFields)
          ..where(($CardFieldsTable f) => f.cardId.equals(cardId)))
        .get();

    String? first(String key) {
      for (final CardField f in fields) {
        // An image crop is a picture of a value, not a value — it cannot be
        // matched on and must not become somebody's name.
        if (f.fieldKey == key && f.valueKind == FieldValueKind.text) {
          return f.value.trim();
        }
      }
      return null;
    }

    final String? website = first(FieldKeys.website);
    String? domain;
    for (final CardField f in fields) {
      if (f.fieldKey == FieldKeys.website && f.normalizedValue != null) {
        domain = f.normalizedValue;
        break;
      }
    }

    // A stray line that extraction filed as a name does not become a person.
    final String? candidateName = first(FieldKeys.personName);

    return CardFacts(
      personName:
          looksLikePersonName(candidateName) ? candidateName : null,
      company: first(FieldKeys.company),
      designation: first(FieldKeys.designation),
      website: website,
      websiteDomain: domain,
      address: first(FieldKeys.address),
      contacts: <ContactFact>[
        for (final CardField f in fields)
          if (f.valueKind == FieldValueKind.text)
            // An endpoint with no canonical form does not go in the graph.
            // `017098227` is a real read off a real card — three digits short
            // — and promoting it produces a contact point that cannot be
            // dialled, cannot match anything, and gets exported into the
            // user's address book as though it were a phone number. The field
            // stays on the card, flagged and repairable; it is just not
            // treated as a way to reach anybody until it is fixed.
            //
            // The test is the canonical form, deliberately, and not
            // `validationIssue == null`. Most issues are *notes on a value
            // that is fine*: `digit_restored` means the number was reformatted
            // for display, `ocr_repaired` that a digit was inferred. Both
            // carry a good E.164. Filtering on the issue instead threw away
            // every repaired number on the card — which is most of them.
            if (f.normalizedValue != null)
              if (_kindOf(f.fieldKey) case final ContactKind kind)
                ContactFact(
                  kind: kind,
                  value: f.value.trim(),
                  normalized: f.normalizedValue,
                  source: f.source,
                ),
      ],
    );
  }

  static ContactKind? _kindOf(String fieldKey) => switch (fieldKey) {
        FieldKeys.phone => ContactKind.phone,
        FieldKeys.email => ContactKind.email,
        _ => null,
      };
}
