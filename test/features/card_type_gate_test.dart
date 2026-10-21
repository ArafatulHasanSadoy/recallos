// `isNull` is exported by both drift and matcher; the matcher one is meant.
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recallos/core/db/database.dart';
import 'package:recallos/core/db/enums.dart';
import 'package:recallos/core/extraction/card_extractor.dart';
import 'package:recallos/core/extraction/field_validator.dart';
import 'package:recallos/features/contacts/data/identity_repository.dart';

/// Only cards about people make contacts.
///
/// A receipt prints a shop, a phone number and often a cashier's name; a
/// warranty prints a brand and a service centre. Promoted like a business
/// card, every receipt would add a stranger to the contacts and every shop
/// visited to the companies.
void main() {
  late AppDatabase db;
  late IdentityRepository identity;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    identity = IdentityRepository(db);
  });
  tearDown(() async => db.close());

  Future<int> card(CardType type) async {
    final int id = await db
        .into(db.cards)
        .insert(
          CardsCompanion.insert(
            imagePath: '/tmp/cards/${type.name}.jpg',
            capturedAt: DateTime(2026, 10, 8),
            type: Value<CardType>(type),
          ),
        );
    Future<void> put(String key, String value) async {
      final FieldValidation check = validateField(key, value);
      await db
          .into(db.cardFields)
          .insert(
            CardFieldsCompanion.insert(
              cardId: id,
              fieldKey: key,
              value: value,
              normalizedValue: Value<String?>(check.normalized),
              validationIssue: Value<String?>(check.issue),
              source: FactSource.printed,
            ),
          );
    }

    await put(FieldKeys.personName, 'Rafiq Islam');
    await put(FieldKeys.company, 'Star Tech & Engineering');
    await put(FieldKeys.phone, '01711-223344');
    return id;
  }

  Future<int> count(TableInfo<Table, Object?> t) async =>
      (await db.select(t).get()).length;

  test('a receipt with a name on it makes no contact and no company', () async {
    final int id = await card(CardType.receipt);
    await identity.promote(id);

    expect(await count(db.people), 0);
    expect(await count(db.organizations), 0);
    expect(await count(db.contactPoints), 0);
  });

  test('a warranty card is kept out the same way', () async {
    await identity.promote(await card(CardType.warrantyCard));
    expect(await count(db.people), 0);
  });

  test('a business card, and a card from before types, still do', () async {
    await identity.promote(await card(CardType.visitingCard));
    await identity.promote(await card(CardType.unknown));
    expect(await count(db.people), greaterThan(0));
    expect(await count(db.contactPoints), greaterThan(0));
  });

  test('a card re-typed as a receipt leaves the contacts', () async {
    final int id = await card(CardType.visitingCard);
    await identity.promote(id);
    expect(await count(db.contactPoints), greaterThan(0));

    await (db.update(db.cards)..where(($CardsTable c) => c.id.equals(id)))
        .write(const CardsCompanion(type: Value<CardType>(CardType.receipt)));
    await identity.promote(id);

    final CardRow row = await (db.select(
      db.cards,
    )..where(($CardsTable c) => c.id.equals(id))).getSingle();
    expect(row.personId, isNull);
    expect(row.orgId, isNull);
    expect(await count(db.contactPoints), 0);
  });

  test('backfill does not turn receipts into contacts either', () async {
    await card(CardType.receipt);
    await identity.backfill();
    expect(await count(db.people), 0);
  });
}
