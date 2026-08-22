import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/db/enums.dart';
import '../../../core/extraction/card_extractor.dart';
import '../../../core/identity/resolution.dart';
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
  });

  final Person person;
  final List<RoleDetail> roles;

  /// Endpoints not tied to any particular job.
  final List<ContactPoint> looseContacts;

  final List<int> cardIds;
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

  /// Rebuilds one card's contribution to the graph.
  ///
  /// Idempotent by construction: the card's own `contact_points` rows are
  /// dropped and rewritten, and everything else is find-or-create. That
  /// matters because `attachExtraction` deletes and re-inserts unverified
  /// fields on every re-run — anything that merely appended here would grow a
  /// duplicate endpoint per retry.
  Future<void> promote(int cardId) async {
    final CardFacts facts = await _factsOf(cardId);

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
      ') ORDER BY captured_at DESC',
    ).get();

    for (final QueryRow row in rows) {
      await promote(row.read<int>('id'));
    }
  }

  // -------------------------------------------------------------------------
  // Resolution
  // -------------------------------------------------------------------------

  /// Finds the organization this card belongs to, or makes one.
  Future<int?> _resolveOrganization(CardFacts facts) async {
    final String? name = facts.company?.trim();
    final String? domain = facts.websiteDomain;
    if ((name == null || name.isEmpty) && domain == null) return null;

    final List<Organization> candidates = await _db.select(_db.organizations).get();
    for (final Organization o in candidates) {
      final MatchVerdict v = scoreOrganization(
        cardDomain: domain,
        candidateDomain: o.websiteDomain,
        cardName: name,
        candidateName: o.name,
      );
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

    return _db.into(_db.organizations).insert(
          OrganizationsCompanion.insert(
            name: name ?? domain!,
            website: Value<String?>(facts.website),
            websiteDomain: Value<String?>(domain),
          ),
        );
  }

  /// Finds the person this card belongs to, or makes one.
  ///
  /// Links only on a shared phone or email. A matching name is recorded as a
  /// duplicate candidate and left for the user — see the note at the top of
  /// `resolution.dart` for why that asymmetry is deliberate.
  Future<int?> _resolvePerson(CardFacts facts, int cardId) async {
    final String? name = facts.personName?.trim();
    final List<String> keys = facts.matchKeys.toList();
    if ((name == null || name.isEmpty) && keys.isEmpty) return null;

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
        final int personId = hits.first.read<int>('id');
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
        if (name != null && name.isNotEmpty) {
          await _fillBlankName(personId, name);
        }
        return personId;
      }
    }

    if (name == null || name.isEmpty) return null;

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

  Future<void> _fillBlankName(int personId, String name) async {
    final Person p = await (_db.select(_db.people)
          ..where(($PeopleTable t) => t.id.equals(personId)))
        .getSingle();
    // Only ever fills a gap. Overwriting a name the user may have corrected is
    // exactly the destructive behaviour the whole design avoids.
    if (p.displayName.trim().isNotEmpty) return;
    await (_db.update(_db.people)..where(($PeopleTable t) => t.id.equals(personId)))
        .write(PeopleCompanion(
      displayName: Value<String>(name),
      updatedAt: Value<DateTime>(DateTime.now()),
    ));
  }

  Future<int> _findOrCreateRole({
    required int personId,
    required int orgId,
    String? title,
  }) async {
    final Role? existing = await (_db.select(_db.roles)
          ..where(($RolesTable r) =>
              r.personId.equals(personId) & r.orgId.equals(orgId)))
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

  Future<void> _proposeDuplicate(int a, int b, MatchVerdict v) async {
    final int lo = a < b ? a : b;
    final int hi = a < b ? b : a;
    if (lo == hi) return;

    final DuplicateCandidate? already = await (_db.select(_db.duplicateCandidates)
          ..where(($DuplicateCandidatesTable d) =>
              d.subjectType.equals('person') &
              d.aId.equals(lo) &
              d.bId.equals(hi)))
        .getSingleOrNull();
    // A candidate the user already ruled on does not come back.
    if (already != null) return;

    await _db.into(_db.duplicateCandidates).insert(
          DuplicateCandidatesCompanion.insert(
            subjectType: 'person',
            aId: lo,
            bId: hi,
            score: v.score,
            signalsJson: Value<String?>(jsonEncode(v.signals)),
          ),
        );
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
    await _db.customStatement(
      'DELETE FROM roles WHERE id NOT IN '
      '(SELECT role_id FROM cards WHERE role_id IS NOT NULL) '
      'AND id NOT IN '
      '(SELECT role_id FROM contact_points WHERE role_id IS NOT NULL)',
    );
    await _db.customStatement(
      'DELETE FROM org_branches WHERE org_id NOT IN '
      '(SELECT org_id FROM cards WHERE org_id IS NOT NULL)',
    );
    await _db.customStatement(
      'DELETE FROM people WHERE id NOT IN '
      '(SELECT person_id FROM cards WHERE person_id IS NOT NULL) '
      'AND id NOT IN '
      "(SELECT owner_id FROM contact_points WHERE owner_type = 'person')",
    );
    await _db.customStatement(
      'DELETE FROM organizations WHERE id NOT IN '
      '(SELECT org_id FROM cards WHERE org_id IS NOT NULL) '
      'AND id NOT IN '
      "(SELECT owner_id FROM contact_points WHERE owner_type = 'organization')",
    );
    await _db.customStatement(
      'DELETE FROM duplicate_candidates WHERE subject_type = \'person\' AND '
      '(a_id NOT IN (SELECT id FROM people) OR '
      'b_id NOT IN (SELECT id FROM people))',
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
    final List<QueryRow> roles = await _db.customSelect(
      'SELECT r.title AS title, o.name AS org FROM roles r '
      'JOIN organizations o ON o.id = r.org_id '
      'WHERE r.person_id = ? ORDER BY r.is_current DESC, r.id ASC',
      variables: <Variable<Object>>[Variable<int>(personId)],
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

    final List<ContactPoint> all = await (_db.select(_db.contactPoints)
          ..where(($ContactPointsTable c) =>
              c.ownerType.equals('person') & c.ownerId.equals(personId)))
        .get();

    final List<QueryRow> roleRows = await _db.customSelect(
      'SELECT r.id AS id, r.title AS title, o.id AS org_id, o.name AS org '
      'FROM roles r JOIN organizations o ON o.id = r.org_id '
      'WHERE r.person_id = ? ORDER BY r.is_current DESC, r.id ASC',
      variables: <Variable<Object>>[Variable<int>(personId)],
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
      'SELECT id FROM cards WHERE person_id = ? AND deleted_at IS NULL '
      'ORDER BY captured_at DESC',
      variables: <Variable<Object>>[Variable<int>(personId)],
    ).get();

    return PersonDetail(
      person: person,
      roles: roles,
      looseContacts: _dedupe(all.where((ContactPoint c) => c.roleId == null)),
      cardIds: <int>[for (final QueryRow r in cardRows) r.read<int>('id')],
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

    final List<OrgBranch> branches = await (_db.select(_db.orgBranches)
          ..where(($OrgBranchesTable b) => b.orgId.equals(orgId))
          ..orderBy(<OrderClauseGenerator<$OrgBranchesTable>>[
            ($OrgBranchesTable b) => OrderingTerm.desc(b.isPrimary),
          ]))
        .get();

    final List<ContactPoint> contacts = await (_db.select(_db.contactPoints)
          ..where(($ContactPointsTable c) =>
              c.ownerType.equals('organization') & c.ownerId.equals(orgId)))
        .get();

    final List<QueryRow> peopleRows = await _db.customSelect(
      'SELECT DISTINCT p.id AS id, p.display_name AS display_name '
      'FROM people p JOIN roles r ON r.person_id = p.id '
      'WHERE r.org_id = ? ORDER BY p.display_name',
      variables: <Variable<Object>>[Variable<int>(orgId)],
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
      'SELECT id FROM cards WHERE org_id = ? AND deleted_at IS NULL '
      'ORDER BY captured_at DESC',
      variables: <Variable<Object>>[Variable<int>(orgId)],
    ).get();

    return OrgDetail(
      organization: org,
      branches: branches,
      contacts: _dedupe(contacts),
      people: people,
      cardIds: <int>[for (final QueryRow r in cardRows) r.read<int>('id')],
    );
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

    return CardFacts(
      personName: first(FieldKeys.personName),
      company: first(FieldKeys.company),
      designation: first(FieldKeys.designation),
      website: website,
      websiteDomain: domain,
      address: first(FieldKeys.address),
      contacts: <ContactFact>[
        for (final CardField f in fields)
          if (f.valueKind == FieldValueKind.text)
            // A value the validator objected to does not become an endpoint.
            // `017098227` is a real read of a real card — three digits short,
            // no canonical form — and promoting it produces a contact point
            // that cannot be dialled, cannot match anything, and gets exported
            // into the user's address book as if it were a phone number. The
            // field stays on the card, flagged and repairable; it just is not
            // treated as a way to reach anybody until it is fixed.
            if (f.validationIssue == null)
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
