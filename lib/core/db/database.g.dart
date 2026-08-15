// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $PeopleTable extends People with TableInfo<$PeopleTable, PeopleData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PeopleTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 200,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _photoPathMeta = const VerificationMeta(
    'photoPath',
  );
  @override
  late final GeneratedColumn<String> photoPath = GeneratedColumn<String>(
    'photo_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _relationshipMeta = const VerificationMeta(
    'relationship',
  );
  @override
  late final GeneratedColumn<String> relationship = GeneratedColumn<String>(
    'relationship',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _trustScoreMeta = const VerificationMeta(
    'trustScore',
  );
  @override
  late final GeneratedColumn<double> trustScore = GeneratedColumn<double>(
    'trust_score',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.5),
  );
  @override
  List<GeneratedColumn> get $columns => [
    createdAt,
    updatedAt,
    deletedAt,
    id,
    displayName,
    photoPath,
    relationship,
    trustScore,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'people';
  @override
  VerificationContext validateIntegrity(
    Insertable<PeopleData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_displayNameMeta);
    }
    if (data.containsKey('photo_path')) {
      context.handle(
        _photoPathMeta,
        photoPath.isAcceptableOrUnknown(data['photo_path']!, _photoPathMeta),
      );
    }
    if (data.containsKey('relationship')) {
      context.handle(
        _relationshipMeta,
        relationship.isAcceptableOrUnknown(
          data['relationship']!,
          _relationshipMeta,
        ),
      );
    }
    if (data.containsKey('trust_score')) {
      context.handle(
        _trustScoreMeta,
        trustScore.isAcceptableOrUnknown(data['trust_score']!, _trustScoreMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PeopleData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PeopleData(
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      )!,
      photoPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}photo_path'],
      ),
      relationship: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}relationship'],
      ),
      trustScore: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}trust_score'],
      )!,
    );
  }

  @override
  $PeopleTable createAlias(String alias) {
    return $PeopleTable(attachedDatabase, alias);
  }
}

class PeopleData extends DataClass implements Insertable<PeopleData> {
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final int id;
  final String displayName;
  final String? photoPath;

  /// Free text: "met at CSE Fest", "cousin's friend".
  final String? relationship;

  /// Private, per-user, learned from feedback. 0.0–1.0, 0.5 = no signal.
  final double trustScore;
  const PeopleData({
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.id,
    required this.displayName,
    this.photoPath,
    this.relationship,
    required this.trustScore,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['id'] = Variable<int>(id);
    map['display_name'] = Variable<String>(displayName);
    if (!nullToAbsent || photoPath != null) {
      map['photo_path'] = Variable<String>(photoPath);
    }
    if (!nullToAbsent || relationship != null) {
      map['relationship'] = Variable<String>(relationship);
    }
    map['trust_score'] = Variable<double>(trustScore);
    return map;
  }

  PeopleCompanion toCompanion(bool nullToAbsent) {
    return PeopleCompanion(
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      id: Value(id),
      displayName: Value(displayName),
      photoPath: photoPath == null && nullToAbsent
          ? const Value.absent()
          : Value(photoPath),
      relationship: relationship == null && nullToAbsent
          ? const Value.absent()
          : Value(relationship),
      trustScore: Value(trustScore),
    );
  }

  factory PeopleData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PeopleData(
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      id: serializer.fromJson<int>(json['id']),
      displayName: serializer.fromJson<String>(json['displayName']),
      photoPath: serializer.fromJson<String?>(json['photoPath']),
      relationship: serializer.fromJson<String?>(json['relationship']),
      trustScore: serializer.fromJson<double>(json['trustScore']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'id': serializer.toJson<int>(id),
      'displayName': serializer.toJson<String>(displayName),
      'photoPath': serializer.toJson<String?>(photoPath),
      'relationship': serializer.toJson<String?>(relationship),
      'trustScore': serializer.toJson<double>(trustScore),
    };
  }

  PeopleData copyWith({
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
    int? id,
    String? displayName,
    Value<String?> photoPath = const Value.absent(),
    Value<String?> relationship = const Value.absent(),
    double? trustScore,
  }) => PeopleData(
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    id: id ?? this.id,
    displayName: displayName ?? this.displayName,
    photoPath: photoPath.present ? photoPath.value : this.photoPath,
    relationship: relationship.present ? relationship.value : this.relationship,
    trustScore: trustScore ?? this.trustScore,
  );
  PeopleData copyWithCompanion(PeopleCompanion data) {
    return PeopleData(
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      id: data.id.present ? data.id.value : this.id,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
      photoPath: data.photoPath.present ? data.photoPath.value : this.photoPath,
      relationship: data.relationship.present
          ? data.relationship.value
          : this.relationship,
      trustScore: data.trustScore.present
          ? data.trustScore.value
          : this.trustScore,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PeopleData(')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('id: $id, ')
          ..write('displayName: $displayName, ')
          ..write('photoPath: $photoPath, ')
          ..write('relationship: $relationship, ')
          ..write('trustScore: $trustScore')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    createdAt,
    updatedAt,
    deletedAt,
    id,
    displayName,
    photoPath,
    relationship,
    trustScore,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PeopleData &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.id == this.id &&
          other.displayName == this.displayName &&
          other.photoPath == this.photoPath &&
          other.relationship == this.relationship &&
          other.trustScore == this.trustScore);
}

class PeopleCompanion extends UpdateCompanion<PeopleData> {
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> id;
  final Value<String> displayName;
  final Value<String?> photoPath;
  final Value<String?> relationship;
  final Value<double> trustScore;
  const PeopleCompanion({
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.id = const Value.absent(),
    this.displayName = const Value.absent(),
    this.photoPath = const Value.absent(),
    this.relationship = const Value.absent(),
    this.trustScore = const Value.absent(),
  });
  PeopleCompanion.insert({
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.id = const Value.absent(),
    required String displayName,
    this.photoPath = const Value.absent(),
    this.relationship = const Value.absent(),
    this.trustScore = const Value.absent(),
  }) : displayName = Value(displayName);
  static Insertable<PeopleData> custom({
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? id,
    Expression<String>? displayName,
    Expression<String>? photoPath,
    Expression<String>? relationship,
    Expression<double>? trustScore,
  }) {
    return RawValuesInsertable({
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (id != null) 'id': id,
      if (displayName != null) 'display_name': displayName,
      if (photoPath != null) 'photo_path': photoPath,
      if (relationship != null) 'relationship': relationship,
      if (trustScore != null) 'trust_score': trustScore,
    });
  }

  PeopleCompanion copyWith({
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? id,
    Value<String>? displayName,
    Value<String?>? photoPath,
    Value<String?>? relationship,
    Value<double>? trustScore,
  }) {
    return PeopleCompanion(
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      photoPath: photoPath ?? this.photoPath,
      relationship: relationship ?? this.relationship,
      trustScore: trustScore ?? this.trustScore,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (photoPath.present) {
      map['photo_path'] = Variable<String>(photoPath.value);
    }
    if (relationship.present) {
      map['relationship'] = Variable<String>(relationship.value);
    }
    if (trustScore.present) {
      map['trust_score'] = Variable<double>(trustScore.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PeopleCompanion(')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('id: $id, ')
          ..write('displayName: $displayName, ')
          ..write('photoPath: $photoPath, ')
          ..write('relationship: $relationship, ')
          ..write('trustScore: $trustScore')
          ..write(')'))
        .toString();
  }
}

class $OrganizationsTable extends Organizations
    with TableInfo<$OrganizationsTable, Organization> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OrganizationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 300,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _websiteMeta = const VerificationMeta(
    'website',
  );
  @override
  late final GeneratedColumn<String> website = GeneratedColumn<String>(
    'website',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _websiteDomainMeta = const VerificationMeta(
    'websiteDomain',
  );
  @override
  late final GeneratedColumn<String> websiteDomain = GeneratedColumn<String>(
    'website_domain',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    createdAt,
    updatedAt,
    deletedAt,
    id,
    name,
    category,
    website,
    websiteDomain,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'organizations';
  @override
  VerificationContext validateIntegrity(
    Insertable<Organization> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    }
    if (data.containsKey('website')) {
      context.handle(
        _websiteMeta,
        website.isAcceptableOrUnknown(data['website']!, _websiteMeta),
      );
    }
    if (data.containsKey('website_domain')) {
      context.handle(
        _websiteDomainMeta,
        websiteDomain.isAcceptableOrUnknown(
          data['website_domain']!,
          _websiteDomainMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Organization map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Organization(
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      ),
      website: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}website'],
      ),
      websiteDomain: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}website_domain'],
      ),
    );
  }

  @override
  $OrganizationsTable createAlias(String alias) {
    return $OrganizationsTable(attachedDatabase, alias);
  }
}

class Organization extends DataClass implements Insertable<Organization> {
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final int id;
  final String name;
  final String? category;
  final String? website;

  /// Normalised registrable domain, used as a strong duplicate signal.
  final String? websiteDomain;
  const Organization({
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.id,
    required this.name,
    this.category,
    this.website,
    this.websiteDomain,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || category != null) {
      map['category'] = Variable<String>(category);
    }
    if (!nullToAbsent || website != null) {
      map['website'] = Variable<String>(website);
    }
    if (!nullToAbsent || websiteDomain != null) {
      map['website_domain'] = Variable<String>(websiteDomain);
    }
    return map;
  }

  OrganizationsCompanion toCompanion(bool nullToAbsent) {
    return OrganizationsCompanion(
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      id: Value(id),
      name: Value(name),
      category: category == null && nullToAbsent
          ? const Value.absent()
          : Value(category),
      website: website == null && nullToAbsent
          ? const Value.absent()
          : Value(website),
      websiteDomain: websiteDomain == null && nullToAbsent
          ? const Value.absent()
          : Value(websiteDomain),
    );
  }

  factory Organization.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Organization(
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      category: serializer.fromJson<String?>(json['category']),
      website: serializer.fromJson<String?>(json['website']),
      websiteDomain: serializer.fromJson<String?>(json['websiteDomain']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'category': serializer.toJson<String?>(category),
      'website': serializer.toJson<String?>(website),
      'websiteDomain': serializer.toJson<String?>(websiteDomain),
    };
  }

  Organization copyWith({
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
    int? id,
    String? name,
    Value<String?> category = const Value.absent(),
    Value<String?> website = const Value.absent(),
    Value<String?> websiteDomain = const Value.absent(),
  }) => Organization(
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    id: id ?? this.id,
    name: name ?? this.name,
    category: category.present ? category.value : this.category,
    website: website.present ? website.value : this.website,
    websiteDomain: websiteDomain.present
        ? websiteDomain.value
        : this.websiteDomain,
  );
  Organization copyWithCompanion(OrganizationsCompanion data) {
    return Organization(
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      category: data.category.present ? data.category.value : this.category,
      website: data.website.present ? data.website.value : this.website,
      websiteDomain: data.websiteDomain.present
          ? data.websiteDomain.value
          : this.websiteDomain,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Organization(')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('category: $category, ')
          ..write('website: $website, ')
          ..write('websiteDomain: $websiteDomain')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    createdAt,
    updatedAt,
    deletedAt,
    id,
    name,
    category,
    website,
    websiteDomain,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Organization &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.id == this.id &&
          other.name == this.name &&
          other.category == this.category &&
          other.website == this.website &&
          other.websiteDomain == this.websiteDomain);
}

class OrganizationsCompanion extends UpdateCompanion<Organization> {
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> id;
  final Value<String> name;
  final Value<String?> category;
  final Value<String?> website;
  final Value<String?> websiteDomain;
  const OrganizationsCompanion({
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.category = const Value.absent(),
    this.website = const Value.absent(),
    this.websiteDomain = const Value.absent(),
  });
  OrganizationsCompanion.insert({
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.id = const Value.absent(),
    required String name,
    this.category = const Value.absent(),
    this.website = const Value.absent(),
    this.websiteDomain = const Value.absent(),
  }) : name = Value(name);
  static Insertable<Organization> custom({
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? category,
    Expression<String>? website,
    Expression<String>? websiteDomain,
  }) {
    return RawValuesInsertable({
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (category != null) 'category': category,
      if (website != null) 'website': website,
      if (websiteDomain != null) 'website_domain': websiteDomain,
    });
  }

  OrganizationsCompanion copyWith({
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? id,
    Value<String>? name,
    Value<String?>? category,
    Value<String?>? website,
    Value<String?>? websiteDomain,
  }) {
    return OrganizationsCompanion(
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      website: website ?? this.website,
      websiteDomain: websiteDomain ?? this.websiteDomain,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (website.present) {
      map['website'] = Variable<String>(website.value);
    }
    if (websiteDomain.present) {
      map['website_domain'] = Variable<String>(websiteDomain.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OrganizationsCompanion(')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('category: $category, ')
          ..write('website: $website, ')
          ..write('websiteDomain: $websiteDomain')
          ..write(')'))
        .toString();
  }
}

class $OrgBranchesTable extends OrgBranches
    with TableInfo<$OrgBranchesTable, OrgBranche> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OrgBranchesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _orgIdMeta = const VerificationMeta('orgId');
  @override
  late final GeneratedColumn<int> orgId = GeneratedColumn<int>(
    'org_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES organizations (id)',
    ),
  );
  static const VerificationMeta _addressMeta = const VerificationMeta(
    'address',
  );
  @override
  late final GeneratedColumn<String> address = GeneratedColumn<String>(
    'address',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _latMeta = const VerificationMeta('lat');
  @override
  late final GeneratedColumn<double> lat = GeneratedColumn<double>(
    'lat',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lngMeta = const VerificationMeta('lng');
  @override
  late final GeneratedColumn<double> lng = GeneratedColumn<double>(
    'lng',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _phoneMeta = const VerificationMeta('phone');
  @override
  late final GeneratedColumn<String> phone = GeneratedColumn<String>(
    'phone',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isPrimaryMeta = const VerificationMeta(
    'isPrimary',
  );
  @override
  late final GeneratedColumn<bool> isPrimary = GeneratedColumn<bool>(
    'is_primary',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_primary" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    createdAt,
    updatedAt,
    deletedAt,
    id,
    orgId,
    address,
    lat,
    lng,
    phone,
    isPrimary,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'org_branches';
  @override
  VerificationContext validateIntegrity(
    Insertable<OrgBranche> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('org_id')) {
      context.handle(
        _orgIdMeta,
        orgId.isAcceptableOrUnknown(data['org_id']!, _orgIdMeta),
      );
    } else if (isInserting) {
      context.missing(_orgIdMeta);
    }
    if (data.containsKey('address')) {
      context.handle(
        _addressMeta,
        address.isAcceptableOrUnknown(data['address']!, _addressMeta),
      );
    }
    if (data.containsKey('lat')) {
      context.handle(
        _latMeta,
        lat.isAcceptableOrUnknown(data['lat']!, _latMeta),
      );
    }
    if (data.containsKey('lng')) {
      context.handle(
        _lngMeta,
        lng.isAcceptableOrUnknown(data['lng']!, _lngMeta),
      );
    }
    if (data.containsKey('phone')) {
      context.handle(
        _phoneMeta,
        phone.isAcceptableOrUnknown(data['phone']!, _phoneMeta),
      );
    }
    if (data.containsKey('is_primary')) {
      context.handle(
        _isPrimaryMeta,
        isPrimary.isAcceptableOrUnknown(data['is_primary']!, _isPrimaryMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OrgBranche map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OrgBranche(
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      orgId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}org_id'],
      )!,
      address: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}address'],
      ),
      lat: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}lat'],
      ),
      lng: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}lng'],
      ),
      phone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}phone'],
      ),
      isPrimary: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_primary'],
      )!,
    );
  }

  @override
  $OrgBranchesTable createAlias(String alias) {
    return $OrgBranchesTable(attachedDatabase, alias);
  }
}

class OrgBranche extends DataClass implements Insertable<OrgBranche> {
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final int id;
  final int orgId;
  final String? address;
  final double? lat;
  final double? lng;
  final String? phone;
  final bool isPrimary;
  const OrgBranche({
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.id,
    required this.orgId,
    this.address,
    this.lat,
    this.lng,
    this.phone,
    required this.isPrimary,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['id'] = Variable<int>(id);
    map['org_id'] = Variable<int>(orgId);
    if (!nullToAbsent || address != null) {
      map['address'] = Variable<String>(address);
    }
    if (!nullToAbsent || lat != null) {
      map['lat'] = Variable<double>(lat);
    }
    if (!nullToAbsent || lng != null) {
      map['lng'] = Variable<double>(lng);
    }
    if (!nullToAbsent || phone != null) {
      map['phone'] = Variable<String>(phone);
    }
    map['is_primary'] = Variable<bool>(isPrimary);
    return map;
  }

  OrgBranchesCompanion toCompanion(bool nullToAbsent) {
    return OrgBranchesCompanion(
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      id: Value(id),
      orgId: Value(orgId),
      address: address == null && nullToAbsent
          ? const Value.absent()
          : Value(address),
      lat: lat == null && nullToAbsent ? const Value.absent() : Value(lat),
      lng: lng == null && nullToAbsent ? const Value.absent() : Value(lng),
      phone: phone == null && nullToAbsent
          ? const Value.absent()
          : Value(phone),
      isPrimary: Value(isPrimary),
    );
  }

  factory OrgBranche.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OrgBranche(
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      id: serializer.fromJson<int>(json['id']),
      orgId: serializer.fromJson<int>(json['orgId']),
      address: serializer.fromJson<String?>(json['address']),
      lat: serializer.fromJson<double?>(json['lat']),
      lng: serializer.fromJson<double?>(json['lng']),
      phone: serializer.fromJson<String?>(json['phone']),
      isPrimary: serializer.fromJson<bool>(json['isPrimary']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'id': serializer.toJson<int>(id),
      'orgId': serializer.toJson<int>(orgId),
      'address': serializer.toJson<String?>(address),
      'lat': serializer.toJson<double?>(lat),
      'lng': serializer.toJson<double?>(lng),
      'phone': serializer.toJson<String?>(phone),
      'isPrimary': serializer.toJson<bool>(isPrimary),
    };
  }

  OrgBranche copyWith({
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
    int? id,
    int? orgId,
    Value<String?> address = const Value.absent(),
    Value<double?> lat = const Value.absent(),
    Value<double?> lng = const Value.absent(),
    Value<String?> phone = const Value.absent(),
    bool? isPrimary,
  }) => OrgBranche(
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    id: id ?? this.id,
    orgId: orgId ?? this.orgId,
    address: address.present ? address.value : this.address,
    lat: lat.present ? lat.value : this.lat,
    lng: lng.present ? lng.value : this.lng,
    phone: phone.present ? phone.value : this.phone,
    isPrimary: isPrimary ?? this.isPrimary,
  );
  OrgBranche copyWithCompanion(OrgBranchesCompanion data) {
    return OrgBranche(
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      id: data.id.present ? data.id.value : this.id,
      orgId: data.orgId.present ? data.orgId.value : this.orgId,
      address: data.address.present ? data.address.value : this.address,
      lat: data.lat.present ? data.lat.value : this.lat,
      lng: data.lng.present ? data.lng.value : this.lng,
      phone: data.phone.present ? data.phone.value : this.phone,
      isPrimary: data.isPrimary.present ? data.isPrimary.value : this.isPrimary,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OrgBranche(')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('id: $id, ')
          ..write('orgId: $orgId, ')
          ..write('address: $address, ')
          ..write('lat: $lat, ')
          ..write('lng: $lng, ')
          ..write('phone: $phone, ')
          ..write('isPrimary: $isPrimary')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    createdAt,
    updatedAt,
    deletedAt,
    id,
    orgId,
    address,
    lat,
    lng,
    phone,
    isPrimary,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OrgBranche &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.id == this.id &&
          other.orgId == this.orgId &&
          other.address == this.address &&
          other.lat == this.lat &&
          other.lng == this.lng &&
          other.phone == this.phone &&
          other.isPrimary == this.isPrimary);
}

class OrgBranchesCompanion extends UpdateCompanion<OrgBranche> {
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> id;
  final Value<int> orgId;
  final Value<String?> address;
  final Value<double?> lat;
  final Value<double?> lng;
  final Value<String?> phone;
  final Value<bool> isPrimary;
  const OrgBranchesCompanion({
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.id = const Value.absent(),
    this.orgId = const Value.absent(),
    this.address = const Value.absent(),
    this.lat = const Value.absent(),
    this.lng = const Value.absent(),
    this.phone = const Value.absent(),
    this.isPrimary = const Value.absent(),
  });
  OrgBranchesCompanion.insert({
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.id = const Value.absent(),
    required int orgId,
    this.address = const Value.absent(),
    this.lat = const Value.absent(),
    this.lng = const Value.absent(),
    this.phone = const Value.absent(),
    this.isPrimary = const Value.absent(),
  }) : orgId = Value(orgId);
  static Insertable<OrgBranche> custom({
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? id,
    Expression<int>? orgId,
    Expression<String>? address,
    Expression<double>? lat,
    Expression<double>? lng,
    Expression<String>? phone,
    Expression<bool>? isPrimary,
  }) {
    return RawValuesInsertable({
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (id != null) 'id': id,
      if (orgId != null) 'org_id': orgId,
      if (address != null) 'address': address,
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
      if (phone != null) 'phone': phone,
      if (isPrimary != null) 'is_primary': isPrimary,
    });
  }

  OrgBranchesCompanion copyWith({
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? id,
    Value<int>? orgId,
    Value<String?>? address,
    Value<double?>? lat,
    Value<double?>? lng,
    Value<String?>? phone,
    Value<bool>? isPrimary,
  }) {
    return OrgBranchesCompanion(
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      id: id ?? this.id,
      orgId: orgId ?? this.orgId,
      address: address ?? this.address,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      phone: phone ?? this.phone,
      isPrimary: isPrimary ?? this.isPrimary,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (orgId.present) {
      map['org_id'] = Variable<int>(orgId.value);
    }
    if (address.present) {
      map['address'] = Variable<String>(address.value);
    }
    if (lat.present) {
      map['lat'] = Variable<double>(lat.value);
    }
    if (lng.present) {
      map['lng'] = Variable<double>(lng.value);
    }
    if (phone.present) {
      map['phone'] = Variable<String>(phone.value);
    }
    if (isPrimary.present) {
      map['is_primary'] = Variable<bool>(isPrimary.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OrgBranchesCompanion(')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('id: $id, ')
          ..write('orgId: $orgId, ')
          ..write('address: $address, ')
          ..write('lat: $lat, ')
          ..write('lng: $lng, ')
          ..write('phone: $phone, ')
          ..write('isPrimary: $isPrimary')
          ..write(')'))
        .toString();
  }
}

class $RolesTable extends Roles with TableInfo<$RolesTable, Role> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RolesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _personIdMeta = const VerificationMeta(
    'personId',
  );
  @override
  late final GeneratedColumn<int> personId = GeneratedColumn<int>(
    'person_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES people (id)',
    ),
  );
  static const VerificationMeta _orgIdMeta = const VerificationMeta('orgId');
  @override
  late final GeneratedColumn<int> orgId = GeneratedColumn<int>(
    'org_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES organizations (id)',
    ),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isCurrentMeta = const VerificationMeta(
    'isCurrent',
  );
  @override
  late final GeneratedColumn<bool> isCurrent = GeneratedColumn<bool>(
    'is_current',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_current" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _startDateMeta = const VerificationMeta(
    'startDate',
  );
  @override
  late final GeneratedColumn<DateTime> startDate = GeneratedColumn<DateTime>(
    'start_date',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _endDateMeta = const VerificationMeta(
    'endDate',
  );
  @override
  late final GeneratedColumn<DateTime> endDate = GeneratedColumn<DateTime>(
    'end_date',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    createdAt,
    updatedAt,
    deletedAt,
    id,
    personId,
    orgId,
    title,
    isCurrent,
    startDate,
    endDate,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'roles';
  @override
  VerificationContext validateIntegrity(
    Insertable<Role> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('person_id')) {
      context.handle(
        _personIdMeta,
        personId.isAcceptableOrUnknown(data['person_id']!, _personIdMeta),
      );
    } else if (isInserting) {
      context.missing(_personIdMeta);
    }
    if (data.containsKey('org_id')) {
      context.handle(
        _orgIdMeta,
        orgId.isAcceptableOrUnknown(data['org_id']!, _orgIdMeta),
      );
    } else if (isInserting) {
      context.missing(_orgIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('is_current')) {
      context.handle(
        _isCurrentMeta,
        isCurrent.isAcceptableOrUnknown(data['is_current']!, _isCurrentMeta),
      );
    }
    if (data.containsKey('start_date')) {
      context.handle(
        _startDateMeta,
        startDate.isAcceptableOrUnknown(data['start_date']!, _startDateMeta),
      );
    }
    if (data.containsKey('end_date')) {
      context.handle(
        _endDateMeta,
        endDate.isAcceptableOrUnknown(data['end_date']!, _endDateMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Role map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Role(
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      personId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}person_id'],
      )!,
      orgId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}org_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      ),
      isCurrent: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_current'],
      )!,
      startDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}start_date'],
      ),
      endDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}end_date'],
      ),
    );
  }

  @override
  $RolesTable createAlias(String alias) {
    return $RolesTable(attachedDatabase, alias);
  }
}

class Role extends DataClass implements Insertable<Role> {
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final int id;
  final int personId;
  final int orgId;
  final String? title;
  final bool isCurrent;
  final DateTime? startDate;
  final DateTime? endDate;
  const Role({
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.id,
    required this.personId,
    required this.orgId,
    this.title,
    required this.isCurrent,
    this.startDate,
    this.endDate,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['id'] = Variable<int>(id);
    map['person_id'] = Variable<int>(personId);
    map['org_id'] = Variable<int>(orgId);
    if (!nullToAbsent || title != null) {
      map['title'] = Variable<String>(title);
    }
    map['is_current'] = Variable<bool>(isCurrent);
    if (!nullToAbsent || startDate != null) {
      map['start_date'] = Variable<DateTime>(startDate);
    }
    if (!nullToAbsent || endDate != null) {
      map['end_date'] = Variable<DateTime>(endDate);
    }
    return map;
  }

  RolesCompanion toCompanion(bool nullToAbsent) {
    return RolesCompanion(
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      id: Value(id),
      personId: Value(personId),
      orgId: Value(orgId),
      title: title == null && nullToAbsent
          ? const Value.absent()
          : Value(title),
      isCurrent: Value(isCurrent),
      startDate: startDate == null && nullToAbsent
          ? const Value.absent()
          : Value(startDate),
      endDate: endDate == null && nullToAbsent
          ? const Value.absent()
          : Value(endDate),
    );
  }

  factory Role.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Role(
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      id: serializer.fromJson<int>(json['id']),
      personId: serializer.fromJson<int>(json['personId']),
      orgId: serializer.fromJson<int>(json['orgId']),
      title: serializer.fromJson<String?>(json['title']),
      isCurrent: serializer.fromJson<bool>(json['isCurrent']),
      startDate: serializer.fromJson<DateTime?>(json['startDate']),
      endDate: serializer.fromJson<DateTime?>(json['endDate']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'id': serializer.toJson<int>(id),
      'personId': serializer.toJson<int>(personId),
      'orgId': serializer.toJson<int>(orgId),
      'title': serializer.toJson<String?>(title),
      'isCurrent': serializer.toJson<bool>(isCurrent),
      'startDate': serializer.toJson<DateTime?>(startDate),
      'endDate': serializer.toJson<DateTime?>(endDate),
    };
  }

  Role copyWith({
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
    int? id,
    int? personId,
    int? orgId,
    Value<String?> title = const Value.absent(),
    bool? isCurrent,
    Value<DateTime?> startDate = const Value.absent(),
    Value<DateTime?> endDate = const Value.absent(),
  }) => Role(
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    id: id ?? this.id,
    personId: personId ?? this.personId,
    orgId: orgId ?? this.orgId,
    title: title.present ? title.value : this.title,
    isCurrent: isCurrent ?? this.isCurrent,
    startDate: startDate.present ? startDate.value : this.startDate,
    endDate: endDate.present ? endDate.value : this.endDate,
  );
  Role copyWithCompanion(RolesCompanion data) {
    return Role(
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      id: data.id.present ? data.id.value : this.id,
      personId: data.personId.present ? data.personId.value : this.personId,
      orgId: data.orgId.present ? data.orgId.value : this.orgId,
      title: data.title.present ? data.title.value : this.title,
      isCurrent: data.isCurrent.present ? data.isCurrent.value : this.isCurrent,
      startDate: data.startDate.present ? data.startDate.value : this.startDate,
      endDate: data.endDate.present ? data.endDate.value : this.endDate,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Role(')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('id: $id, ')
          ..write('personId: $personId, ')
          ..write('orgId: $orgId, ')
          ..write('title: $title, ')
          ..write('isCurrent: $isCurrent, ')
          ..write('startDate: $startDate, ')
          ..write('endDate: $endDate')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    createdAt,
    updatedAt,
    deletedAt,
    id,
    personId,
    orgId,
    title,
    isCurrent,
    startDate,
    endDate,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Role &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.id == this.id &&
          other.personId == this.personId &&
          other.orgId == this.orgId &&
          other.title == this.title &&
          other.isCurrent == this.isCurrent &&
          other.startDate == this.startDate &&
          other.endDate == this.endDate);
}

class RolesCompanion extends UpdateCompanion<Role> {
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> id;
  final Value<int> personId;
  final Value<int> orgId;
  final Value<String?> title;
  final Value<bool> isCurrent;
  final Value<DateTime?> startDate;
  final Value<DateTime?> endDate;
  const RolesCompanion({
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.id = const Value.absent(),
    this.personId = const Value.absent(),
    this.orgId = const Value.absent(),
    this.title = const Value.absent(),
    this.isCurrent = const Value.absent(),
    this.startDate = const Value.absent(),
    this.endDate = const Value.absent(),
  });
  RolesCompanion.insert({
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.id = const Value.absent(),
    required int personId,
    required int orgId,
    this.title = const Value.absent(),
    this.isCurrent = const Value.absent(),
    this.startDate = const Value.absent(),
    this.endDate = const Value.absent(),
  }) : personId = Value(personId),
       orgId = Value(orgId);
  static Insertable<Role> custom({
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? id,
    Expression<int>? personId,
    Expression<int>? orgId,
    Expression<String>? title,
    Expression<bool>? isCurrent,
    Expression<DateTime>? startDate,
    Expression<DateTime>? endDate,
  }) {
    return RawValuesInsertable({
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (id != null) 'id': id,
      if (personId != null) 'person_id': personId,
      if (orgId != null) 'org_id': orgId,
      if (title != null) 'title': title,
      if (isCurrent != null) 'is_current': isCurrent,
      if (startDate != null) 'start_date': startDate,
      if (endDate != null) 'end_date': endDate,
    });
  }

  RolesCompanion copyWith({
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? id,
    Value<int>? personId,
    Value<int>? orgId,
    Value<String?>? title,
    Value<bool>? isCurrent,
    Value<DateTime?>? startDate,
    Value<DateTime?>? endDate,
  }) {
    return RolesCompanion(
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      id: id ?? this.id,
      personId: personId ?? this.personId,
      orgId: orgId ?? this.orgId,
      title: title ?? this.title,
      isCurrent: isCurrent ?? this.isCurrent,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (personId.present) {
      map['person_id'] = Variable<int>(personId.value);
    }
    if (orgId.present) {
      map['org_id'] = Variable<int>(orgId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (isCurrent.present) {
      map['is_current'] = Variable<bool>(isCurrent.value);
    }
    if (startDate.present) {
      map['start_date'] = Variable<DateTime>(startDate.value);
    }
    if (endDate.present) {
      map['end_date'] = Variable<DateTime>(endDate.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RolesCompanion(')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('id: $id, ')
          ..write('personId: $personId, ')
          ..write('orgId: $orgId, ')
          ..write('title: $title, ')
          ..write('isCurrent: $isCurrent, ')
          ..write('startDate: $startDate, ')
          ..write('endDate: $endDate')
          ..write(')'))
        .toString();
  }
}

class $CardsTable extends Cards with TableInfo<$CardsTable, CardRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CardsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<CardType, String> type =
      GeneratedColumn<String>(
        'type',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: Constant(CardType.unknown.name),
      ).withConverter<CardType>($CardsTable.$convertertype);
  static const VerificationMeta _imagePathMeta = const VerificationMeta(
    'imagePath',
  );
  @override
  late final GeneratedColumn<String> imagePath = GeneratedColumn<String>(
    'image_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _backImagePathMeta = const VerificationMeta(
    'backImagePath',
  );
  @override
  late final GeneratedColumn<String> backImagePath = GeneratedColumn<String>(
    'back_image_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _thumbPathMeta = const VerificationMeta(
    'thumbPath',
  );
  @override
  late final GeneratedColumn<String> thumbPath = GeneratedColumn<String>(
    'thumb_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _rawOcrTextMeta = const VerificationMeta(
    'rawOcrText',
  );
  @override
  late final GeneratedColumn<String> rawOcrText = GeneratedColumn<String>(
    'raw_ocr_text',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ocrEngineMeta = const VerificationMeta(
    'ocrEngine',
  );
  @override
  late final GeneratedColumn<String> ocrEngine = GeneratedColumn<String>(
    'ocr_engine',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ocrConfidenceMeta = const VerificationMeta(
    'ocrConfidence',
  );
  @override
  late final GeneratedColumn<double> ocrConfidence = GeneratedColumn<double>(
    'ocr_confidence',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<ExtractionStatus, String>
  extractionStatus = GeneratedColumn<String>(
    'extraction_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: Constant(ExtractionStatus.pending.name),
  ).withConverter<ExtractionStatus>($CardsTable.$converterextractionStatus);
  static const VerificationMeta _capturedAtMeta = const VerificationMeta(
    'capturedAt',
  );
  @override
  late final GeneratedColumn<DateTime> capturedAt = GeneratedColumn<DateTime>(
    'captured_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _personIdMeta = const VerificationMeta(
    'personId',
  );
  @override
  late final GeneratedColumn<int> personId = GeneratedColumn<int>(
    'person_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES people (id)',
    ),
  );
  static const VerificationMeta _orgIdMeta = const VerificationMeta('orgId');
  @override
  late final GeneratedColumn<int> orgId = GeneratedColumn<int>(
    'org_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES organizations (id)',
    ),
  );
  static const VerificationMeta _roleIdMeta = const VerificationMeta('roleId');
  @override
  late final GeneratedColumn<int> roleId = GeneratedColumn<int>(
    'role_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES roles (id)',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [
    createdAt,
    updatedAt,
    deletedAt,
    id,
    type,
    imagePath,
    backImagePath,
    thumbPath,
    rawOcrText,
    ocrEngine,
    ocrConfidence,
    extractionStatus,
    capturedAt,
    personId,
    orgId,
    roleId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cards';
  @override
  VerificationContext validateIntegrity(
    Insertable<CardRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('image_path')) {
      context.handle(
        _imagePathMeta,
        imagePath.isAcceptableOrUnknown(data['image_path']!, _imagePathMeta),
      );
    } else if (isInserting) {
      context.missing(_imagePathMeta);
    }
    if (data.containsKey('back_image_path')) {
      context.handle(
        _backImagePathMeta,
        backImagePath.isAcceptableOrUnknown(
          data['back_image_path']!,
          _backImagePathMeta,
        ),
      );
    }
    if (data.containsKey('thumb_path')) {
      context.handle(
        _thumbPathMeta,
        thumbPath.isAcceptableOrUnknown(data['thumb_path']!, _thumbPathMeta),
      );
    }
    if (data.containsKey('raw_ocr_text')) {
      context.handle(
        _rawOcrTextMeta,
        rawOcrText.isAcceptableOrUnknown(
          data['raw_ocr_text']!,
          _rawOcrTextMeta,
        ),
      );
    }
    if (data.containsKey('ocr_engine')) {
      context.handle(
        _ocrEngineMeta,
        ocrEngine.isAcceptableOrUnknown(data['ocr_engine']!, _ocrEngineMeta),
      );
    }
    if (data.containsKey('ocr_confidence')) {
      context.handle(
        _ocrConfidenceMeta,
        ocrConfidence.isAcceptableOrUnknown(
          data['ocr_confidence']!,
          _ocrConfidenceMeta,
        ),
      );
    }
    if (data.containsKey('captured_at')) {
      context.handle(
        _capturedAtMeta,
        capturedAt.isAcceptableOrUnknown(data['captured_at']!, _capturedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_capturedAtMeta);
    }
    if (data.containsKey('person_id')) {
      context.handle(
        _personIdMeta,
        personId.isAcceptableOrUnknown(data['person_id']!, _personIdMeta),
      );
    }
    if (data.containsKey('org_id')) {
      context.handle(
        _orgIdMeta,
        orgId.isAcceptableOrUnknown(data['org_id']!, _orgIdMeta),
      );
    }
    if (data.containsKey('role_id')) {
      context.handle(
        _roleIdMeta,
        roleId.isAcceptableOrUnknown(data['role_id']!, _roleIdMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CardRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CardRow(
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      type: $CardsTable.$convertertype.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}type'],
        )!,
      ),
      imagePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_path'],
      )!,
      backImagePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}back_image_path'],
      ),
      thumbPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}thumb_path'],
      ),
      rawOcrText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}raw_ocr_text'],
      ),
      ocrEngine: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ocr_engine'],
      ),
      ocrConfidence: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}ocr_confidence'],
      ),
      extractionStatus: $CardsTable.$converterextractionStatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}extraction_status'],
        )!,
      ),
      capturedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}captured_at'],
      )!,
      personId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}person_id'],
      ),
      orgId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}org_id'],
      ),
      roleId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}role_id'],
      ),
    );
  }

  @override
  $CardsTable createAlias(String alias) {
    return $CardsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<CardType, String, String> $convertertype =
      const EnumNameConverter<CardType>(CardType.values);
  static JsonTypeConverter2<ExtractionStatus, String, String>
  $converterextractionStatus = const EnumNameConverter<ExtractionStatus>(
    ExtractionStatus.values,
  );
}

class CardRow extends DataClass implements Insertable<CardRow> {
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final int id;
  final CardType type;

  /// Full-resolution capture. Re-running OCR later needs the pixels, so this is
  /// kept until the user chooses otherwise.
  final String imagePath;
  final String? backImagePath;
  final String? thumbPath;

  /// Everything the engines read, joined. Feeds keyword search and gives the
  /// user something to read themselves when field assignment failed.
  final String? rawOcrText;

  /// Engine or routing strategy that produced the current fields.
  final String? ocrEngine;
  final double? ocrConfidence;
  final ExtractionStatus extractionStatus;
  final DateTime capturedAt;
  final int? personId;
  final int? orgId;
  final int? roleId;
  const CardRow({
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.id,
    required this.type,
    required this.imagePath,
    this.backImagePath,
    this.thumbPath,
    this.rawOcrText,
    this.ocrEngine,
    this.ocrConfidence,
    required this.extractionStatus,
    required this.capturedAt,
    this.personId,
    this.orgId,
    this.roleId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['id'] = Variable<int>(id);
    {
      map['type'] = Variable<String>($CardsTable.$convertertype.toSql(type));
    }
    map['image_path'] = Variable<String>(imagePath);
    if (!nullToAbsent || backImagePath != null) {
      map['back_image_path'] = Variable<String>(backImagePath);
    }
    if (!nullToAbsent || thumbPath != null) {
      map['thumb_path'] = Variable<String>(thumbPath);
    }
    if (!nullToAbsent || rawOcrText != null) {
      map['raw_ocr_text'] = Variable<String>(rawOcrText);
    }
    if (!nullToAbsent || ocrEngine != null) {
      map['ocr_engine'] = Variable<String>(ocrEngine);
    }
    if (!nullToAbsent || ocrConfidence != null) {
      map['ocr_confidence'] = Variable<double>(ocrConfidence);
    }
    {
      map['extraction_status'] = Variable<String>(
        $CardsTable.$converterextractionStatus.toSql(extractionStatus),
      );
    }
    map['captured_at'] = Variable<DateTime>(capturedAt);
    if (!nullToAbsent || personId != null) {
      map['person_id'] = Variable<int>(personId);
    }
    if (!nullToAbsent || orgId != null) {
      map['org_id'] = Variable<int>(orgId);
    }
    if (!nullToAbsent || roleId != null) {
      map['role_id'] = Variable<int>(roleId);
    }
    return map;
  }

  CardsCompanion toCompanion(bool nullToAbsent) {
    return CardsCompanion(
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      id: Value(id),
      type: Value(type),
      imagePath: Value(imagePath),
      backImagePath: backImagePath == null && nullToAbsent
          ? const Value.absent()
          : Value(backImagePath),
      thumbPath: thumbPath == null && nullToAbsent
          ? const Value.absent()
          : Value(thumbPath),
      rawOcrText: rawOcrText == null && nullToAbsent
          ? const Value.absent()
          : Value(rawOcrText),
      ocrEngine: ocrEngine == null && nullToAbsent
          ? const Value.absent()
          : Value(ocrEngine),
      ocrConfidence: ocrConfidence == null && nullToAbsent
          ? const Value.absent()
          : Value(ocrConfidence),
      extractionStatus: Value(extractionStatus),
      capturedAt: Value(capturedAt),
      personId: personId == null && nullToAbsent
          ? const Value.absent()
          : Value(personId),
      orgId: orgId == null && nullToAbsent
          ? const Value.absent()
          : Value(orgId),
      roleId: roleId == null && nullToAbsent
          ? const Value.absent()
          : Value(roleId),
    );
  }

  factory CardRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CardRow(
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      id: serializer.fromJson<int>(json['id']),
      type: $CardsTable.$convertertype.fromJson(
        serializer.fromJson<String>(json['type']),
      ),
      imagePath: serializer.fromJson<String>(json['imagePath']),
      backImagePath: serializer.fromJson<String?>(json['backImagePath']),
      thumbPath: serializer.fromJson<String?>(json['thumbPath']),
      rawOcrText: serializer.fromJson<String?>(json['rawOcrText']),
      ocrEngine: serializer.fromJson<String?>(json['ocrEngine']),
      ocrConfidence: serializer.fromJson<double?>(json['ocrConfidence']),
      extractionStatus: $CardsTable.$converterextractionStatus.fromJson(
        serializer.fromJson<String>(json['extractionStatus']),
      ),
      capturedAt: serializer.fromJson<DateTime>(json['capturedAt']),
      personId: serializer.fromJson<int?>(json['personId']),
      orgId: serializer.fromJson<int?>(json['orgId']),
      roleId: serializer.fromJson<int?>(json['roleId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'id': serializer.toJson<int>(id),
      'type': serializer.toJson<String>(
        $CardsTable.$convertertype.toJson(type),
      ),
      'imagePath': serializer.toJson<String>(imagePath),
      'backImagePath': serializer.toJson<String?>(backImagePath),
      'thumbPath': serializer.toJson<String?>(thumbPath),
      'rawOcrText': serializer.toJson<String?>(rawOcrText),
      'ocrEngine': serializer.toJson<String?>(ocrEngine),
      'ocrConfidence': serializer.toJson<double?>(ocrConfidence),
      'extractionStatus': serializer.toJson<String>(
        $CardsTable.$converterextractionStatus.toJson(extractionStatus),
      ),
      'capturedAt': serializer.toJson<DateTime>(capturedAt),
      'personId': serializer.toJson<int?>(personId),
      'orgId': serializer.toJson<int?>(orgId),
      'roleId': serializer.toJson<int?>(roleId),
    };
  }

  CardRow copyWith({
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
    int? id,
    CardType? type,
    String? imagePath,
    Value<String?> backImagePath = const Value.absent(),
    Value<String?> thumbPath = const Value.absent(),
    Value<String?> rawOcrText = const Value.absent(),
    Value<String?> ocrEngine = const Value.absent(),
    Value<double?> ocrConfidence = const Value.absent(),
    ExtractionStatus? extractionStatus,
    DateTime? capturedAt,
    Value<int?> personId = const Value.absent(),
    Value<int?> orgId = const Value.absent(),
    Value<int?> roleId = const Value.absent(),
  }) => CardRow(
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    id: id ?? this.id,
    type: type ?? this.type,
    imagePath: imagePath ?? this.imagePath,
    backImagePath: backImagePath.present
        ? backImagePath.value
        : this.backImagePath,
    thumbPath: thumbPath.present ? thumbPath.value : this.thumbPath,
    rawOcrText: rawOcrText.present ? rawOcrText.value : this.rawOcrText,
    ocrEngine: ocrEngine.present ? ocrEngine.value : this.ocrEngine,
    ocrConfidence: ocrConfidence.present
        ? ocrConfidence.value
        : this.ocrConfidence,
    extractionStatus: extractionStatus ?? this.extractionStatus,
    capturedAt: capturedAt ?? this.capturedAt,
    personId: personId.present ? personId.value : this.personId,
    orgId: orgId.present ? orgId.value : this.orgId,
    roleId: roleId.present ? roleId.value : this.roleId,
  );
  CardRow copyWithCompanion(CardsCompanion data) {
    return CardRow(
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      id: data.id.present ? data.id.value : this.id,
      type: data.type.present ? data.type.value : this.type,
      imagePath: data.imagePath.present ? data.imagePath.value : this.imagePath,
      backImagePath: data.backImagePath.present
          ? data.backImagePath.value
          : this.backImagePath,
      thumbPath: data.thumbPath.present ? data.thumbPath.value : this.thumbPath,
      rawOcrText: data.rawOcrText.present
          ? data.rawOcrText.value
          : this.rawOcrText,
      ocrEngine: data.ocrEngine.present ? data.ocrEngine.value : this.ocrEngine,
      ocrConfidence: data.ocrConfidence.present
          ? data.ocrConfidence.value
          : this.ocrConfidence,
      extractionStatus: data.extractionStatus.present
          ? data.extractionStatus.value
          : this.extractionStatus,
      capturedAt: data.capturedAt.present
          ? data.capturedAt.value
          : this.capturedAt,
      personId: data.personId.present ? data.personId.value : this.personId,
      orgId: data.orgId.present ? data.orgId.value : this.orgId,
      roleId: data.roleId.present ? data.roleId.value : this.roleId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CardRow(')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('imagePath: $imagePath, ')
          ..write('backImagePath: $backImagePath, ')
          ..write('thumbPath: $thumbPath, ')
          ..write('rawOcrText: $rawOcrText, ')
          ..write('ocrEngine: $ocrEngine, ')
          ..write('ocrConfidence: $ocrConfidence, ')
          ..write('extractionStatus: $extractionStatus, ')
          ..write('capturedAt: $capturedAt, ')
          ..write('personId: $personId, ')
          ..write('orgId: $orgId, ')
          ..write('roleId: $roleId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    createdAt,
    updatedAt,
    deletedAt,
    id,
    type,
    imagePath,
    backImagePath,
    thumbPath,
    rawOcrText,
    ocrEngine,
    ocrConfidence,
    extractionStatus,
    capturedAt,
    personId,
    orgId,
    roleId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CardRow &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.id == this.id &&
          other.type == this.type &&
          other.imagePath == this.imagePath &&
          other.backImagePath == this.backImagePath &&
          other.thumbPath == this.thumbPath &&
          other.rawOcrText == this.rawOcrText &&
          other.ocrEngine == this.ocrEngine &&
          other.ocrConfidence == this.ocrConfidence &&
          other.extractionStatus == this.extractionStatus &&
          other.capturedAt == this.capturedAt &&
          other.personId == this.personId &&
          other.orgId == this.orgId &&
          other.roleId == this.roleId);
}

class CardsCompanion extends UpdateCompanion<CardRow> {
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> id;
  final Value<CardType> type;
  final Value<String> imagePath;
  final Value<String?> backImagePath;
  final Value<String?> thumbPath;
  final Value<String?> rawOcrText;
  final Value<String?> ocrEngine;
  final Value<double?> ocrConfidence;
  final Value<ExtractionStatus> extractionStatus;
  final Value<DateTime> capturedAt;
  final Value<int?> personId;
  final Value<int?> orgId;
  final Value<int?> roleId;
  const CardsCompanion({
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.id = const Value.absent(),
    this.type = const Value.absent(),
    this.imagePath = const Value.absent(),
    this.backImagePath = const Value.absent(),
    this.thumbPath = const Value.absent(),
    this.rawOcrText = const Value.absent(),
    this.ocrEngine = const Value.absent(),
    this.ocrConfidence = const Value.absent(),
    this.extractionStatus = const Value.absent(),
    this.capturedAt = const Value.absent(),
    this.personId = const Value.absent(),
    this.orgId = const Value.absent(),
    this.roleId = const Value.absent(),
  });
  CardsCompanion.insert({
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.id = const Value.absent(),
    this.type = const Value.absent(),
    required String imagePath,
    this.backImagePath = const Value.absent(),
    this.thumbPath = const Value.absent(),
    this.rawOcrText = const Value.absent(),
    this.ocrEngine = const Value.absent(),
    this.ocrConfidence = const Value.absent(),
    this.extractionStatus = const Value.absent(),
    required DateTime capturedAt,
    this.personId = const Value.absent(),
    this.orgId = const Value.absent(),
    this.roleId = const Value.absent(),
  }) : imagePath = Value(imagePath),
       capturedAt = Value(capturedAt);
  static Insertable<CardRow> custom({
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? id,
    Expression<String>? type,
    Expression<String>? imagePath,
    Expression<String>? backImagePath,
    Expression<String>? thumbPath,
    Expression<String>? rawOcrText,
    Expression<String>? ocrEngine,
    Expression<double>? ocrConfidence,
    Expression<String>? extractionStatus,
    Expression<DateTime>? capturedAt,
    Expression<int>? personId,
    Expression<int>? orgId,
    Expression<int>? roleId,
  }) {
    return RawValuesInsertable({
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (id != null) 'id': id,
      if (type != null) 'type': type,
      if (imagePath != null) 'image_path': imagePath,
      if (backImagePath != null) 'back_image_path': backImagePath,
      if (thumbPath != null) 'thumb_path': thumbPath,
      if (rawOcrText != null) 'raw_ocr_text': rawOcrText,
      if (ocrEngine != null) 'ocr_engine': ocrEngine,
      if (ocrConfidence != null) 'ocr_confidence': ocrConfidence,
      if (extractionStatus != null) 'extraction_status': extractionStatus,
      if (capturedAt != null) 'captured_at': capturedAt,
      if (personId != null) 'person_id': personId,
      if (orgId != null) 'org_id': orgId,
      if (roleId != null) 'role_id': roleId,
    });
  }

  CardsCompanion copyWith({
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? id,
    Value<CardType>? type,
    Value<String>? imagePath,
    Value<String?>? backImagePath,
    Value<String?>? thumbPath,
    Value<String?>? rawOcrText,
    Value<String?>? ocrEngine,
    Value<double?>? ocrConfidence,
    Value<ExtractionStatus>? extractionStatus,
    Value<DateTime>? capturedAt,
    Value<int?>? personId,
    Value<int?>? orgId,
    Value<int?>? roleId,
  }) {
    return CardsCompanion(
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      id: id ?? this.id,
      type: type ?? this.type,
      imagePath: imagePath ?? this.imagePath,
      backImagePath: backImagePath ?? this.backImagePath,
      thumbPath: thumbPath ?? this.thumbPath,
      rawOcrText: rawOcrText ?? this.rawOcrText,
      ocrEngine: ocrEngine ?? this.ocrEngine,
      ocrConfidence: ocrConfidence ?? this.ocrConfidence,
      extractionStatus: extractionStatus ?? this.extractionStatus,
      capturedAt: capturedAt ?? this.capturedAt,
      personId: personId ?? this.personId,
      orgId: orgId ?? this.orgId,
      roleId: roleId ?? this.roleId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(
        $CardsTable.$convertertype.toSql(type.value),
      );
    }
    if (imagePath.present) {
      map['image_path'] = Variable<String>(imagePath.value);
    }
    if (backImagePath.present) {
      map['back_image_path'] = Variable<String>(backImagePath.value);
    }
    if (thumbPath.present) {
      map['thumb_path'] = Variable<String>(thumbPath.value);
    }
    if (rawOcrText.present) {
      map['raw_ocr_text'] = Variable<String>(rawOcrText.value);
    }
    if (ocrEngine.present) {
      map['ocr_engine'] = Variable<String>(ocrEngine.value);
    }
    if (ocrConfidence.present) {
      map['ocr_confidence'] = Variable<double>(ocrConfidence.value);
    }
    if (extractionStatus.present) {
      map['extraction_status'] = Variable<String>(
        $CardsTable.$converterextractionStatus.toSql(extractionStatus.value),
      );
    }
    if (capturedAt.present) {
      map['captured_at'] = Variable<DateTime>(capturedAt.value);
    }
    if (personId.present) {
      map['person_id'] = Variable<int>(personId.value);
    }
    if (orgId.present) {
      map['org_id'] = Variable<int>(orgId.value);
    }
    if (roleId.present) {
      map['role_id'] = Variable<int>(roleId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CardsCompanion(')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('imagePath: $imagePath, ')
          ..write('backImagePath: $backImagePath, ')
          ..write('thumbPath: $thumbPath, ')
          ..write('rawOcrText: $rawOcrText, ')
          ..write('ocrEngine: $ocrEngine, ')
          ..write('ocrConfidence: $ocrConfidence, ')
          ..write('extractionStatus: $extractionStatus, ')
          ..write('capturedAt: $capturedAt, ')
          ..write('personId: $personId, ')
          ..write('orgId: $orgId, ')
          ..write('roleId: $roleId')
          ..write(')'))
        .toString();
  }
}

class $CardFieldsTable extends CardFields
    with TableInfo<$CardFieldsTable, CardField> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CardFieldsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _cardIdMeta = const VerificationMeta('cardId');
  @override
  late final GeneratedColumn<int> cardId = GeneratedColumn<int>(
    'card_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES cards (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _fieldKeyMeta = const VerificationMeta(
    'fieldKey',
  );
  @override
  late final GeneratedColumn<String> fieldKey = GeneratedColumn<String>(
    'field_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _normalizedValueMeta = const VerificationMeta(
    'normalizedValue',
  );
  @override
  late final GeneratedColumn<String> normalizedValue = GeneratedColumn<String>(
    'normalized_value',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<FactSource, String> source =
      GeneratedColumn<String>(
        'source',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<FactSource>($CardFieldsTable.$convertersource);
  static const VerificationMeta _confidenceMeta = const VerificationMeta(
    'confidence',
  );
  @override
  late final GeneratedColumn<double> confidence = GeneratedColumn<double>(
    'confidence',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _verifiedByUserMeta = const VerificationMeta(
    'verifiedByUser',
  );
  @override
  late final GeneratedColumn<bool> verifiedByUser = GeneratedColumn<bool>(
    'verified_by_user',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("verified_by_user" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _validationIssueMeta = const VerificationMeta(
    'validationIssue',
  );
  @override
  late final GeneratedColumn<String> validationIssue = GeneratedColumn<String>(
    'validation_issue',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<FieldValueKind, String>
  valueKind = GeneratedColumn<String>(
    'value_kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: Constant(FieldValueKind.text.name),
  ).withConverter<FieldValueKind>($CardFieldsTable.$convertervalueKind);
  static const VerificationMeta _regionRectMeta = const VerificationMeta(
    'regionRect',
  );
  @override
  late final GeneratedColumn<String> regionRect = GeneratedColumn<String>(
    'region_rect',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    createdAt,
    updatedAt,
    deletedAt,
    id,
    cardId,
    fieldKey,
    value,
    normalizedValue,
    source,
    confidence,
    verifiedByUser,
    validationIssue,
    valueKind,
    regionRect,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'card_fields';
  @override
  VerificationContext validateIntegrity(
    Insertable<CardField> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('card_id')) {
      context.handle(
        _cardIdMeta,
        cardId.isAcceptableOrUnknown(data['card_id']!, _cardIdMeta),
      );
    } else if (isInserting) {
      context.missing(_cardIdMeta);
    }
    if (data.containsKey('field_key')) {
      context.handle(
        _fieldKeyMeta,
        fieldKey.isAcceptableOrUnknown(data['field_key']!, _fieldKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_fieldKeyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    if (data.containsKey('normalized_value')) {
      context.handle(
        _normalizedValueMeta,
        normalizedValue.isAcceptableOrUnknown(
          data['normalized_value']!,
          _normalizedValueMeta,
        ),
      );
    }
    if (data.containsKey('confidence')) {
      context.handle(
        _confidenceMeta,
        confidence.isAcceptableOrUnknown(data['confidence']!, _confidenceMeta),
      );
    }
    if (data.containsKey('verified_by_user')) {
      context.handle(
        _verifiedByUserMeta,
        verifiedByUser.isAcceptableOrUnknown(
          data['verified_by_user']!,
          _verifiedByUserMeta,
        ),
      );
    }
    if (data.containsKey('validation_issue')) {
      context.handle(
        _validationIssueMeta,
        validationIssue.isAcceptableOrUnknown(
          data['validation_issue']!,
          _validationIssueMeta,
        ),
      );
    }
    if (data.containsKey('region_rect')) {
      context.handle(
        _regionRectMeta,
        regionRect.isAcceptableOrUnknown(data['region_rect']!, _regionRectMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CardField map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CardField(
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      cardId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}card_id'],
      )!,
      fieldKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}field_key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
      normalizedValue: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}normalized_value'],
      ),
      source: $CardFieldsTable.$convertersource.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}source'],
        )!,
      ),
      confidence: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}confidence'],
      ),
      verifiedByUser: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}verified_by_user'],
      )!,
      validationIssue: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}validation_issue'],
      ),
      valueKind: $CardFieldsTable.$convertervalueKind.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}value_kind'],
        )!,
      ),
      regionRect: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}region_rect'],
      ),
    );
  }

  @override
  $CardFieldsTable createAlias(String alias) {
    return $CardFieldsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<FactSource, String, String> $convertersource =
      const EnumNameConverter<FactSource>(FactSource.values);
  static JsonTypeConverter2<FieldValueKind, String, String>
  $convertervalueKind = const EnumNameConverter<FieldValueKind>(
    FieldValueKind.values,
  );
}

class CardField extends DataClass implements Insertable<CardField> {
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final int id;
  final int cardId;

  /// Controlled vocabulary: `person_name`, `company`, `designation`,
  /// `phone`, `email`, `website`, `address`, `services`.
  final String fieldKey;
  final String value;

  /// Canonical form for matching: E.164 phones, lowercased emails, bare domains.
  final String? normalizedValue;
  final FactSource source;
  final double? confidence;

  /// True once the user has confirmed or corrected this. Drives the manual
  /// correction rate metric, straight out of real usage.
  final bool verifiedByUser;

  /// Set when a validator disagreed with the extracted value — an 8-digit
  /// "mobile", an email with no plausible TLD. Flagged, never silently kept.
  final String? validationIssue;
  final FieldValueKind valueKind;

  /// "left,top,right,bottom" in the source image's coordinate space.
  final String? regionRect;
  const CardField({
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.id,
    required this.cardId,
    required this.fieldKey,
    required this.value,
    this.normalizedValue,
    required this.source,
    this.confidence,
    required this.verifiedByUser,
    this.validationIssue,
    required this.valueKind,
    this.regionRect,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['id'] = Variable<int>(id);
    map['card_id'] = Variable<int>(cardId);
    map['field_key'] = Variable<String>(fieldKey);
    map['value'] = Variable<String>(value);
    if (!nullToAbsent || normalizedValue != null) {
      map['normalized_value'] = Variable<String>(normalizedValue);
    }
    {
      map['source'] = Variable<String>(
        $CardFieldsTable.$convertersource.toSql(source),
      );
    }
    if (!nullToAbsent || confidence != null) {
      map['confidence'] = Variable<double>(confidence);
    }
    map['verified_by_user'] = Variable<bool>(verifiedByUser);
    if (!nullToAbsent || validationIssue != null) {
      map['validation_issue'] = Variable<String>(validationIssue);
    }
    {
      map['value_kind'] = Variable<String>(
        $CardFieldsTable.$convertervalueKind.toSql(valueKind),
      );
    }
    if (!nullToAbsent || regionRect != null) {
      map['region_rect'] = Variable<String>(regionRect);
    }
    return map;
  }

  CardFieldsCompanion toCompanion(bool nullToAbsent) {
    return CardFieldsCompanion(
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      id: Value(id),
      cardId: Value(cardId),
      fieldKey: Value(fieldKey),
      value: Value(value),
      normalizedValue: normalizedValue == null && nullToAbsent
          ? const Value.absent()
          : Value(normalizedValue),
      source: Value(source),
      confidence: confidence == null && nullToAbsent
          ? const Value.absent()
          : Value(confidence),
      verifiedByUser: Value(verifiedByUser),
      validationIssue: validationIssue == null && nullToAbsent
          ? const Value.absent()
          : Value(validationIssue),
      valueKind: Value(valueKind),
      regionRect: regionRect == null && nullToAbsent
          ? const Value.absent()
          : Value(regionRect),
    );
  }

  factory CardField.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CardField(
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      id: serializer.fromJson<int>(json['id']),
      cardId: serializer.fromJson<int>(json['cardId']),
      fieldKey: serializer.fromJson<String>(json['fieldKey']),
      value: serializer.fromJson<String>(json['value']),
      normalizedValue: serializer.fromJson<String?>(json['normalizedValue']),
      source: $CardFieldsTable.$convertersource.fromJson(
        serializer.fromJson<String>(json['source']),
      ),
      confidence: serializer.fromJson<double?>(json['confidence']),
      verifiedByUser: serializer.fromJson<bool>(json['verifiedByUser']),
      validationIssue: serializer.fromJson<String?>(json['validationIssue']),
      valueKind: $CardFieldsTable.$convertervalueKind.fromJson(
        serializer.fromJson<String>(json['valueKind']),
      ),
      regionRect: serializer.fromJson<String?>(json['regionRect']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'id': serializer.toJson<int>(id),
      'cardId': serializer.toJson<int>(cardId),
      'fieldKey': serializer.toJson<String>(fieldKey),
      'value': serializer.toJson<String>(value),
      'normalizedValue': serializer.toJson<String?>(normalizedValue),
      'source': serializer.toJson<String>(
        $CardFieldsTable.$convertersource.toJson(source),
      ),
      'confidence': serializer.toJson<double?>(confidence),
      'verifiedByUser': serializer.toJson<bool>(verifiedByUser),
      'validationIssue': serializer.toJson<String?>(validationIssue),
      'valueKind': serializer.toJson<String>(
        $CardFieldsTable.$convertervalueKind.toJson(valueKind),
      ),
      'regionRect': serializer.toJson<String?>(regionRect),
    };
  }

  CardField copyWith({
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
    int? id,
    int? cardId,
    String? fieldKey,
    String? value,
    Value<String?> normalizedValue = const Value.absent(),
    FactSource? source,
    Value<double?> confidence = const Value.absent(),
    bool? verifiedByUser,
    Value<String?> validationIssue = const Value.absent(),
    FieldValueKind? valueKind,
    Value<String?> regionRect = const Value.absent(),
  }) => CardField(
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    id: id ?? this.id,
    cardId: cardId ?? this.cardId,
    fieldKey: fieldKey ?? this.fieldKey,
    value: value ?? this.value,
    normalizedValue: normalizedValue.present
        ? normalizedValue.value
        : this.normalizedValue,
    source: source ?? this.source,
    confidence: confidence.present ? confidence.value : this.confidence,
    verifiedByUser: verifiedByUser ?? this.verifiedByUser,
    validationIssue: validationIssue.present
        ? validationIssue.value
        : this.validationIssue,
    valueKind: valueKind ?? this.valueKind,
    regionRect: regionRect.present ? regionRect.value : this.regionRect,
  );
  CardField copyWithCompanion(CardFieldsCompanion data) {
    return CardField(
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      id: data.id.present ? data.id.value : this.id,
      cardId: data.cardId.present ? data.cardId.value : this.cardId,
      fieldKey: data.fieldKey.present ? data.fieldKey.value : this.fieldKey,
      value: data.value.present ? data.value.value : this.value,
      normalizedValue: data.normalizedValue.present
          ? data.normalizedValue.value
          : this.normalizedValue,
      source: data.source.present ? data.source.value : this.source,
      confidence: data.confidence.present
          ? data.confidence.value
          : this.confidence,
      verifiedByUser: data.verifiedByUser.present
          ? data.verifiedByUser.value
          : this.verifiedByUser,
      validationIssue: data.validationIssue.present
          ? data.validationIssue.value
          : this.validationIssue,
      valueKind: data.valueKind.present ? data.valueKind.value : this.valueKind,
      regionRect: data.regionRect.present
          ? data.regionRect.value
          : this.regionRect,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CardField(')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('id: $id, ')
          ..write('cardId: $cardId, ')
          ..write('fieldKey: $fieldKey, ')
          ..write('value: $value, ')
          ..write('normalizedValue: $normalizedValue, ')
          ..write('source: $source, ')
          ..write('confidence: $confidence, ')
          ..write('verifiedByUser: $verifiedByUser, ')
          ..write('validationIssue: $validationIssue, ')
          ..write('valueKind: $valueKind, ')
          ..write('regionRect: $regionRect')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    createdAt,
    updatedAt,
    deletedAt,
    id,
    cardId,
    fieldKey,
    value,
    normalizedValue,
    source,
    confidence,
    verifiedByUser,
    validationIssue,
    valueKind,
    regionRect,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CardField &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.id == this.id &&
          other.cardId == this.cardId &&
          other.fieldKey == this.fieldKey &&
          other.value == this.value &&
          other.normalizedValue == this.normalizedValue &&
          other.source == this.source &&
          other.confidence == this.confidence &&
          other.verifiedByUser == this.verifiedByUser &&
          other.validationIssue == this.validationIssue &&
          other.valueKind == this.valueKind &&
          other.regionRect == this.regionRect);
}

class CardFieldsCompanion extends UpdateCompanion<CardField> {
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> id;
  final Value<int> cardId;
  final Value<String> fieldKey;
  final Value<String> value;
  final Value<String?> normalizedValue;
  final Value<FactSource> source;
  final Value<double?> confidence;
  final Value<bool> verifiedByUser;
  final Value<String?> validationIssue;
  final Value<FieldValueKind> valueKind;
  final Value<String?> regionRect;
  const CardFieldsCompanion({
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.id = const Value.absent(),
    this.cardId = const Value.absent(),
    this.fieldKey = const Value.absent(),
    this.value = const Value.absent(),
    this.normalizedValue = const Value.absent(),
    this.source = const Value.absent(),
    this.confidence = const Value.absent(),
    this.verifiedByUser = const Value.absent(),
    this.validationIssue = const Value.absent(),
    this.valueKind = const Value.absent(),
    this.regionRect = const Value.absent(),
  });
  CardFieldsCompanion.insert({
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.id = const Value.absent(),
    required int cardId,
    required String fieldKey,
    required String value,
    this.normalizedValue = const Value.absent(),
    required FactSource source,
    this.confidence = const Value.absent(),
    this.verifiedByUser = const Value.absent(),
    this.validationIssue = const Value.absent(),
    this.valueKind = const Value.absent(),
    this.regionRect = const Value.absent(),
  }) : cardId = Value(cardId),
       fieldKey = Value(fieldKey),
       value = Value(value),
       source = Value(source);
  static Insertable<CardField> custom({
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? id,
    Expression<int>? cardId,
    Expression<String>? fieldKey,
    Expression<String>? value,
    Expression<String>? normalizedValue,
    Expression<String>? source,
    Expression<double>? confidence,
    Expression<bool>? verifiedByUser,
    Expression<String>? validationIssue,
    Expression<String>? valueKind,
    Expression<String>? regionRect,
  }) {
    return RawValuesInsertable({
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (id != null) 'id': id,
      if (cardId != null) 'card_id': cardId,
      if (fieldKey != null) 'field_key': fieldKey,
      if (value != null) 'value': value,
      if (normalizedValue != null) 'normalized_value': normalizedValue,
      if (source != null) 'source': source,
      if (confidence != null) 'confidence': confidence,
      if (verifiedByUser != null) 'verified_by_user': verifiedByUser,
      if (validationIssue != null) 'validation_issue': validationIssue,
      if (valueKind != null) 'value_kind': valueKind,
      if (regionRect != null) 'region_rect': regionRect,
    });
  }

  CardFieldsCompanion copyWith({
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? id,
    Value<int>? cardId,
    Value<String>? fieldKey,
    Value<String>? value,
    Value<String?>? normalizedValue,
    Value<FactSource>? source,
    Value<double?>? confidence,
    Value<bool>? verifiedByUser,
    Value<String?>? validationIssue,
    Value<FieldValueKind>? valueKind,
    Value<String?>? regionRect,
  }) {
    return CardFieldsCompanion(
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      id: id ?? this.id,
      cardId: cardId ?? this.cardId,
      fieldKey: fieldKey ?? this.fieldKey,
      value: value ?? this.value,
      normalizedValue: normalizedValue ?? this.normalizedValue,
      source: source ?? this.source,
      confidence: confidence ?? this.confidence,
      verifiedByUser: verifiedByUser ?? this.verifiedByUser,
      validationIssue: validationIssue ?? this.validationIssue,
      valueKind: valueKind ?? this.valueKind,
      regionRect: regionRect ?? this.regionRect,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (cardId.present) {
      map['card_id'] = Variable<int>(cardId.value);
    }
    if (fieldKey.present) {
      map['field_key'] = Variable<String>(fieldKey.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (normalizedValue.present) {
      map['normalized_value'] = Variable<String>(normalizedValue.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(
        $CardFieldsTable.$convertersource.toSql(source.value),
      );
    }
    if (confidence.present) {
      map['confidence'] = Variable<double>(confidence.value);
    }
    if (verifiedByUser.present) {
      map['verified_by_user'] = Variable<bool>(verifiedByUser.value);
    }
    if (validationIssue.present) {
      map['validation_issue'] = Variable<String>(validationIssue.value);
    }
    if (valueKind.present) {
      map['value_kind'] = Variable<String>(
        $CardFieldsTable.$convertervalueKind.toSql(valueKind.value),
      );
    }
    if (regionRect.present) {
      map['region_rect'] = Variable<String>(regionRect.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CardFieldsCompanion(')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('id: $id, ')
          ..write('cardId: $cardId, ')
          ..write('fieldKey: $fieldKey, ')
          ..write('value: $value, ')
          ..write('normalizedValue: $normalizedValue, ')
          ..write('source: $source, ')
          ..write('confidence: $confidence, ')
          ..write('verifiedByUser: $verifiedByUser, ')
          ..write('validationIssue: $validationIssue, ')
          ..write('valueKind: $valueKind, ')
          ..write('regionRect: $regionRect')
          ..write(')'))
        .toString();
  }
}

class $ContactPointsTable extends ContactPoints
    with TableInfo<$ContactPointsTable, ContactPoint> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ContactPointsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _ownerTypeMeta = const VerificationMeta(
    'ownerType',
  );
  @override
  late final GeneratedColumn<String> ownerType = GeneratedColumn<String>(
    'owner_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ownerIdMeta = const VerificationMeta(
    'ownerId',
  );
  @override
  late final GeneratedColumn<int> ownerId = GeneratedColumn<int>(
    'owner_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<ContactKind, String> kind =
      GeneratedColumn<String>(
        'kind',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<ContactKind>($ContactPointsTable.$converterkind);
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _normalizedValueMeta = const VerificationMeta(
    'normalizedValue',
  );
  @override
  late final GeneratedColumn<String> normalizedValue = GeneratedColumn<String>(
    'normalized_value',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _roleIdMeta = const VerificationMeta('roleId');
  @override
  late final GeneratedColumn<int> roleId = GeneratedColumn<int>(
    'role_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES roles (id)',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<FactSource, String> source =
      GeneratedColumn<String>(
        'source',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<FactSource>($ContactPointsTable.$convertersource);
  static const VerificationMeta _isActiveMeta = const VerificationMeta(
    'isActive',
  );
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  @override
  List<GeneratedColumn> get $columns => [
    createdAt,
    updatedAt,
    deletedAt,
    id,
    ownerType,
    ownerId,
    kind,
    value,
    normalizedValue,
    label,
    roleId,
    source,
    isActive,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'contact_points';
  @override
  VerificationContext validateIntegrity(
    Insertable<ContactPoint> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('owner_type')) {
      context.handle(
        _ownerTypeMeta,
        ownerType.isAcceptableOrUnknown(data['owner_type']!, _ownerTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_ownerTypeMeta);
    }
    if (data.containsKey('owner_id')) {
      context.handle(
        _ownerIdMeta,
        ownerId.isAcceptableOrUnknown(data['owner_id']!, _ownerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_ownerIdMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    if (data.containsKey('normalized_value')) {
      context.handle(
        _normalizedValueMeta,
        normalizedValue.isAcceptableOrUnknown(
          data['normalized_value']!,
          _normalizedValueMeta,
        ),
      );
    }
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    }
    if (data.containsKey('role_id')) {
      context.handle(
        _roleIdMeta,
        roleId.isAcceptableOrUnknown(data['role_id']!, _roleIdMeta),
      );
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ContactPoint map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ContactPoint(
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      ownerType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_type'],
      )!,
      ownerId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}owner_id'],
      )!,
      kind: $ContactPointsTable.$converterkind.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}kind'],
        )!,
      ),
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
      normalizedValue: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}normalized_value'],
      ),
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      ),
      roleId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}role_id'],
      ),
      source: $ContactPointsTable.$convertersource.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}source'],
        )!,
      ),
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
    );
  }

  @override
  $ContactPointsTable createAlias(String alias) {
    return $ContactPointsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<ContactKind, String, String> $converterkind =
      const EnumNameConverter<ContactKind>(ContactKind.values);
  static JsonTypeConverter2<FactSource, String, String> $convertersource =
      const EnumNameConverter<FactSource>(FactSource.values);
}

class ContactPoint extends DataClass implements Insertable<ContactPoint> {
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final int id;

  /// `person` or `organization`.
  final String ownerType;
  final int ownerId;
  final ContactKind kind;
  final String value;

  /// E.164 for phones, lowercased for email, registrable domain for sites.
  /// Duplicate detection blocks on this, so it must be canonical.
  final String? normalizedValue;

  /// "office", "mobile", "the watch shop one".
  final String? label;

  /// Which role this endpoint belongs to, when the person has several jobs.
  final int? roleId;
  final FactSource source;
  final bool isActive;
  const ContactPoint({
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.id,
    required this.ownerType,
    required this.ownerId,
    required this.kind,
    required this.value,
    this.normalizedValue,
    this.label,
    this.roleId,
    required this.source,
    required this.isActive,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['id'] = Variable<int>(id);
    map['owner_type'] = Variable<String>(ownerType);
    map['owner_id'] = Variable<int>(ownerId);
    {
      map['kind'] = Variable<String>(
        $ContactPointsTable.$converterkind.toSql(kind),
      );
    }
    map['value'] = Variable<String>(value);
    if (!nullToAbsent || normalizedValue != null) {
      map['normalized_value'] = Variable<String>(normalizedValue);
    }
    if (!nullToAbsent || label != null) {
      map['label'] = Variable<String>(label);
    }
    if (!nullToAbsent || roleId != null) {
      map['role_id'] = Variable<int>(roleId);
    }
    {
      map['source'] = Variable<String>(
        $ContactPointsTable.$convertersource.toSql(source),
      );
    }
    map['is_active'] = Variable<bool>(isActive);
    return map;
  }

  ContactPointsCompanion toCompanion(bool nullToAbsent) {
    return ContactPointsCompanion(
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      id: Value(id),
      ownerType: Value(ownerType),
      ownerId: Value(ownerId),
      kind: Value(kind),
      value: Value(value),
      normalizedValue: normalizedValue == null && nullToAbsent
          ? const Value.absent()
          : Value(normalizedValue),
      label: label == null && nullToAbsent
          ? const Value.absent()
          : Value(label),
      roleId: roleId == null && nullToAbsent
          ? const Value.absent()
          : Value(roleId),
      source: Value(source),
      isActive: Value(isActive),
    );
  }

  factory ContactPoint.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ContactPoint(
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      id: serializer.fromJson<int>(json['id']),
      ownerType: serializer.fromJson<String>(json['ownerType']),
      ownerId: serializer.fromJson<int>(json['ownerId']),
      kind: $ContactPointsTable.$converterkind.fromJson(
        serializer.fromJson<String>(json['kind']),
      ),
      value: serializer.fromJson<String>(json['value']),
      normalizedValue: serializer.fromJson<String?>(json['normalizedValue']),
      label: serializer.fromJson<String?>(json['label']),
      roleId: serializer.fromJson<int?>(json['roleId']),
      source: $ContactPointsTable.$convertersource.fromJson(
        serializer.fromJson<String>(json['source']),
      ),
      isActive: serializer.fromJson<bool>(json['isActive']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'id': serializer.toJson<int>(id),
      'ownerType': serializer.toJson<String>(ownerType),
      'ownerId': serializer.toJson<int>(ownerId),
      'kind': serializer.toJson<String>(
        $ContactPointsTable.$converterkind.toJson(kind),
      ),
      'value': serializer.toJson<String>(value),
      'normalizedValue': serializer.toJson<String?>(normalizedValue),
      'label': serializer.toJson<String?>(label),
      'roleId': serializer.toJson<int?>(roleId),
      'source': serializer.toJson<String>(
        $ContactPointsTable.$convertersource.toJson(source),
      ),
      'isActive': serializer.toJson<bool>(isActive),
    };
  }

  ContactPoint copyWith({
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
    int? id,
    String? ownerType,
    int? ownerId,
    ContactKind? kind,
    String? value,
    Value<String?> normalizedValue = const Value.absent(),
    Value<String?> label = const Value.absent(),
    Value<int?> roleId = const Value.absent(),
    FactSource? source,
    bool? isActive,
  }) => ContactPoint(
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    id: id ?? this.id,
    ownerType: ownerType ?? this.ownerType,
    ownerId: ownerId ?? this.ownerId,
    kind: kind ?? this.kind,
    value: value ?? this.value,
    normalizedValue: normalizedValue.present
        ? normalizedValue.value
        : this.normalizedValue,
    label: label.present ? label.value : this.label,
    roleId: roleId.present ? roleId.value : this.roleId,
    source: source ?? this.source,
    isActive: isActive ?? this.isActive,
  );
  ContactPoint copyWithCompanion(ContactPointsCompanion data) {
    return ContactPoint(
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      id: data.id.present ? data.id.value : this.id,
      ownerType: data.ownerType.present ? data.ownerType.value : this.ownerType,
      ownerId: data.ownerId.present ? data.ownerId.value : this.ownerId,
      kind: data.kind.present ? data.kind.value : this.kind,
      value: data.value.present ? data.value.value : this.value,
      normalizedValue: data.normalizedValue.present
          ? data.normalizedValue.value
          : this.normalizedValue,
      label: data.label.present ? data.label.value : this.label,
      roleId: data.roleId.present ? data.roleId.value : this.roleId,
      source: data.source.present ? data.source.value : this.source,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ContactPoint(')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('id: $id, ')
          ..write('ownerType: $ownerType, ')
          ..write('ownerId: $ownerId, ')
          ..write('kind: $kind, ')
          ..write('value: $value, ')
          ..write('normalizedValue: $normalizedValue, ')
          ..write('label: $label, ')
          ..write('roleId: $roleId, ')
          ..write('source: $source, ')
          ..write('isActive: $isActive')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    createdAt,
    updatedAt,
    deletedAt,
    id,
    ownerType,
    ownerId,
    kind,
    value,
    normalizedValue,
    label,
    roleId,
    source,
    isActive,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ContactPoint &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.id == this.id &&
          other.ownerType == this.ownerType &&
          other.ownerId == this.ownerId &&
          other.kind == this.kind &&
          other.value == this.value &&
          other.normalizedValue == this.normalizedValue &&
          other.label == this.label &&
          other.roleId == this.roleId &&
          other.source == this.source &&
          other.isActive == this.isActive);
}

class ContactPointsCompanion extends UpdateCompanion<ContactPoint> {
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> id;
  final Value<String> ownerType;
  final Value<int> ownerId;
  final Value<ContactKind> kind;
  final Value<String> value;
  final Value<String?> normalizedValue;
  final Value<String?> label;
  final Value<int?> roleId;
  final Value<FactSource> source;
  final Value<bool> isActive;
  const ContactPointsCompanion({
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.id = const Value.absent(),
    this.ownerType = const Value.absent(),
    this.ownerId = const Value.absent(),
    this.kind = const Value.absent(),
    this.value = const Value.absent(),
    this.normalizedValue = const Value.absent(),
    this.label = const Value.absent(),
    this.roleId = const Value.absent(),
    this.source = const Value.absent(),
    this.isActive = const Value.absent(),
  });
  ContactPointsCompanion.insert({
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.id = const Value.absent(),
    required String ownerType,
    required int ownerId,
    required ContactKind kind,
    required String value,
    this.normalizedValue = const Value.absent(),
    this.label = const Value.absent(),
    this.roleId = const Value.absent(),
    required FactSource source,
    this.isActive = const Value.absent(),
  }) : ownerType = Value(ownerType),
       ownerId = Value(ownerId),
       kind = Value(kind),
       value = Value(value),
       source = Value(source);
  static Insertable<ContactPoint> custom({
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? id,
    Expression<String>? ownerType,
    Expression<int>? ownerId,
    Expression<String>? kind,
    Expression<String>? value,
    Expression<String>? normalizedValue,
    Expression<String>? label,
    Expression<int>? roleId,
    Expression<String>? source,
    Expression<bool>? isActive,
  }) {
    return RawValuesInsertable({
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (id != null) 'id': id,
      if (ownerType != null) 'owner_type': ownerType,
      if (ownerId != null) 'owner_id': ownerId,
      if (kind != null) 'kind': kind,
      if (value != null) 'value': value,
      if (normalizedValue != null) 'normalized_value': normalizedValue,
      if (label != null) 'label': label,
      if (roleId != null) 'role_id': roleId,
      if (source != null) 'source': source,
      if (isActive != null) 'is_active': isActive,
    });
  }

  ContactPointsCompanion copyWith({
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? id,
    Value<String>? ownerType,
    Value<int>? ownerId,
    Value<ContactKind>? kind,
    Value<String>? value,
    Value<String?>? normalizedValue,
    Value<String?>? label,
    Value<int?>? roleId,
    Value<FactSource>? source,
    Value<bool>? isActive,
  }) {
    return ContactPointsCompanion(
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      id: id ?? this.id,
      ownerType: ownerType ?? this.ownerType,
      ownerId: ownerId ?? this.ownerId,
      kind: kind ?? this.kind,
      value: value ?? this.value,
      normalizedValue: normalizedValue ?? this.normalizedValue,
      label: label ?? this.label,
      roleId: roleId ?? this.roleId,
      source: source ?? this.source,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (ownerType.present) {
      map['owner_type'] = Variable<String>(ownerType.value);
    }
    if (ownerId.present) {
      map['owner_id'] = Variable<int>(ownerId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(
        $ContactPointsTable.$converterkind.toSql(kind.value),
      );
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (normalizedValue.present) {
      map['normalized_value'] = Variable<String>(normalizedValue.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (roleId.present) {
      map['role_id'] = Variable<int>(roleId.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(
        $ContactPointsTable.$convertersource.toSql(source.value),
      );
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ContactPointsCompanion(')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('id: $id, ')
          ..write('ownerType: $ownerType, ')
          ..write('ownerId: $ownerId, ')
          ..write('kind: $kind, ')
          ..write('value: $value, ')
          ..write('normalizedValue: $normalizedValue, ')
          ..write('label: $label, ')
          ..write('roleId: $roleId, ')
          ..write('source: $source, ')
          ..write('isActive: $isActive')
          ..write(')'))
        .toString();
  }
}

class $OcrBlocksTable extends OcrBlocks
    with TableInfo<$OcrBlocksTable, OcrBlockRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OcrBlocksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _cardIdMeta = const VerificationMeta('cardId');
  @override
  late final GeneratedColumn<int> cardId = GeneratedColumn<int>(
    'card_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES cards (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _blockTextMeta = const VerificationMeta(
    'blockText',
  );
  @override
  late final GeneratedColumn<String> blockText = GeneratedColumn<String>(
    'text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rectMeta = const VerificationMeta('rect');
  @override
  late final GeneratedColumn<String> rect = GeneratedColumn<String>(
    'rect',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _confidenceMeta = const VerificationMeta(
    'confidence',
  );
  @override
  late final GeneratedColumn<double> confidence = GeneratedColumn<double>(
    'confidence',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scriptMeta = const VerificationMeta('script');
  @override
  late final GeneratedColumn<String> script = GeneratedColumn<String>(
    'script',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _engineMeta = const VerificationMeta('engine');
  @override
  late final GeneratedColumn<String> engine = GeneratedColumn<String>(
    'engine',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _assignedFieldKeyMeta = const VerificationMeta(
    'assignedFieldKey',
  );
  @override
  late final GeneratedColumn<String> assignedFieldKey = GeneratedColumn<String>(
    'assigned_field_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fieldIdMeta = const VerificationMeta(
    'fieldId',
  );
  @override
  late final GeneratedColumn<int> fieldId = GeneratedColumn<int>(
    'field_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES card_fields (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _orderIndexMeta = const VerificationMeta(
    'orderIndex',
  );
  @override
  late final GeneratedColumn<int> orderIndex = GeneratedColumn<int>(
    'order_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    cardId,
    blockText,
    rect,
    confidence,
    script,
    engine,
    assignedFieldKey,
    fieldId,
    orderIndex,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ocr_blocks';
  @override
  VerificationContext validateIntegrity(
    Insertable<OcrBlockRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('card_id')) {
      context.handle(
        _cardIdMeta,
        cardId.isAcceptableOrUnknown(data['card_id']!, _cardIdMeta),
      );
    } else if (isInserting) {
      context.missing(_cardIdMeta);
    }
    if (data.containsKey('text')) {
      context.handle(
        _blockTextMeta,
        blockText.isAcceptableOrUnknown(data['text']!, _blockTextMeta),
      );
    } else if (isInserting) {
      context.missing(_blockTextMeta);
    }
    if (data.containsKey('rect')) {
      context.handle(
        _rectMeta,
        rect.isAcceptableOrUnknown(data['rect']!, _rectMeta),
      );
    } else if (isInserting) {
      context.missing(_rectMeta);
    }
    if (data.containsKey('confidence')) {
      context.handle(
        _confidenceMeta,
        confidence.isAcceptableOrUnknown(data['confidence']!, _confidenceMeta),
      );
    } else if (isInserting) {
      context.missing(_confidenceMeta);
    }
    if (data.containsKey('script')) {
      context.handle(
        _scriptMeta,
        script.isAcceptableOrUnknown(data['script']!, _scriptMeta),
      );
    } else if (isInserting) {
      context.missing(_scriptMeta);
    }
    if (data.containsKey('engine')) {
      context.handle(
        _engineMeta,
        engine.isAcceptableOrUnknown(data['engine']!, _engineMeta),
      );
    }
    if (data.containsKey('assigned_field_key')) {
      context.handle(
        _assignedFieldKeyMeta,
        assignedFieldKey.isAcceptableOrUnknown(
          data['assigned_field_key']!,
          _assignedFieldKeyMeta,
        ),
      );
    }
    if (data.containsKey('field_id')) {
      context.handle(
        _fieldIdMeta,
        fieldId.isAcceptableOrUnknown(data['field_id']!, _fieldIdMeta),
      );
    }
    if (data.containsKey('order_index')) {
      context.handle(
        _orderIndexMeta,
        orderIndex.isAcceptableOrUnknown(data['order_index']!, _orderIndexMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OcrBlockRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OcrBlockRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      cardId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}card_id'],
      )!,
      blockText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}text'],
      )!,
      rect: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rect'],
      )!,
      confidence: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}confidence'],
      )!,
      script: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}script'],
      )!,
      engine: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}engine'],
      ),
      assignedFieldKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}assigned_field_key'],
      ),
      fieldId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}field_id'],
      ),
      orderIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}order_index'],
      )!,
    );
  }

  @override
  $OcrBlocksTable createAlias(String alias) {
    return $OcrBlocksTable(attachedDatabase, alias);
  }
}

class OcrBlockRow extends DataClass implements Insertable<OcrBlockRow> {
  final int id;
  final int cardId;

  /// Named `blockText` rather than `text` because a getter called `text` would
  /// shadow Drift's own `text()` column builder.
  final String blockText;

  /// "left,top,right,bottom" in the source image's coordinate space.
  final String rect;

  /// Negative means the engine reported no confidence signal.
  final double confidence;

  /// `latin`, `bengali`, `unknown`.
  final String script;
  final String? engine;

  /// Which field this block was assigned to, if any. Null means unassigned and
  /// therefore available in the tap-to-assign picker.
  final String? assignedFieldKey;

  /// Which field row owns this block.
  ///
  /// [assignedFieldKey] cannot answer this on its own: a card with two phone
  /// numbers has two fields sharing one key, so re-assigning one of them could
  /// not tell which blocks to release. Without that, a block the user moved
  /// away from a field would stay marked as used and its text would vanish
  /// from the picker for good.
  final int? fieldId;
  final int orderIndex;
  const OcrBlockRow({
    required this.id,
    required this.cardId,
    required this.blockText,
    required this.rect,
    required this.confidence,
    required this.script,
    this.engine,
    this.assignedFieldKey,
    this.fieldId,
    required this.orderIndex,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['card_id'] = Variable<int>(cardId);
    map['text'] = Variable<String>(blockText);
    map['rect'] = Variable<String>(rect);
    map['confidence'] = Variable<double>(confidence);
    map['script'] = Variable<String>(script);
    if (!nullToAbsent || engine != null) {
      map['engine'] = Variable<String>(engine);
    }
    if (!nullToAbsent || assignedFieldKey != null) {
      map['assigned_field_key'] = Variable<String>(assignedFieldKey);
    }
    if (!nullToAbsent || fieldId != null) {
      map['field_id'] = Variable<int>(fieldId);
    }
    map['order_index'] = Variable<int>(orderIndex);
    return map;
  }

  OcrBlocksCompanion toCompanion(bool nullToAbsent) {
    return OcrBlocksCompanion(
      id: Value(id),
      cardId: Value(cardId),
      blockText: Value(blockText),
      rect: Value(rect),
      confidence: Value(confidence),
      script: Value(script),
      engine: engine == null && nullToAbsent
          ? const Value.absent()
          : Value(engine),
      assignedFieldKey: assignedFieldKey == null && nullToAbsent
          ? const Value.absent()
          : Value(assignedFieldKey),
      fieldId: fieldId == null && nullToAbsent
          ? const Value.absent()
          : Value(fieldId),
      orderIndex: Value(orderIndex),
    );
  }

  factory OcrBlockRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OcrBlockRow(
      id: serializer.fromJson<int>(json['id']),
      cardId: serializer.fromJson<int>(json['cardId']),
      blockText: serializer.fromJson<String>(json['blockText']),
      rect: serializer.fromJson<String>(json['rect']),
      confidence: serializer.fromJson<double>(json['confidence']),
      script: serializer.fromJson<String>(json['script']),
      engine: serializer.fromJson<String?>(json['engine']),
      assignedFieldKey: serializer.fromJson<String?>(json['assignedFieldKey']),
      fieldId: serializer.fromJson<int?>(json['fieldId']),
      orderIndex: serializer.fromJson<int>(json['orderIndex']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'cardId': serializer.toJson<int>(cardId),
      'blockText': serializer.toJson<String>(blockText),
      'rect': serializer.toJson<String>(rect),
      'confidence': serializer.toJson<double>(confidence),
      'script': serializer.toJson<String>(script),
      'engine': serializer.toJson<String?>(engine),
      'assignedFieldKey': serializer.toJson<String?>(assignedFieldKey),
      'fieldId': serializer.toJson<int?>(fieldId),
      'orderIndex': serializer.toJson<int>(orderIndex),
    };
  }

  OcrBlockRow copyWith({
    int? id,
    int? cardId,
    String? blockText,
    String? rect,
    double? confidence,
    String? script,
    Value<String?> engine = const Value.absent(),
    Value<String?> assignedFieldKey = const Value.absent(),
    Value<int?> fieldId = const Value.absent(),
    int? orderIndex,
  }) => OcrBlockRow(
    id: id ?? this.id,
    cardId: cardId ?? this.cardId,
    blockText: blockText ?? this.blockText,
    rect: rect ?? this.rect,
    confidence: confidence ?? this.confidence,
    script: script ?? this.script,
    engine: engine.present ? engine.value : this.engine,
    assignedFieldKey: assignedFieldKey.present
        ? assignedFieldKey.value
        : this.assignedFieldKey,
    fieldId: fieldId.present ? fieldId.value : this.fieldId,
    orderIndex: orderIndex ?? this.orderIndex,
  );
  OcrBlockRow copyWithCompanion(OcrBlocksCompanion data) {
    return OcrBlockRow(
      id: data.id.present ? data.id.value : this.id,
      cardId: data.cardId.present ? data.cardId.value : this.cardId,
      blockText: data.blockText.present ? data.blockText.value : this.blockText,
      rect: data.rect.present ? data.rect.value : this.rect,
      confidence: data.confidence.present
          ? data.confidence.value
          : this.confidence,
      script: data.script.present ? data.script.value : this.script,
      engine: data.engine.present ? data.engine.value : this.engine,
      assignedFieldKey: data.assignedFieldKey.present
          ? data.assignedFieldKey.value
          : this.assignedFieldKey,
      fieldId: data.fieldId.present ? data.fieldId.value : this.fieldId,
      orderIndex: data.orderIndex.present
          ? data.orderIndex.value
          : this.orderIndex,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OcrBlockRow(')
          ..write('id: $id, ')
          ..write('cardId: $cardId, ')
          ..write('blockText: $blockText, ')
          ..write('rect: $rect, ')
          ..write('confidence: $confidence, ')
          ..write('script: $script, ')
          ..write('engine: $engine, ')
          ..write('assignedFieldKey: $assignedFieldKey, ')
          ..write('fieldId: $fieldId, ')
          ..write('orderIndex: $orderIndex')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    cardId,
    blockText,
    rect,
    confidence,
    script,
    engine,
    assignedFieldKey,
    fieldId,
    orderIndex,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OcrBlockRow &&
          other.id == this.id &&
          other.cardId == this.cardId &&
          other.blockText == this.blockText &&
          other.rect == this.rect &&
          other.confidence == this.confidence &&
          other.script == this.script &&
          other.engine == this.engine &&
          other.assignedFieldKey == this.assignedFieldKey &&
          other.fieldId == this.fieldId &&
          other.orderIndex == this.orderIndex);
}

class OcrBlocksCompanion extends UpdateCompanion<OcrBlockRow> {
  final Value<int> id;
  final Value<int> cardId;
  final Value<String> blockText;
  final Value<String> rect;
  final Value<double> confidence;
  final Value<String> script;
  final Value<String?> engine;
  final Value<String?> assignedFieldKey;
  final Value<int?> fieldId;
  final Value<int> orderIndex;
  const OcrBlocksCompanion({
    this.id = const Value.absent(),
    this.cardId = const Value.absent(),
    this.blockText = const Value.absent(),
    this.rect = const Value.absent(),
    this.confidence = const Value.absent(),
    this.script = const Value.absent(),
    this.engine = const Value.absent(),
    this.assignedFieldKey = const Value.absent(),
    this.fieldId = const Value.absent(),
    this.orderIndex = const Value.absent(),
  });
  OcrBlocksCompanion.insert({
    this.id = const Value.absent(),
    required int cardId,
    required String blockText,
    required String rect,
    required double confidence,
    required String script,
    this.engine = const Value.absent(),
    this.assignedFieldKey = const Value.absent(),
    this.fieldId = const Value.absent(),
    this.orderIndex = const Value.absent(),
  }) : cardId = Value(cardId),
       blockText = Value(blockText),
       rect = Value(rect),
       confidence = Value(confidence),
       script = Value(script);
  static Insertable<OcrBlockRow> custom({
    Expression<int>? id,
    Expression<int>? cardId,
    Expression<String>? blockText,
    Expression<String>? rect,
    Expression<double>? confidence,
    Expression<String>? script,
    Expression<String>? engine,
    Expression<String>? assignedFieldKey,
    Expression<int>? fieldId,
    Expression<int>? orderIndex,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (cardId != null) 'card_id': cardId,
      if (blockText != null) 'text': blockText,
      if (rect != null) 'rect': rect,
      if (confidence != null) 'confidence': confidence,
      if (script != null) 'script': script,
      if (engine != null) 'engine': engine,
      if (assignedFieldKey != null) 'assigned_field_key': assignedFieldKey,
      if (fieldId != null) 'field_id': fieldId,
      if (orderIndex != null) 'order_index': orderIndex,
    });
  }

  OcrBlocksCompanion copyWith({
    Value<int>? id,
    Value<int>? cardId,
    Value<String>? blockText,
    Value<String>? rect,
    Value<double>? confidence,
    Value<String>? script,
    Value<String?>? engine,
    Value<String?>? assignedFieldKey,
    Value<int?>? fieldId,
    Value<int>? orderIndex,
  }) {
    return OcrBlocksCompanion(
      id: id ?? this.id,
      cardId: cardId ?? this.cardId,
      blockText: blockText ?? this.blockText,
      rect: rect ?? this.rect,
      confidence: confidence ?? this.confidence,
      script: script ?? this.script,
      engine: engine ?? this.engine,
      assignedFieldKey: assignedFieldKey ?? this.assignedFieldKey,
      fieldId: fieldId ?? this.fieldId,
      orderIndex: orderIndex ?? this.orderIndex,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (cardId.present) {
      map['card_id'] = Variable<int>(cardId.value);
    }
    if (blockText.present) {
      map['text'] = Variable<String>(blockText.value);
    }
    if (rect.present) {
      map['rect'] = Variable<String>(rect.value);
    }
    if (confidence.present) {
      map['confidence'] = Variable<double>(confidence.value);
    }
    if (script.present) {
      map['script'] = Variable<String>(script.value);
    }
    if (engine.present) {
      map['engine'] = Variable<String>(engine.value);
    }
    if (assignedFieldKey.present) {
      map['assigned_field_key'] = Variable<String>(assignedFieldKey.value);
    }
    if (fieldId.present) {
      map['field_id'] = Variable<int>(fieldId.value);
    }
    if (orderIndex.present) {
      map['order_index'] = Variable<int>(orderIndex.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OcrBlocksCompanion(')
          ..write('id: $id, ')
          ..write('cardId: $cardId, ')
          ..write('blockText: $blockText, ')
          ..write('rect: $rect, ')
          ..write('confidence: $confidence, ')
          ..write('script: $script, ')
          ..write('engine: $engine, ')
          ..write('assignedFieldKey: $assignedFieldKey, ')
          ..write('fieldId: $fieldId, ')
          ..write('orderIndex: $orderIndex')
          ..write(')'))
        .toString();
  }
}

class $ExtractionAttemptsTable extends ExtractionAttempts
    with TableInfo<$ExtractionAttemptsTable, ExtractionAttempt> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ExtractionAttemptsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _cardIdMeta = const VerificationMeta('cardId');
  @override
  late final GeneratedColumn<int> cardId = GeneratedColumn<int>(
    'card_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES cards (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _engineMeta = const VerificationMeta('engine');
  @override
  late final GeneratedColumn<String> engine = GeneratedColumn<String>(
    'engine',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _durationMsMeta = const VerificationMeta(
    'durationMs',
  );
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
    'duration_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<AttemptStatus, String> status =
      GeneratedColumn<String>(
        'status',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<AttemptStatus>($ExtractionAttemptsTable.$converterstatus);
  static const VerificationMeta _fieldsFoundMeta = const VerificationMeta(
    'fieldsFound',
  );
  @override
  late final GeneratedColumn<int> fieldsFound = GeneratedColumn<int>(
    'fields_found',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _errorCodeMeta = const VerificationMeta(
    'errorCode',
  );
  @override
  late final GeneratedColumn<String> errorCode = GeneratedColumn<String>(
    'error_code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _errorDetailMeta = const VerificationMeta(
    'errorDetail',
  );
  @override
  late final GeneratedColumn<String> errorDetail = GeneratedColumn<String>(
    'error_detail',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    cardId,
    engine,
    startedAt,
    durationMs,
    status,
    fieldsFound,
    errorCode,
    errorDetail,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'extraction_attempts';
  @override
  VerificationContext validateIntegrity(
    Insertable<ExtractionAttempt> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('card_id')) {
      context.handle(
        _cardIdMeta,
        cardId.isAcceptableOrUnknown(data['card_id']!, _cardIdMeta),
      );
    } else if (isInserting) {
      context.missing(_cardIdMeta);
    }
    if (data.containsKey('engine')) {
      context.handle(
        _engineMeta,
        engine.isAcceptableOrUnknown(data['engine']!, _engineMeta),
      );
    } else if (isInserting) {
      context.missing(_engineMeta);
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
      );
    } else if (isInserting) {
      context.missing(_durationMsMeta);
    }
    if (data.containsKey('fields_found')) {
      context.handle(
        _fieldsFoundMeta,
        fieldsFound.isAcceptableOrUnknown(
          data['fields_found']!,
          _fieldsFoundMeta,
        ),
      );
    }
    if (data.containsKey('error_code')) {
      context.handle(
        _errorCodeMeta,
        errorCode.isAcceptableOrUnknown(data['error_code']!, _errorCodeMeta),
      );
    }
    if (data.containsKey('error_detail')) {
      context.handle(
        _errorDetailMeta,
        errorDetail.isAcceptableOrUnknown(
          data['error_detail']!,
          _errorDetailMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ExtractionAttempt map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ExtractionAttempt(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      cardId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}card_id'],
      )!,
      engine: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}engine'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      )!,
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      )!,
      status: $ExtractionAttemptsTable.$converterstatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}status'],
        )!,
      ),
      fieldsFound: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}fields_found'],
      )!,
      errorCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error_code'],
      ),
      errorDetail: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error_detail'],
      ),
    );
  }

  @override
  $ExtractionAttemptsTable createAlias(String alias) {
    return $ExtractionAttemptsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<AttemptStatus, String, String> $converterstatus =
      const EnumNameConverter<AttemptStatus>(AttemptStatus.values);
}

class ExtractionAttempt extends DataClass
    implements Insertable<ExtractionAttempt> {
  final int id;
  final int cardId;
  final String engine;
  final DateTime startedAt;
  final int durationMs;
  final AttemptStatus status;
  final int fieldsFound;

  /// Matches [OcrFailure] names when OCR was the failing stage.
  final String? errorCode;
  final String? errorDetail;
  const ExtractionAttempt({
    required this.id,
    required this.cardId,
    required this.engine,
    required this.startedAt,
    required this.durationMs,
    required this.status,
    required this.fieldsFound,
    this.errorCode,
    this.errorDetail,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['card_id'] = Variable<int>(cardId);
    map['engine'] = Variable<String>(engine);
    map['started_at'] = Variable<DateTime>(startedAt);
    map['duration_ms'] = Variable<int>(durationMs);
    {
      map['status'] = Variable<String>(
        $ExtractionAttemptsTable.$converterstatus.toSql(status),
      );
    }
    map['fields_found'] = Variable<int>(fieldsFound);
    if (!nullToAbsent || errorCode != null) {
      map['error_code'] = Variable<String>(errorCode);
    }
    if (!nullToAbsent || errorDetail != null) {
      map['error_detail'] = Variable<String>(errorDetail);
    }
    return map;
  }

  ExtractionAttemptsCompanion toCompanion(bool nullToAbsent) {
    return ExtractionAttemptsCompanion(
      id: Value(id),
      cardId: Value(cardId),
      engine: Value(engine),
      startedAt: Value(startedAt),
      durationMs: Value(durationMs),
      status: Value(status),
      fieldsFound: Value(fieldsFound),
      errorCode: errorCode == null && nullToAbsent
          ? const Value.absent()
          : Value(errorCode),
      errorDetail: errorDetail == null && nullToAbsent
          ? const Value.absent()
          : Value(errorDetail),
    );
  }

  factory ExtractionAttempt.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ExtractionAttempt(
      id: serializer.fromJson<int>(json['id']),
      cardId: serializer.fromJson<int>(json['cardId']),
      engine: serializer.fromJson<String>(json['engine']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      durationMs: serializer.fromJson<int>(json['durationMs']),
      status: $ExtractionAttemptsTable.$converterstatus.fromJson(
        serializer.fromJson<String>(json['status']),
      ),
      fieldsFound: serializer.fromJson<int>(json['fieldsFound']),
      errorCode: serializer.fromJson<String?>(json['errorCode']),
      errorDetail: serializer.fromJson<String?>(json['errorDetail']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'cardId': serializer.toJson<int>(cardId),
      'engine': serializer.toJson<String>(engine),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'durationMs': serializer.toJson<int>(durationMs),
      'status': serializer.toJson<String>(
        $ExtractionAttemptsTable.$converterstatus.toJson(status),
      ),
      'fieldsFound': serializer.toJson<int>(fieldsFound),
      'errorCode': serializer.toJson<String?>(errorCode),
      'errorDetail': serializer.toJson<String?>(errorDetail),
    };
  }

  ExtractionAttempt copyWith({
    int? id,
    int? cardId,
    String? engine,
    DateTime? startedAt,
    int? durationMs,
    AttemptStatus? status,
    int? fieldsFound,
    Value<String?> errorCode = const Value.absent(),
    Value<String?> errorDetail = const Value.absent(),
  }) => ExtractionAttempt(
    id: id ?? this.id,
    cardId: cardId ?? this.cardId,
    engine: engine ?? this.engine,
    startedAt: startedAt ?? this.startedAt,
    durationMs: durationMs ?? this.durationMs,
    status: status ?? this.status,
    fieldsFound: fieldsFound ?? this.fieldsFound,
    errorCode: errorCode.present ? errorCode.value : this.errorCode,
    errorDetail: errorDetail.present ? errorDetail.value : this.errorDetail,
  );
  ExtractionAttempt copyWithCompanion(ExtractionAttemptsCompanion data) {
    return ExtractionAttempt(
      id: data.id.present ? data.id.value : this.id,
      cardId: data.cardId.present ? data.cardId.value : this.cardId,
      engine: data.engine.present ? data.engine.value : this.engine,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
      status: data.status.present ? data.status.value : this.status,
      fieldsFound: data.fieldsFound.present
          ? data.fieldsFound.value
          : this.fieldsFound,
      errorCode: data.errorCode.present ? data.errorCode.value : this.errorCode,
      errorDetail: data.errorDetail.present
          ? data.errorDetail.value
          : this.errorDetail,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ExtractionAttempt(')
          ..write('id: $id, ')
          ..write('cardId: $cardId, ')
          ..write('engine: $engine, ')
          ..write('startedAt: $startedAt, ')
          ..write('durationMs: $durationMs, ')
          ..write('status: $status, ')
          ..write('fieldsFound: $fieldsFound, ')
          ..write('errorCode: $errorCode, ')
          ..write('errorDetail: $errorDetail')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    cardId,
    engine,
    startedAt,
    durationMs,
    status,
    fieldsFound,
    errorCode,
    errorDetail,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ExtractionAttempt &&
          other.id == this.id &&
          other.cardId == this.cardId &&
          other.engine == this.engine &&
          other.startedAt == this.startedAt &&
          other.durationMs == this.durationMs &&
          other.status == this.status &&
          other.fieldsFound == this.fieldsFound &&
          other.errorCode == this.errorCode &&
          other.errorDetail == this.errorDetail);
}

class ExtractionAttemptsCompanion extends UpdateCompanion<ExtractionAttempt> {
  final Value<int> id;
  final Value<int> cardId;
  final Value<String> engine;
  final Value<DateTime> startedAt;
  final Value<int> durationMs;
  final Value<AttemptStatus> status;
  final Value<int> fieldsFound;
  final Value<String?> errorCode;
  final Value<String?> errorDetail;
  const ExtractionAttemptsCompanion({
    this.id = const Value.absent(),
    this.cardId = const Value.absent(),
    this.engine = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.status = const Value.absent(),
    this.fieldsFound = const Value.absent(),
    this.errorCode = const Value.absent(),
    this.errorDetail = const Value.absent(),
  });
  ExtractionAttemptsCompanion.insert({
    this.id = const Value.absent(),
    required int cardId,
    required String engine,
    required DateTime startedAt,
    required int durationMs,
    required AttemptStatus status,
    this.fieldsFound = const Value.absent(),
    this.errorCode = const Value.absent(),
    this.errorDetail = const Value.absent(),
  }) : cardId = Value(cardId),
       engine = Value(engine),
       startedAt = Value(startedAt),
       durationMs = Value(durationMs),
       status = Value(status);
  static Insertable<ExtractionAttempt> custom({
    Expression<int>? id,
    Expression<int>? cardId,
    Expression<String>? engine,
    Expression<DateTime>? startedAt,
    Expression<int>? durationMs,
    Expression<String>? status,
    Expression<int>? fieldsFound,
    Expression<String>? errorCode,
    Expression<String>? errorDetail,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (cardId != null) 'card_id': cardId,
      if (engine != null) 'engine': engine,
      if (startedAt != null) 'started_at': startedAt,
      if (durationMs != null) 'duration_ms': durationMs,
      if (status != null) 'status': status,
      if (fieldsFound != null) 'fields_found': fieldsFound,
      if (errorCode != null) 'error_code': errorCode,
      if (errorDetail != null) 'error_detail': errorDetail,
    });
  }

  ExtractionAttemptsCompanion copyWith({
    Value<int>? id,
    Value<int>? cardId,
    Value<String>? engine,
    Value<DateTime>? startedAt,
    Value<int>? durationMs,
    Value<AttemptStatus>? status,
    Value<int>? fieldsFound,
    Value<String?>? errorCode,
    Value<String?>? errorDetail,
  }) {
    return ExtractionAttemptsCompanion(
      id: id ?? this.id,
      cardId: cardId ?? this.cardId,
      engine: engine ?? this.engine,
      startedAt: startedAt ?? this.startedAt,
      durationMs: durationMs ?? this.durationMs,
      status: status ?? this.status,
      fieldsFound: fieldsFound ?? this.fieldsFound,
      errorCode: errorCode ?? this.errorCode,
      errorDetail: errorDetail ?? this.errorDetail,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (cardId.present) {
      map['card_id'] = Variable<int>(cardId.value);
    }
    if (engine.present) {
      map['engine'] = Variable<String>(engine.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(
        $ExtractionAttemptsTable.$converterstatus.toSql(status.value),
      );
    }
    if (fieldsFound.present) {
      map['fields_found'] = Variable<int>(fieldsFound.value);
    }
    if (errorCode.present) {
      map['error_code'] = Variable<String>(errorCode.value);
    }
    if (errorDetail.present) {
      map['error_detail'] = Variable<String>(errorDetail.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ExtractionAttemptsCompanion(')
          ..write('id: $id, ')
          ..write('cardId: $cardId, ')
          ..write('engine: $engine, ')
          ..write('startedAt: $startedAt, ')
          ..write('durationMs: $durationMs, ')
          ..write('status: $status, ')
          ..write('fieldsFound: $fieldsFound, ')
          ..write('errorCode: $errorCode, ')
          ..write('errorDetail: $errorDetail')
          ..write(')'))
        .toString();
  }
}

class $NotesTable extends Notes with TableInfo<$NotesTable, Note> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NotesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _subjectTypeMeta = const VerificationMeta(
    'subjectType',
  );
  @override
  late final GeneratedColumn<String> subjectType = GeneratedColumn<String>(
    'subject_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _subjectIdMeta = const VerificationMeta(
    'subjectId',
  );
  @override
  late final GeneratedColumn<int> subjectId = GeneratedColumn<int>(
    'subject_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _audioPathMeta = const VerificationMeta(
    'audioPath',
  );
  @override
  late final GeneratedColumn<String> audioPath = GeneratedColumn<String>(
    'audio_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _transcriptMeta = const VerificationMeta(
    'transcript',
  );
  @override
  late final GeneratedColumn<String> transcript = GeneratedColumn<String>(
    'transcript',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _languageMeta = const VerificationMeta(
    'language',
  );
  @override
  late final GeneratedColumn<String> language = GeneratedColumn<String>(
    'language',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    createdAt,
    updatedAt,
    deletedAt,
    id,
    subjectType,
    subjectId,
    body,
    audioPath,
    transcript,
    language,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'notes';
  @override
  VerificationContext validateIntegrity(
    Insertable<Note> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('subject_type')) {
      context.handle(
        _subjectTypeMeta,
        subjectType.isAcceptableOrUnknown(
          data['subject_type']!,
          _subjectTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_subjectTypeMeta);
    }
    if (data.containsKey('subject_id')) {
      context.handle(
        _subjectIdMeta,
        subjectId.isAcceptableOrUnknown(data['subject_id']!, _subjectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_subjectIdMeta);
    }
    if (data.containsKey('body')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['body']!, _bodyMeta),
      );
    }
    if (data.containsKey('audio_path')) {
      context.handle(
        _audioPathMeta,
        audioPath.isAcceptableOrUnknown(data['audio_path']!, _audioPathMeta),
      );
    }
    if (data.containsKey('transcript')) {
      context.handle(
        _transcriptMeta,
        transcript.isAcceptableOrUnknown(data['transcript']!, _transcriptMeta),
      );
    }
    if (data.containsKey('language')) {
      context.handle(
        _languageMeta,
        language.isAcceptableOrUnknown(data['language']!, _languageMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Note map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Note(
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      subjectType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subject_type'],
      )!,
      subjectId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}subject_id'],
      )!,
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body'],
      ),
      audioPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}audio_path'],
      ),
      transcript: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}transcript'],
      ),
      language: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}language'],
      ),
    );
  }

  @override
  $NotesTable createAlias(String alias) {
    return $NotesTable(attachedDatabase, alias);
  }
}

class Note extends DataClass implements Insertable<Note> {
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final int id;
  final String subjectType;
  final int subjectId;
  final String? body;
  final String? audioPath;
  final String? transcript;

  /// BCP-47-ish tag; `bn-Latn` marks romanised Bangla.
  final String? language;
  const Note({
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.id,
    required this.subjectType,
    required this.subjectId,
    this.body,
    this.audioPath,
    this.transcript,
    this.language,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['id'] = Variable<int>(id);
    map['subject_type'] = Variable<String>(subjectType);
    map['subject_id'] = Variable<int>(subjectId);
    if (!nullToAbsent || body != null) {
      map['body'] = Variable<String>(body);
    }
    if (!nullToAbsent || audioPath != null) {
      map['audio_path'] = Variable<String>(audioPath);
    }
    if (!nullToAbsent || transcript != null) {
      map['transcript'] = Variable<String>(transcript);
    }
    if (!nullToAbsent || language != null) {
      map['language'] = Variable<String>(language);
    }
    return map;
  }

  NotesCompanion toCompanion(bool nullToAbsent) {
    return NotesCompanion(
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      id: Value(id),
      subjectType: Value(subjectType),
      subjectId: Value(subjectId),
      body: body == null && nullToAbsent ? const Value.absent() : Value(body),
      audioPath: audioPath == null && nullToAbsent
          ? const Value.absent()
          : Value(audioPath),
      transcript: transcript == null && nullToAbsent
          ? const Value.absent()
          : Value(transcript),
      language: language == null && nullToAbsent
          ? const Value.absent()
          : Value(language),
    );
  }

  factory Note.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Note(
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      id: serializer.fromJson<int>(json['id']),
      subjectType: serializer.fromJson<String>(json['subjectType']),
      subjectId: serializer.fromJson<int>(json['subjectId']),
      body: serializer.fromJson<String?>(json['body']),
      audioPath: serializer.fromJson<String?>(json['audioPath']),
      transcript: serializer.fromJson<String?>(json['transcript']),
      language: serializer.fromJson<String?>(json['language']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'id': serializer.toJson<int>(id),
      'subjectType': serializer.toJson<String>(subjectType),
      'subjectId': serializer.toJson<int>(subjectId),
      'body': serializer.toJson<String?>(body),
      'audioPath': serializer.toJson<String?>(audioPath),
      'transcript': serializer.toJson<String?>(transcript),
      'language': serializer.toJson<String?>(language),
    };
  }

  Note copyWith({
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
    int? id,
    String? subjectType,
    int? subjectId,
    Value<String?> body = const Value.absent(),
    Value<String?> audioPath = const Value.absent(),
    Value<String?> transcript = const Value.absent(),
    Value<String?> language = const Value.absent(),
  }) => Note(
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    id: id ?? this.id,
    subjectType: subjectType ?? this.subjectType,
    subjectId: subjectId ?? this.subjectId,
    body: body.present ? body.value : this.body,
    audioPath: audioPath.present ? audioPath.value : this.audioPath,
    transcript: transcript.present ? transcript.value : this.transcript,
    language: language.present ? language.value : this.language,
  );
  Note copyWithCompanion(NotesCompanion data) {
    return Note(
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      id: data.id.present ? data.id.value : this.id,
      subjectType: data.subjectType.present
          ? data.subjectType.value
          : this.subjectType,
      subjectId: data.subjectId.present ? data.subjectId.value : this.subjectId,
      body: data.body.present ? data.body.value : this.body,
      audioPath: data.audioPath.present ? data.audioPath.value : this.audioPath,
      transcript: data.transcript.present
          ? data.transcript.value
          : this.transcript,
      language: data.language.present ? data.language.value : this.language,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Note(')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('id: $id, ')
          ..write('subjectType: $subjectType, ')
          ..write('subjectId: $subjectId, ')
          ..write('body: $body, ')
          ..write('audioPath: $audioPath, ')
          ..write('transcript: $transcript, ')
          ..write('language: $language')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    createdAt,
    updatedAt,
    deletedAt,
    id,
    subjectType,
    subjectId,
    body,
    audioPath,
    transcript,
    language,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Note &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.id == this.id &&
          other.subjectType == this.subjectType &&
          other.subjectId == this.subjectId &&
          other.body == this.body &&
          other.audioPath == this.audioPath &&
          other.transcript == this.transcript &&
          other.language == this.language);
}

class NotesCompanion extends UpdateCompanion<Note> {
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> id;
  final Value<String> subjectType;
  final Value<int> subjectId;
  final Value<String?> body;
  final Value<String?> audioPath;
  final Value<String?> transcript;
  final Value<String?> language;
  const NotesCompanion({
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.id = const Value.absent(),
    this.subjectType = const Value.absent(),
    this.subjectId = const Value.absent(),
    this.body = const Value.absent(),
    this.audioPath = const Value.absent(),
    this.transcript = const Value.absent(),
    this.language = const Value.absent(),
  });
  NotesCompanion.insert({
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.id = const Value.absent(),
    required String subjectType,
    required int subjectId,
    this.body = const Value.absent(),
    this.audioPath = const Value.absent(),
    this.transcript = const Value.absent(),
    this.language = const Value.absent(),
  }) : subjectType = Value(subjectType),
       subjectId = Value(subjectId);
  static Insertable<Note> custom({
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? id,
    Expression<String>? subjectType,
    Expression<int>? subjectId,
    Expression<String>? body,
    Expression<String>? audioPath,
    Expression<String>? transcript,
    Expression<String>? language,
  }) {
    return RawValuesInsertable({
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (id != null) 'id': id,
      if (subjectType != null) 'subject_type': subjectType,
      if (subjectId != null) 'subject_id': subjectId,
      if (body != null) 'body': body,
      if (audioPath != null) 'audio_path': audioPath,
      if (transcript != null) 'transcript': transcript,
      if (language != null) 'language': language,
    });
  }

  NotesCompanion copyWith({
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? id,
    Value<String>? subjectType,
    Value<int>? subjectId,
    Value<String?>? body,
    Value<String?>? audioPath,
    Value<String?>? transcript,
    Value<String?>? language,
  }) {
    return NotesCompanion(
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      id: id ?? this.id,
      subjectType: subjectType ?? this.subjectType,
      subjectId: subjectId ?? this.subjectId,
      body: body ?? this.body,
      audioPath: audioPath ?? this.audioPath,
      transcript: transcript ?? this.transcript,
      language: language ?? this.language,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (subjectType.present) {
      map['subject_type'] = Variable<String>(subjectType.value);
    }
    if (subjectId.present) {
      map['subject_id'] = Variable<int>(subjectId.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (audioPath.present) {
      map['audio_path'] = Variable<String>(audioPath.value);
    }
    if (transcript.present) {
      map['transcript'] = Variable<String>(transcript.value);
    }
    if (language.present) {
      map['language'] = Variable<String>(language.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NotesCompanion(')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('id: $id, ')
          ..write('subjectType: $subjectType, ')
          ..write('subjectId: $subjectId, ')
          ..write('body: $body, ')
          ..write('audioPath: $audioPath, ')
          ..write('transcript: $transcript, ')
          ..write('language: $language')
          ..write(')'))
        .toString();
  }
}

class $AttributesTable extends Attributes
    with TableInfo<$AttributesTable, Attribute> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AttributesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _subjectTypeMeta = const VerificationMeta(
    'subjectType',
  );
  @override
  late final GeneratedColumn<String> subjectType = GeneratedColumn<String>(
    'subject_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _subjectIdMeta = const VerificationMeta(
    'subjectId',
  );
  @override
  late final GeneratedColumn<int> subjectId = GeneratedColumn<int>(
    'subject_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<FactSource, String> source =
      GeneratedColumn<String>(
        'source',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<FactSource>($AttributesTable.$convertersource);
  static const VerificationMeta _confidenceMeta = const VerificationMeta(
    'confidence',
  );
  @override
  late final GeneratedColumn<double> confidence = GeneratedColumn<double>(
    'confidence',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    createdAt,
    updatedAt,
    deletedAt,
    id,
    subjectType,
    subjectId,
    key,
    value,
    source,
    confidence,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'attributes';
  @override
  VerificationContext validateIntegrity(
    Insertable<Attribute> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('subject_type')) {
      context.handle(
        _subjectTypeMeta,
        subjectType.isAcceptableOrUnknown(
          data['subject_type']!,
          _subjectTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_subjectTypeMeta);
    }
    if (data.containsKey('subject_id')) {
      context.handle(
        _subjectIdMeta,
        subjectId.isAcceptableOrUnknown(data['subject_id']!, _subjectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_subjectIdMeta);
    }
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    if (data.containsKey('confidence')) {
      context.handle(
        _confidenceMeta,
        confidence.isAcceptableOrUnknown(data['confidence']!, _confidenceMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Attribute map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Attribute(
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      subjectType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subject_type'],
      )!,
      subjectId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}subject_id'],
      )!,
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
      source: $AttributesTable.$convertersource.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}source'],
        )!,
      ),
      confidence: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}confidence'],
      ),
    );
  }

  @override
  $AttributesTable createAlias(String alias) {
    return $AttributesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<FactSource, String, String> $convertersource =
      const EnumNameConverter<FactSource>(FactSource.values);
}

class Attribute extends DataClass implements Insertable<Attribute> {
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final int id;
  final String subjectType;
  final int subjectId;

  /// Controlled: `price_tier`, `min_order`, `delivery_reliability`, `quality`.
  final String key;
  final String value;
  final FactSource source;
  final double? confidence;
  const Attribute({
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.id,
    required this.subjectType,
    required this.subjectId,
    required this.key,
    required this.value,
    required this.source,
    this.confidence,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['id'] = Variable<int>(id);
    map['subject_type'] = Variable<String>(subjectType);
    map['subject_id'] = Variable<int>(subjectId);
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    {
      map['source'] = Variable<String>(
        $AttributesTable.$convertersource.toSql(source),
      );
    }
    if (!nullToAbsent || confidence != null) {
      map['confidence'] = Variable<double>(confidence);
    }
    return map;
  }

  AttributesCompanion toCompanion(bool nullToAbsent) {
    return AttributesCompanion(
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      id: Value(id),
      subjectType: Value(subjectType),
      subjectId: Value(subjectId),
      key: Value(key),
      value: Value(value),
      source: Value(source),
      confidence: confidence == null && nullToAbsent
          ? const Value.absent()
          : Value(confidence),
    );
  }

  factory Attribute.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Attribute(
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      id: serializer.fromJson<int>(json['id']),
      subjectType: serializer.fromJson<String>(json['subjectType']),
      subjectId: serializer.fromJson<int>(json['subjectId']),
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
      source: $AttributesTable.$convertersource.fromJson(
        serializer.fromJson<String>(json['source']),
      ),
      confidence: serializer.fromJson<double?>(json['confidence']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'id': serializer.toJson<int>(id),
      'subjectType': serializer.toJson<String>(subjectType),
      'subjectId': serializer.toJson<int>(subjectId),
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
      'source': serializer.toJson<String>(
        $AttributesTable.$convertersource.toJson(source),
      ),
      'confidence': serializer.toJson<double?>(confidence),
    };
  }

  Attribute copyWith({
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
    int? id,
    String? subjectType,
    int? subjectId,
    String? key,
    String? value,
    FactSource? source,
    Value<double?> confidence = const Value.absent(),
  }) => Attribute(
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    id: id ?? this.id,
    subjectType: subjectType ?? this.subjectType,
    subjectId: subjectId ?? this.subjectId,
    key: key ?? this.key,
    value: value ?? this.value,
    source: source ?? this.source,
    confidence: confidence.present ? confidence.value : this.confidence,
  );
  Attribute copyWithCompanion(AttributesCompanion data) {
    return Attribute(
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      id: data.id.present ? data.id.value : this.id,
      subjectType: data.subjectType.present
          ? data.subjectType.value
          : this.subjectType,
      subjectId: data.subjectId.present ? data.subjectId.value : this.subjectId,
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
      source: data.source.present ? data.source.value : this.source,
      confidence: data.confidence.present
          ? data.confidence.value
          : this.confidence,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Attribute(')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('id: $id, ')
          ..write('subjectType: $subjectType, ')
          ..write('subjectId: $subjectId, ')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('source: $source, ')
          ..write('confidence: $confidence')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    createdAt,
    updatedAt,
    deletedAt,
    id,
    subjectType,
    subjectId,
    key,
    value,
    source,
    confidence,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Attribute &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.id == this.id &&
          other.subjectType == this.subjectType &&
          other.subjectId == this.subjectId &&
          other.key == this.key &&
          other.value == this.value &&
          other.source == this.source &&
          other.confidence == this.confidence);
}

class AttributesCompanion extends UpdateCompanion<Attribute> {
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> id;
  final Value<String> subjectType;
  final Value<int> subjectId;
  final Value<String> key;
  final Value<String> value;
  final Value<FactSource> source;
  final Value<double?> confidence;
  const AttributesCompanion({
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.id = const Value.absent(),
    this.subjectType = const Value.absent(),
    this.subjectId = const Value.absent(),
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.source = const Value.absent(),
    this.confidence = const Value.absent(),
  });
  AttributesCompanion.insert({
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.id = const Value.absent(),
    required String subjectType,
    required int subjectId,
    required String key,
    required String value,
    required FactSource source,
    this.confidence = const Value.absent(),
  }) : subjectType = Value(subjectType),
       subjectId = Value(subjectId),
       key = Value(key),
       value = Value(value),
       source = Value(source);
  static Insertable<Attribute> custom({
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? id,
    Expression<String>? subjectType,
    Expression<int>? subjectId,
    Expression<String>? key,
    Expression<String>? value,
    Expression<String>? source,
    Expression<double>? confidence,
  }) {
    return RawValuesInsertable({
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (id != null) 'id': id,
      if (subjectType != null) 'subject_type': subjectType,
      if (subjectId != null) 'subject_id': subjectId,
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (source != null) 'source': source,
      if (confidence != null) 'confidence': confidence,
    });
  }

  AttributesCompanion copyWith({
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? id,
    Value<String>? subjectType,
    Value<int>? subjectId,
    Value<String>? key,
    Value<String>? value,
    Value<FactSource>? source,
    Value<double?>? confidence,
  }) {
    return AttributesCompanion(
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      id: id ?? this.id,
      subjectType: subjectType ?? this.subjectType,
      subjectId: subjectId ?? this.subjectId,
      key: key ?? this.key,
      value: value ?? this.value,
      source: source ?? this.source,
      confidence: confidence ?? this.confidence,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (subjectType.present) {
      map['subject_type'] = Variable<String>(subjectType.value);
    }
    if (subjectId.present) {
      map['subject_id'] = Variable<int>(subjectId.value);
    }
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(
        $AttributesTable.$convertersource.toSql(source.value),
      );
    }
    if (confidence.present) {
      map['confidence'] = Variable<double>(confidence.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AttributesCompanion(')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('id: $id, ')
          ..write('subjectType: $subjectType, ')
          ..write('subjectId: $subjectId, ')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('source: $source, ')
          ..write('confidence: $confidence')
          ..write(')'))
        .toString();
  }
}

class $CapabilityProfilesTable extends CapabilityProfiles
    with TableInfo<$CapabilityProfilesTable, CapabilityProfile> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CapabilityProfilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _subjectTypeMeta = const VerificationMeta(
    'subjectType',
  );
  @override
  late final GeneratedColumn<String> subjectType = GeneratedColumn<String>(
    'subject_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _subjectIdMeta = const VerificationMeta(
    'subjectId',
  );
  @override
  late final GeneratedColumn<int> subjectId = GeneratedColumn<int>(
    'subject_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _canonicalEnMeta = const VerificationMeta(
    'canonicalEn',
  );
  @override
  late final GeneratedColumn<String> canonicalEn = GeneratedColumn<String>(
    'canonical_en',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _servicesJsonMeta = const VerificationMeta(
    'servicesJson',
  );
  @override
  late final GeneratedColumn<String> servicesJson = GeneratedColumn<String>(
    'services_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _categoriesJsonMeta = const VerificationMeta(
    'categoriesJson',
  );
  @override
  late final GeneratedColumn<String> categoriesJson = GeneratedColumn<String>(
    'categories_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _modelMeta = const VerificationMeta('model');
  @override
  late final GeneratedColumn<String> model = GeneratedColumn<String>(
    'model',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    createdAt,
    updatedAt,
    deletedAt,
    id,
    subjectType,
    subjectId,
    canonicalEn,
    servicesJson,
    categoriesJson,
    model,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'capability_profiles';
  @override
  VerificationContext validateIntegrity(
    Insertable<CapabilityProfile> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('subject_type')) {
      context.handle(
        _subjectTypeMeta,
        subjectType.isAcceptableOrUnknown(
          data['subject_type']!,
          _subjectTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_subjectTypeMeta);
    }
    if (data.containsKey('subject_id')) {
      context.handle(
        _subjectIdMeta,
        subjectId.isAcceptableOrUnknown(data['subject_id']!, _subjectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_subjectIdMeta);
    }
    if (data.containsKey('canonical_en')) {
      context.handle(
        _canonicalEnMeta,
        canonicalEn.isAcceptableOrUnknown(
          data['canonical_en']!,
          _canonicalEnMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_canonicalEnMeta);
    }
    if (data.containsKey('services_json')) {
      context.handle(
        _servicesJsonMeta,
        servicesJson.isAcceptableOrUnknown(
          data['services_json']!,
          _servicesJsonMeta,
        ),
      );
    }
    if (data.containsKey('categories_json')) {
      context.handle(
        _categoriesJsonMeta,
        categoriesJson.isAcceptableOrUnknown(
          data['categories_json']!,
          _categoriesJsonMeta,
        ),
      );
    }
    if (data.containsKey('model')) {
      context.handle(
        _modelMeta,
        model.isAcceptableOrUnknown(data['model']!, _modelMeta),
      );
    } else if (isInserting) {
      context.missing(_modelMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CapabilityProfile map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CapabilityProfile(
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      subjectType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subject_type'],
      )!,
      subjectId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}subject_id'],
      )!,
      canonicalEn: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}canonical_en'],
      )!,
      servicesJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}services_json'],
      ),
      categoriesJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}categories_json'],
      ),
      model: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model'],
      )!,
    );
  }

  @override
  $CapabilityProfilesTable createAlias(String alias) {
    return $CapabilityProfilesTable(attachedDatabase, alias);
  }
}

class CapabilityProfile extends DataClass
    implements Insertable<CapabilityProfile> {
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final int id;
  final String subjectType;
  final int subjectId;
  final String canonicalEn;
  final String? servicesJson;
  final String? categoriesJson;

  /// Lets profiles be regenerated selectively when a better model arrives.
  final String model;
  const CapabilityProfile({
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.id,
    required this.subjectType,
    required this.subjectId,
    required this.canonicalEn,
    this.servicesJson,
    this.categoriesJson,
    required this.model,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['id'] = Variable<int>(id);
    map['subject_type'] = Variable<String>(subjectType);
    map['subject_id'] = Variable<int>(subjectId);
    map['canonical_en'] = Variable<String>(canonicalEn);
    if (!nullToAbsent || servicesJson != null) {
      map['services_json'] = Variable<String>(servicesJson);
    }
    if (!nullToAbsent || categoriesJson != null) {
      map['categories_json'] = Variable<String>(categoriesJson);
    }
    map['model'] = Variable<String>(model);
    return map;
  }

  CapabilityProfilesCompanion toCompanion(bool nullToAbsent) {
    return CapabilityProfilesCompanion(
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      id: Value(id),
      subjectType: Value(subjectType),
      subjectId: Value(subjectId),
      canonicalEn: Value(canonicalEn),
      servicesJson: servicesJson == null && nullToAbsent
          ? const Value.absent()
          : Value(servicesJson),
      categoriesJson: categoriesJson == null && nullToAbsent
          ? const Value.absent()
          : Value(categoriesJson),
      model: Value(model),
    );
  }

  factory CapabilityProfile.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CapabilityProfile(
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      id: serializer.fromJson<int>(json['id']),
      subjectType: serializer.fromJson<String>(json['subjectType']),
      subjectId: serializer.fromJson<int>(json['subjectId']),
      canonicalEn: serializer.fromJson<String>(json['canonicalEn']),
      servicesJson: serializer.fromJson<String?>(json['servicesJson']),
      categoriesJson: serializer.fromJson<String?>(json['categoriesJson']),
      model: serializer.fromJson<String>(json['model']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'id': serializer.toJson<int>(id),
      'subjectType': serializer.toJson<String>(subjectType),
      'subjectId': serializer.toJson<int>(subjectId),
      'canonicalEn': serializer.toJson<String>(canonicalEn),
      'servicesJson': serializer.toJson<String?>(servicesJson),
      'categoriesJson': serializer.toJson<String?>(categoriesJson),
      'model': serializer.toJson<String>(model),
    };
  }

  CapabilityProfile copyWith({
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
    int? id,
    String? subjectType,
    int? subjectId,
    String? canonicalEn,
    Value<String?> servicesJson = const Value.absent(),
    Value<String?> categoriesJson = const Value.absent(),
    String? model,
  }) => CapabilityProfile(
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    id: id ?? this.id,
    subjectType: subjectType ?? this.subjectType,
    subjectId: subjectId ?? this.subjectId,
    canonicalEn: canonicalEn ?? this.canonicalEn,
    servicesJson: servicesJson.present ? servicesJson.value : this.servicesJson,
    categoriesJson: categoriesJson.present
        ? categoriesJson.value
        : this.categoriesJson,
    model: model ?? this.model,
  );
  CapabilityProfile copyWithCompanion(CapabilityProfilesCompanion data) {
    return CapabilityProfile(
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      id: data.id.present ? data.id.value : this.id,
      subjectType: data.subjectType.present
          ? data.subjectType.value
          : this.subjectType,
      subjectId: data.subjectId.present ? data.subjectId.value : this.subjectId,
      canonicalEn: data.canonicalEn.present
          ? data.canonicalEn.value
          : this.canonicalEn,
      servicesJson: data.servicesJson.present
          ? data.servicesJson.value
          : this.servicesJson,
      categoriesJson: data.categoriesJson.present
          ? data.categoriesJson.value
          : this.categoriesJson,
      model: data.model.present ? data.model.value : this.model,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CapabilityProfile(')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('id: $id, ')
          ..write('subjectType: $subjectType, ')
          ..write('subjectId: $subjectId, ')
          ..write('canonicalEn: $canonicalEn, ')
          ..write('servicesJson: $servicesJson, ')
          ..write('categoriesJson: $categoriesJson, ')
          ..write('model: $model')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    createdAt,
    updatedAt,
    deletedAt,
    id,
    subjectType,
    subjectId,
    canonicalEn,
    servicesJson,
    categoriesJson,
    model,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CapabilityProfile &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.id == this.id &&
          other.subjectType == this.subjectType &&
          other.subjectId == this.subjectId &&
          other.canonicalEn == this.canonicalEn &&
          other.servicesJson == this.servicesJson &&
          other.categoriesJson == this.categoriesJson &&
          other.model == this.model);
}

class CapabilityProfilesCompanion extends UpdateCompanion<CapabilityProfile> {
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> id;
  final Value<String> subjectType;
  final Value<int> subjectId;
  final Value<String> canonicalEn;
  final Value<String?> servicesJson;
  final Value<String?> categoriesJson;
  final Value<String> model;
  const CapabilityProfilesCompanion({
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.id = const Value.absent(),
    this.subjectType = const Value.absent(),
    this.subjectId = const Value.absent(),
    this.canonicalEn = const Value.absent(),
    this.servicesJson = const Value.absent(),
    this.categoriesJson = const Value.absent(),
    this.model = const Value.absent(),
  });
  CapabilityProfilesCompanion.insert({
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.id = const Value.absent(),
    required String subjectType,
    required int subjectId,
    required String canonicalEn,
    this.servicesJson = const Value.absent(),
    this.categoriesJson = const Value.absent(),
    required String model,
  }) : subjectType = Value(subjectType),
       subjectId = Value(subjectId),
       canonicalEn = Value(canonicalEn),
       model = Value(model);
  static Insertable<CapabilityProfile> custom({
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? id,
    Expression<String>? subjectType,
    Expression<int>? subjectId,
    Expression<String>? canonicalEn,
    Expression<String>? servicesJson,
    Expression<String>? categoriesJson,
    Expression<String>? model,
  }) {
    return RawValuesInsertable({
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (id != null) 'id': id,
      if (subjectType != null) 'subject_type': subjectType,
      if (subjectId != null) 'subject_id': subjectId,
      if (canonicalEn != null) 'canonical_en': canonicalEn,
      if (servicesJson != null) 'services_json': servicesJson,
      if (categoriesJson != null) 'categories_json': categoriesJson,
      if (model != null) 'model': model,
    });
  }

  CapabilityProfilesCompanion copyWith({
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? id,
    Value<String>? subjectType,
    Value<int>? subjectId,
    Value<String>? canonicalEn,
    Value<String?>? servicesJson,
    Value<String?>? categoriesJson,
    Value<String>? model,
  }) {
    return CapabilityProfilesCompanion(
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      id: id ?? this.id,
      subjectType: subjectType ?? this.subjectType,
      subjectId: subjectId ?? this.subjectId,
      canonicalEn: canonicalEn ?? this.canonicalEn,
      servicesJson: servicesJson ?? this.servicesJson,
      categoriesJson: categoriesJson ?? this.categoriesJson,
      model: model ?? this.model,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (subjectType.present) {
      map['subject_type'] = Variable<String>(subjectType.value);
    }
    if (subjectId.present) {
      map['subject_id'] = Variable<int>(subjectId.value);
    }
    if (canonicalEn.present) {
      map['canonical_en'] = Variable<String>(canonicalEn.value);
    }
    if (servicesJson.present) {
      map['services_json'] = Variable<String>(servicesJson.value);
    }
    if (categoriesJson.present) {
      map['categories_json'] = Variable<String>(categoriesJson.value);
    }
    if (model.present) {
      map['model'] = Variable<String>(model.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CapabilityProfilesCompanion(')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('id: $id, ')
          ..write('subjectType: $subjectType, ')
          ..write('subjectId: $subjectId, ')
          ..write('canonicalEn: $canonicalEn, ')
          ..write('servicesJson: $servicesJson, ')
          ..write('categoriesJson: $categoriesJson, ')
          ..write('model: $model')
          ..write(')'))
        .toString();
  }
}

class $EmbeddingsTable extends Embeddings
    with TableInfo<$EmbeddingsTable, Embedding> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EmbeddingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _subjectTypeMeta = const VerificationMeta(
    'subjectType',
  );
  @override
  late final GeneratedColumn<String> subjectType = GeneratedColumn<String>(
    'subject_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _subjectIdMeta = const VerificationMeta(
    'subjectId',
  );
  @override
  late final GeneratedColumn<int> subjectId = GeneratedColumn<int>(
    'subject_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _vectorMeta = const VerificationMeta('vector');
  @override
  late final GeneratedColumn<Uint8List> vector = GeneratedColumn<Uint8List>(
    'vector',
    aliasedName,
    false,
    type: DriftSqlType.blob,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dimMeta = const VerificationMeta('dim');
  @override
  late final GeneratedColumn<int> dim = GeneratedColumn<int>(
    'dim',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _modelMeta = const VerificationMeta('model');
  @override
  late final GeneratedColumn<String> model = GeneratedColumn<String>(
    'model',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    createdAt,
    updatedAt,
    deletedAt,
    id,
    subjectType,
    subjectId,
    vector,
    dim,
    model,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'embeddings';
  @override
  VerificationContext validateIntegrity(
    Insertable<Embedding> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('subject_type')) {
      context.handle(
        _subjectTypeMeta,
        subjectType.isAcceptableOrUnknown(
          data['subject_type']!,
          _subjectTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_subjectTypeMeta);
    }
    if (data.containsKey('subject_id')) {
      context.handle(
        _subjectIdMeta,
        subjectId.isAcceptableOrUnknown(data['subject_id']!, _subjectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_subjectIdMeta);
    }
    if (data.containsKey('vector')) {
      context.handle(
        _vectorMeta,
        vector.isAcceptableOrUnknown(data['vector']!, _vectorMeta),
      );
    } else if (isInserting) {
      context.missing(_vectorMeta);
    }
    if (data.containsKey('dim')) {
      context.handle(
        _dimMeta,
        dim.isAcceptableOrUnknown(data['dim']!, _dimMeta),
      );
    } else if (isInserting) {
      context.missing(_dimMeta);
    }
    if (data.containsKey('model')) {
      context.handle(
        _modelMeta,
        model.isAcceptableOrUnknown(data['model']!, _modelMeta),
      );
    } else if (isInserting) {
      context.missing(_modelMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Embedding map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Embedding(
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      subjectType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subject_type'],
      )!,
      subjectId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}subject_id'],
      )!,
      vector: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}vector'],
      )!,
      dim: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}dim'],
      )!,
      model: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model'],
      )!,
    );
  }

  @override
  $EmbeddingsTable createAlias(String alias) {
    return $EmbeddingsTable(attachedDatabase, alias);
  }
}

class Embedding extends DataClass implements Insertable<Embedding> {
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final int id;
  final String subjectType;
  final int subjectId;
  final Uint8List vector;
  final int dim;
  final String model;
  const Embedding({
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.id,
    required this.subjectType,
    required this.subjectId,
    required this.vector,
    required this.dim,
    required this.model,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['id'] = Variable<int>(id);
    map['subject_type'] = Variable<String>(subjectType);
    map['subject_id'] = Variable<int>(subjectId);
    map['vector'] = Variable<Uint8List>(vector);
    map['dim'] = Variable<int>(dim);
    map['model'] = Variable<String>(model);
    return map;
  }

  EmbeddingsCompanion toCompanion(bool nullToAbsent) {
    return EmbeddingsCompanion(
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      id: Value(id),
      subjectType: Value(subjectType),
      subjectId: Value(subjectId),
      vector: Value(vector),
      dim: Value(dim),
      model: Value(model),
    );
  }

  factory Embedding.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Embedding(
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      id: serializer.fromJson<int>(json['id']),
      subjectType: serializer.fromJson<String>(json['subjectType']),
      subjectId: serializer.fromJson<int>(json['subjectId']),
      vector: serializer.fromJson<Uint8List>(json['vector']),
      dim: serializer.fromJson<int>(json['dim']),
      model: serializer.fromJson<String>(json['model']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'id': serializer.toJson<int>(id),
      'subjectType': serializer.toJson<String>(subjectType),
      'subjectId': serializer.toJson<int>(subjectId),
      'vector': serializer.toJson<Uint8List>(vector),
      'dim': serializer.toJson<int>(dim),
      'model': serializer.toJson<String>(model),
    };
  }

  Embedding copyWith({
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
    int? id,
    String? subjectType,
    int? subjectId,
    Uint8List? vector,
    int? dim,
    String? model,
  }) => Embedding(
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    id: id ?? this.id,
    subjectType: subjectType ?? this.subjectType,
    subjectId: subjectId ?? this.subjectId,
    vector: vector ?? this.vector,
    dim: dim ?? this.dim,
    model: model ?? this.model,
  );
  Embedding copyWithCompanion(EmbeddingsCompanion data) {
    return Embedding(
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      id: data.id.present ? data.id.value : this.id,
      subjectType: data.subjectType.present
          ? data.subjectType.value
          : this.subjectType,
      subjectId: data.subjectId.present ? data.subjectId.value : this.subjectId,
      vector: data.vector.present ? data.vector.value : this.vector,
      dim: data.dim.present ? data.dim.value : this.dim,
      model: data.model.present ? data.model.value : this.model,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Embedding(')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('id: $id, ')
          ..write('subjectType: $subjectType, ')
          ..write('subjectId: $subjectId, ')
          ..write('vector: $vector, ')
          ..write('dim: $dim, ')
          ..write('model: $model')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    createdAt,
    updatedAt,
    deletedAt,
    id,
    subjectType,
    subjectId,
    $driftBlobEquality.hash(vector),
    dim,
    model,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Embedding &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.id == this.id &&
          other.subjectType == this.subjectType &&
          other.subjectId == this.subjectId &&
          $driftBlobEquality.equals(other.vector, this.vector) &&
          other.dim == this.dim &&
          other.model == this.model);
}

class EmbeddingsCompanion extends UpdateCompanion<Embedding> {
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> id;
  final Value<String> subjectType;
  final Value<int> subjectId;
  final Value<Uint8List> vector;
  final Value<int> dim;
  final Value<String> model;
  const EmbeddingsCompanion({
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.id = const Value.absent(),
    this.subjectType = const Value.absent(),
    this.subjectId = const Value.absent(),
    this.vector = const Value.absent(),
    this.dim = const Value.absent(),
    this.model = const Value.absent(),
  });
  EmbeddingsCompanion.insert({
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.id = const Value.absent(),
    required String subjectType,
    required int subjectId,
    required Uint8List vector,
    required int dim,
    required String model,
  }) : subjectType = Value(subjectType),
       subjectId = Value(subjectId),
       vector = Value(vector),
       dim = Value(dim),
       model = Value(model);
  static Insertable<Embedding> custom({
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? id,
    Expression<String>? subjectType,
    Expression<int>? subjectId,
    Expression<Uint8List>? vector,
    Expression<int>? dim,
    Expression<String>? model,
  }) {
    return RawValuesInsertable({
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (id != null) 'id': id,
      if (subjectType != null) 'subject_type': subjectType,
      if (subjectId != null) 'subject_id': subjectId,
      if (vector != null) 'vector': vector,
      if (dim != null) 'dim': dim,
      if (model != null) 'model': model,
    });
  }

  EmbeddingsCompanion copyWith({
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? id,
    Value<String>? subjectType,
    Value<int>? subjectId,
    Value<Uint8List>? vector,
    Value<int>? dim,
    Value<String>? model,
  }) {
    return EmbeddingsCompanion(
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      id: id ?? this.id,
      subjectType: subjectType ?? this.subjectType,
      subjectId: subjectId ?? this.subjectId,
      vector: vector ?? this.vector,
      dim: dim ?? this.dim,
      model: model ?? this.model,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (subjectType.present) {
      map['subject_type'] = Variable<String>(subjectType.value);
    }
    if (subjectId.present) {
      map['subject_id'] = Variable<int>(subjectId.value);
    }
    if (vector.present) {
      map['vector'] = Variable<Uint8List>(vector.value);
    }
    if (dim.present) {
      map['dim'] = Variable<int>(dim.value);
    }
    if (model.present) {
      map['model'] = Variable<String>(model.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EmbeddingsCompanion(')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('id: $id, ')
          ..write('subjectType: $subjectType, ')
          ..write('subjectId: $subjectId, ')
          ..write('vector: $vector, ')
          ..write('dim: $dim, ')
          ..write('model: $model')
          ..write(')'))
        .toString();
  }
}

class $InteractionsTable extends Interactions
    with TableInfo<$InteractionsTable, Interaction> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $InteractionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _subjectTypeMeta = const VerificationMeta(
    'subjectType',
  );
  @override
  late final GeneratedColumn<String> subjectType = GeneratedColumn<String>(
    'subject_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _subjectIdMeta = const VerificationMeta(
    'subjectId',
  );
  @override
  late final GeneratedColumn<int> subjectId = GeneratedColumn<int>(
    'subject_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<InteractionKind, String> kind =
      GeneratedColumn<String>(
        'kind',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<InteractionKind>($InteractionsTable.$converterkind);
  static const VerificationMeta _detailMeta = const VerificationMeta('detail');
  @override
  late final GeneratedColumn<String> detail = GeneratedColumn<String>(
    'detail',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _occurredAtMeta = const VerificationMeta(
    'occurredAt',
  );
  @override
  late final GeneratedColumn<DateTime> occurredAt = GeneratedColumn<DateTime>(
    'occurred_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    subjectType,
    subjectId,
    kind,
    detail,
    occurredAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'interactions';
  @override
  VerificationContext validateIntegrity(
    Insertable<Interaction> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('subject_type')) {
      context.handle(
        _subjectTypeMeta,
        subjectType.isAcceptableOrUnknown(
          data['subject_type']!,
          _subjectTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_subjectTypeMeta);
    }
    if (data.containsKey('subject_id')) {
      context.handle(
        _subjectIdMeta,
        subjectId.isAcceptableOrUnknown(data['subject_id']!, _subjectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_subjectIdMeta);
    }
    if (data.containsKey('detail')) {
      context.handle(
        _detailMeta,
        detail.isAcceptableOrUnknown(data['detail']!, _detailMeta),
      );
    }
    if (data.containsKey('occurred_at')) {
      context.handle(
        _occurredAtMeta,
        occurredAt.isAcceptableOrUnknown(data['occurred_at']!, _occurredAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Interaction map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Interaction(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      subjectType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subject_type'],
      )!,
      subjectId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}subject_id'],
      )!,
      kind: $InteractionsTable.$converterkind.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}kind'],
        )!,
      ),
      detail: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}detail'],
      ),
      occurredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}occurred_at'],
      )!,
    );
  }

  @override
  $InteractionsTable createAlias(String alias) {
    return $InteractionsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<InteractionKind, String, String> $converterkind =
      const EnumNameConverter<InteractionKind>(InteractionKind.values);
}

class Interaction extends DataClass implements Insertable<Interaction> {
  final int id;
  final String subjectType;
  final int subjectId;
  final InteractionKind kind;
  final String? detail;
  final DateTime occurredAt;
  const Interaction({
    required this.id,
    required this.subjectType,
    required this.subjectId,
    required this.kind,
    this.detail,
    required this.occurredAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['subject_type'] = Variable<String>(subjectType);
    map['subject_id'] = Variable<int>(subjectId);
    {
      map['kind'] = Variable<String>(
        $InteractionsTable.$converterkind.toSql(kind),
      );
    }
    if (!nullToAbsent || detail != null) {
      map['detail'] = Variable<String>(detail);
    }
    map['occurred_at'] = Variable<DateTime>(occurredAt);
    return map;
  }

  InteractionsCompanion toCompanion(bool nullToAbsent) {
    return InteractionsCompanion(
      id: Value(id),
      subjectType: Value(subjectType),
      subjectId: Value(subjectId),
      kind: Value(kind),
      detail: detail == null && nullToAbsent
          ? const Value.absent()
          : Value(detail),
      occurredAt: Value(occurredAt),
    );
  }

  factory Interaction.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Interaction(
      id: serializer.fromJson<int>(json['id']),
      subjectType: serializer.fromJson<String>(json['subjectType']),
      subjectId: serializer.fromJson<int>(json['subjectId']),
      kind: $InteractionsTable.$converterkind.fromJson(
        serializer.fromJson<String>(json['kind']),
      ),
      detail: serializer.fromJson<String?>(json['detail']),
      occurredAt: serializer.fromJson<DateTime>(json['occurredAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'subjectType': serializer.toJson<String>(subjectType),
      'subjectId': serializer.toJson<int>(subjectId),
      'kind': serializer.toJson<String>(
        $InteractionsTable.$converterkind.toJson(kind),
      ),
      'detail': serializer.toJson<String?>(detail),
      'occurredAt': serializer.toJson<DateTime>(occurredAt),
    };
  }

  Interaction copyWith({
    int? id,
    String? subjectType,
    int? subjectId,
    InteractionKind? kind,
    Value<String?> detail = const Value.absent(),
    DateTime? occurredAt,
  }) => Interaction(
    id: id ?? this.id,
    subjectType: subjectType ?? this.subjectType,
    subjectId: subjectId ?? this.subjectId,
    kind: kind ?? this.kind,
    detail: detail.present ? detail.value : this.detail,
    occurredAt: occurredAt ?? this.occurredAt,
  );
  Interaction copyWithCompanion(InteractionsCompanion data) {
    return Interaction(
      id: data.id.present ? data.id.value : this.id,
      subjectType: data.subjectType.present
          ? data.subjectType.value
          : this.subjectType,
      subjectId: data.subjectId.present ? data.subjectId.value : this.subjectId,
      kind: data.kind.present ? data.kind.value : this.kind,
      detail: data.detail.present ? data.detail.value : this.detail,
      occurredAt: data.occurredAt.present
          ? data.occurredAt.value
          : this.occurredAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Interaction(')
          ..write('id: $id, ')
          ..write('subjectType: $subjectType, ')
          ..write('subjectId: $subjectId, ')
          ..write('kind: $kind, ')
          ..write('detail: $detail, ')
          ..write('occurredAt: $occurredAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, subjectType, subjectId, kind, detail, occurredAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Interaction &&
          other.id == this.id &&
          other.subjectType == this.subjectType &&
          other.subjectId == this.subjectId &&
          other.kind == this.kind &&
          other.detail == this.detail &&
          other.occurredAt == this.occurredAt);
}

class InteractionsCompanion extends UpdateCompanion<Interaction> {
  final Value<int> id;
  final Value<String> subjectType;
  final Value<int> subjectId;
  final Value<InteractionKind> kind;
  final Value<String?> detail;
  final Value<DateTime> occurredAt;
  const InteractionsCompanion({
    this.id = const Value.absent(),
    this.subjectType = const Value.absent(),
    this.subjectId = const Value.absent(),
    this.kind = const Value.absent(),
    this.detail = const Value.absent(),
    this.occurredAt = const Value.absent(),
  });
  InteractionsCompanion.insert({
    this.id = const Value.absent(),
    required String subjectType,
    required int subjectId,
    required InteractionKind kind,
    this.detail = const Value.absent(),
    this.occurredAt = const Value.absent(),
  }) : subjectType = Value(subjectType),
       subjectId = Value(subjectId),
       kind = Value(kind);
  static Insertable<Interaction> custom({
    Expression<int>? id,
    Expression<String>? subjectType,
    Expression<int>? subjectId,
    Expression<String>? kind,
    Expression<String>? detail,
    Expression<DateTime>? occurredAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (subjectType != null) 'subject_type': subjectType,
      if (subjectId != null) 'subject_id': subjectId,
      if (kind != null) 'kind': kind,
      if (detail != null) 'detail': detail,
      if (occurredAt != null) 'occurred_at': occurredAt,
    });
  }

  InteractionsCompanion copyWith({
    Value<int>? id,
    Value<String>? subjectType,
    Value<int>? subjectId,
    Value<InteractionKind>? kind,
    Value<String?>? detail,
    Value<DateTime>? occurredAt,
  }) {
    return InteractionsCompanion(
      id: id ?? this.id,
      subjectType: subjectType ?? this.subjectType,
      subjectId: subjectId ?? this.subjectId,
      kind: kind ?? this.kind,
      detail: detail ?? this.detail,
      occurredAt: occurredAt ?? this.occurredAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (subjectType.present) {
      map['subject_type'] = Variable<String>(subjectType.value);
    }
    if (subjectId.present) {
      map['subject_id'] = Variable<int>(subjectId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(
        $InteractionsTable.$converterkind.toSql(kind.value),
      );
    }
    if (detail.present) {
      map['detail'] = Variable<String>(detail.value);
    }
    if (occurredAt.present) {
      map['occurred_at'] = Variable<DateTime>(occurredAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('InteractionsCompanion(')
          ..write('id: $id, ')
          ..write('subjectType: $subjectType, ')
          ..write('subjectId: $subjectId, ')
          ..write('kind: $kind, ')
          ..write('detail: $detail, ')
          ..write('occurredAt: $occurredAt')
          ..write(')'))
        .toString();
  }
}

class $TagsTable extends Tags with TableInfo<$TagsTable, Tag> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TagsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    createdAt,
    updatedAt,
    deletedAt,
    id,
    name,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tags';
  @override
  VerificationContext validateIntegrity(
    Insertable<Tag> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Tag map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Tag(
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
    );
  }

  @override
  $TagsTable createAlias(String alias) {
    return $TagsTable(attachedDatabase, alias);
  }
}

class Tag extends DataClass implements Insertable<Tag> {
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final int id;
  final String name;
  const Tag({
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.id,
    required this.name,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    return map;
  }

  TagsCompanion toCompanion(bool nullToAbsent) {
    return TagsCompanion(
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      id: Value(id),
      name: Value(name),
    );
  }

  factory Tag.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Tag(
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
    };
  }

  Tag copyWith({
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
    int? id,
    String? name,
  }) => Tag(
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    id: id ?? this.id,
    name: name ?? this.name,
  );
  Tag copyWithCompanion(TagsCompanion data) {
    return Tag(
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Tag(')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('id: $id, ')
          ..write('name: $name')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(createdAt, updatedAt, deletedAt, id, name);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Tag &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.id == this.id &&
          other.name == this.name);
}

class TagsCompanion extends UpdateCompanion<Tag> {
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> id;
  final Value<String> name;
  const TagsCompanion({
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.id = const Value.absent(),
    this.name = const Value.absent(),
  });
  TagsCompanion.insert({
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.id = const Value.absent(),
    required String name,
  }) : name = Value(name);
  static Insertable<Tag> custom({
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? id,
    Expression<String>? name,
  }) {
    return RawValuesInsertable({
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (id != null) 'id': id,
      if (name != null) 'name': name,
    });
  }

  TagsCompanion copyWith({
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? id,
    Value<String>? name,
  }) {
    return TagsCompanion(
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      id: id ?? this.id,
      name: name ?? this.name,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TagsCompanion(')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('id: $id, ')
          ..write('name: $name')
          ..write(')'))
        .toString();
  }
}

class $SubjectTagsTable extends SubjectTags
    with TableInfo<$SubjectTagsTable, SubjectTag> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SubjectTagsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _tagIdMeta = const VerificationMeta('tagId');
  @override
  late final GeneratedColumn<int> tagId = GeneratedColumn<int>(
    'tag_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES tags (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _subjectTypeMeta = const VerificationMeta(
    'subjectType',
  );
  @override
  late final GeneratedColumn<String> subjectType = GeneratedColumn<String>(
    'subject_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _subjectIdMeta = const VerificationMeta(
    'subjectId',
  );
  @override
  late final GeneratedColumn<int> subjectId = GeneratedColumn<int>(
    'subject_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [tagId, subjectType, subjectId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'subject_tags';
  @override
  VerificationContext validateIntegrity(
    Insertable<SubjectTag> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('tag_id')) {
      context.handle(
        _tagIdMeta,
        tagId.isAcceptableOrUnknown(data['tag_id']!, _tagIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tagIdMeta);
    }
    if (data.containsKey('subject_type')) {
      context.handle(
        _subjectTypeMeta,
        subjectType.isAcceptableOrUnknown(
          data['subject_type']!,
          _subjectTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_subjectTypeMeta);
    }
    if (data.containsKey('subject_id')) {
      context.handle(
        _subjectIdMeta,
        subjectId.isAcceptableOrUnknown(data['subject_id']!, _subjectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_subjectIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {tagId, subjectType, subjectId};
  @override
  SubjectTag map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SubjectTag(
      tagId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tag_id'],
      )!,
      subjectType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subject_type'],
      )!,
      subjectId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}subject_id'],
      )!,
    );
  }

  @override
  $SubjectTagsTable createAlias(String alias) {
    return $SubjectTagsTable(attachedDatabase, alias);
  }
}

class SubjectTag extends DataClass implements Insertable<SubjectTag> {
  final int tagId;
  final String subjectType;
  final int subjectId;
  const SubjectTag({
    required this.tagId,
    required this.subjectType,
    required this.subjectId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['tag_id'] = Variable<int>(tagId);
    map['subject_type'] = Variable<String>(subjectType);
    map['subject_id'] = Variable<int>(subjectId);
    return map;
  }

  SubjectTagsCompanion toCompanion(bool nullToAbsent) {
    return SubjectTagsCompanion(
      tagId: Value(tagId),
      subjectType: Value(subjectType),
      subjectId: Value(subjectId),
    );
  }

  factory SubjectTag.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SubjectTag(
      tagId: serializer.fromJson<int>(json['tagId']),
      subjectType: serializer.fromJson<String>(json['subjectType']),
      subjectId: serializer.fromJson<int>(json['subjectId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'tagId': serializer.toJson<int>(tagId),
      'subjectType': serializer.toJson<String>(subjectType),
      'subjectId': serializer.toJson<int>(subjectId),
    };
  }

  SubjectTag copyWith({int? tagId, String? subjectType, int? subjectId}) =>
      SubjectTag(
        tagId: tagId ?? this.tagId,
        subjectType: subjectType ?? this.subjectType,
        subjectId: subjectId ?? this.subjectId,
      );
  SubjectTag copyWithCompanion(SubjectTagsCompanion data) {
    return SubjectTag(
      tagId: data.tagId.present ? data.tagId.value : this.tagId,
      subjectType: data.subjectType.present
          ? data.subjectType.value
          : this.subjectType,
      subjectId: data.subjectId.present ? data.subjectId.value : this.subjectId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SubjectTag(')
          ..write('tagId: $tagId, ')
          ..write('subjectType: $subjectType, ')
          ..write('subjectId: $subjectId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(tagId, subjectType, subjectId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SubjectTag &&
          other.tagId == this.tagId &&
          other.subjectType == this.subjectType &&
          other.subjectId == this.subjectId);
}

class SubjectTagsCompanion extends UpdateCompanion<SubjectTag> {
  final Value<int> tagId;
  final Value<String> subjectType;
  final Value<int> subjectId;
  final Value<int> rowid;
  const SubjectTagsCompanion({
    this.tagId = const Value.absent(),
    this.subjectType = const Value.absent(),
    this.subjectId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SubjectTagsCompanion.insert({
    required int tagId,
    required String subjectType,
    required int subjectId,
    this.rowid = const Value.absent(),
  }) : tagId = Value(tagId),
       subjectType = Value(subjectType),
       subjectId = Value(subjectId);
  static Insertable<SubjectTag> custom({
    Expression<int>? tagId,
    Expression<String>? subjectType,
    Expression<int>? subjectId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (tagId != null) 'tag_id': tagId,
      if (subjectType != null) 'subject_type': subjectType,
      if (subjectId != null) 'subject_id': subjectId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SubjectTagsCompanion copyWith({
    Value<int>? tagId,
    Value<String>? subjectType,
    Value<int>? subjectId,
    Value<int>? rowid,
  }) {
    return SubjectTagsCompanion(
      tagId: tagId ?? this.tagId,
      subjectType: subjectType ?? this.subjectType,
      subjectId: subjectId ?? this.subjectId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (tagId.present) {
      map['tag_id'] = Variable<int>(tagId.value);
    }
    if (subjectType.present) {
      map['subject_type'] = Variable<String>(subjectType.value);
    }
    if (subjectId.present) {
      map['subject_id'] = Variable<int>(subjectId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SubjectTagsCompanion(')
          ..write('tagId: $tagId, ')
          ..write('subjectType: $subjectType, ')
          ..write('subjectId: $subjectId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SearchQueriesTable extends SearchQueries
    with TableInfo<$SearchQueriesTable, SearchQuery> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SearchQueriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _rawMeta = const VerificationMeta('raw');
  @override
  late final GeneratedColumn<String> raw = GeneratedColumn<String>(
    'raw',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _normalizedJsonMeta = const VerificationMeta(
    'normalizedJson',
  );
  @override
  late final GeneratedColumn<String> normalizedJson = GeneratedColumn<String>(
    'normalized_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _langMeta = const VerificationMeta('lang');
  @override
  late final GeneratedColumn<String> lang = GeneratedColumn<String>(
    'lang',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    raw,
    normalizedJson,
    lang,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'search_queries';
  @override
  VerificationContext validateIntegrity(
    Insertable<SearchQuery> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('raw')) {
      context.handle(
        _rawMeta,
        raw.isAcceptableOrUnknown(data['raw']!, _rawMeta),
      );
    } else if (isInserting) {
      context.missing(_rawMeta);
    }
    if (data.containsKey('normalized_json')) {
      context.handle(
        _normalizedJsonMeta,
        normalizedJson.isAcceptableOrUnknown(
          data['normalized_json']!,
          _normalizedJsonMeta,
        ),
      );
    }
    if (data.containsKey('lang')) {
      context.handle(
        _langMeta,
        lang.isAcceptableOrUnknown(data['lang']!, _langMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SearchQuery map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SearchQuery(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      raw: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}raw'],
      )!,
      normalizedJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}normalized_json'],
      ),
      lang: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lang'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $SearchQueriesTable createAlias(String alias) {
    return $SearchQueriesTable(attachedDatabase, alias);
  }
}

class SearchQuery extends DataClass implements Insertable<SearchQuery> {
  final int id;
  final String raw;

  /// Serialised [QueryIntent]. Kept so the raw-vs-normalised ablation can be
  /// run over real queries later.
  final String? normalizedJson;
  final String? lang;
  final DateTime createdAt;
  const SearchQuery({
    required this.id,
    required this.raw,
    this.normalizedJson,
    this.lang,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['raw'] = Variable<String>(raw);
    if (!nullToAbsent || normalizedJson != null) {
      map['normalized_json'] = Variable<String>(normalizedJson);
    }
    if (!nullToAbsent || lang != null) {
      map['lang'] = Variable<String>(lang);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  SearchQueriesCompanion toCompanion(bool nullToAbsent) {
    return SearchQueriesCompanion(
      id: Value(id),
      raw: Value(raw),
      normalizedJson: normalizedJson == null && nullToAbsent
          ? const Value.absent()
          : Value(normalizedJson),
      lang: lang == null && nullToAbsent ? const Value.absent() : Value(lang),
      createdAt: Value(createdAt),
    );
  }

  factory SearchQuery.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SearchQuery(
      id: serializer.fromJson<int>(json['id']),
      raw: serializer.fromJson<String>(json['raw']),
      normalizedJson: serializer.fromJson<String?>(json['normalizedJson']),
      lang: serializer.fromJson<String?>(json['lang']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'raw': serializer.toJson<String>(raw),
      'normalizedJson': serializer.toJson<String?>(normalizedJson),
      'lang': serializer.toJson<String?>(lang),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  SearchQuery copyWith({
    int? id,
    String? raw,
    Value<String?> normalizedJson = const Value.absent(),
    Value<String?> lang = const Value.absent(),
    DateTime? createdAt,
  }) => SearchQuery(
    id: id ?? this.id,
    raw: raw ?? this.raw,
    normalizedJson: normalizedJson.present
        ? normalizedJson.value
        : this.normalizedJson,
    lang: lang.present ? lang.value : this.lang,
    createdAt: createdAt ?? this.createdAt,
  );
  SearchQuery copyWithCompanion(SearchQueriesCompanion data) {
    return SearchQuery(
      id: data.id.present ? data.id.value : this.id,
      raw: data.raw.present ? data.raw.value : this.raw,
      normalizedJson: data.normalizedJson.present
          ? data.normalizedJson.value
          : this.normalizedJson,
      lang: data.lang.present ? data.lang.value : this.lang,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SearchQuery(')
          ..write('id: $id, ')
          ..write('raw: $raw, ')
          ..write('normalizedJson: $normalizedJson, ')
          ..write('lang: $lang, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, raw, normalizedJson, lang, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SearchQuery &&
          other.id == this.id &&
          other.raw == this.raw &&
          other.normalizedJson == this.normalizedJson &&
          other.lang == this.lang &&
          other.createdAt == this.createdAt);
}

class SearchQueriesCompanion extends UpdateCompanion<SearchQuery> {
  final Value<int> id;
  final Value<String> raw;
  final Value<String?> normalizedJson;
  final Value<String?> lang;
  final Value<DateTime> createdAt;
  const SearchQueriesCompanion({
    this.id = const Value.absent(),
    this.raw = const Value.absent(),
    this.normalizedJson = const Value.absent(),
    this.lang = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  SearchQueriesCompanion.insert({
    this.id = const Value.absent(),
    required String raw,
    this.normalizedJson = const Value.absent(),
    this.lang = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : raw = Value(raw);
  static Insertable<SearchQuery> custom({
    Expression<int>? id,
    Expression<String>? raw,
    Expression<String>? normalizedJson,
    Expression<String>? lang,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (raw != null) 'raw': raw,
      if (normalizedJson != null) 'normalized_json': normalizedJson,
      if (lang != null) 'lang': lang,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  SearchQueriesCompanion copyWith({
    Value<int>? id,
    Value<String>? raw,
    Value<String?>? normalizedJson,
    Value<String?>? lang,
    Value<DateTime>? createdAt,
  }) {
    return SearchQueriesCompanion(
      id: id ?? this.id,
      raw: raw ?? this.raw,
      normalizedJson: normalizedJson ?? this.normalizedJson,
      lang: lang ?? this.lang,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (raw.present) {
      map['raw'] = Variable<String>(raw.value);
    }
    if (normalizedJson.present) {
      map['normalized_json'] = Variable<String>(normalizedJson.value);
    }
    if (lang.present) {
      map['lang'] = Variable<String>(lang.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SearchQueriesCompanion(')
          ..write('id: $id, ')
          ..write('raw: $raw, ')
          ..write('normalizedJson: $normalizedJson, ')
          ..write('lang: $lang, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $SearchFeedbackTable extends SearchFeedback
    with TableInfo<$SearchFeedbackTable, SearchFeedbackData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SearchFeedbackTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _queryIdMeta = const VerificationMeta(
    'queryId',
  );
  @override
  late final GeneratedColumn<int> queryId = GeneratedColumn<int>(
    'query_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES search_queries (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _subjectTypeMeta = const VerificationMeta(
    'subjectType',
  );
  @override
  late final GeneratedColumn<String> subjectType = GeneratedColumn<String>(
    'subject_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _subjectIdMeta = const VerificationMeta(
    'subjectId',
  );
  @override
  late final GeneratedColumn<int> subjectId = GeneratedColumn<int>(
    'subject_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _verdictMeta = const VerificationMeta(
    'verdict',
  );
  @override
  late final GeneratedColumn<String> verdict = GeneratedColumn<String>(
    'verdict',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    queryId,
    subjectType,
    subjectId,
    verdict,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'search_feedback';
  @override
  VerificationContext validateIntegrity(
    Insertable<SearchFeedbackData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('query_id')) {
      context.handle(
        _queryIdMeta,
        queryId.isAcceptableOrUnknown(data['query_id']!, _queryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_queryIdMeta);
    }
    if (data.containsKey('subject_type')) {
      context.handle(
        _subjectTypeMeta,
        subjectType.isAcceptableOrUnknown(
          data['subject_type']!,
          _subjectTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_subjectTypeMeta);
    }
    if (data.containsKey('subject_id')) {
      context.handle(
        _subjectIdMeta,
        subjectId.isAcceptableOrUnknown(data['subject_id']!, _subjectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_subjectIdMeta);
    }
    if (data.containsKey('verdict')) {
      context.handle(
        _verdictMeta,
        verdict.isAcceptableOrUnknown(data['verdict']!, _verdictMeta),
      );
    } else if (isInserting) {
      context.missing(_verdictMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SearchFeedbackData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SearchFeedbackData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      queryId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}query_id'],
      )!,
      subjectType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subject_type'],
      )!,
      subjectId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}subject_id'],
      )!,
      verdict: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}verdict'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $SearchFeedbackTable createAlias(String alias) {
    return $SearchFeedbackTable(attachedDatabase, alias);
  }
}

class SearchFeedbackData extends DataClass
    implements Insertable<SearchFeedbackData> {
  final int id;
  final int queryId;
  final String subjectType;
  final int subjectId;

  /// `useful`, `not_relevant`, `outdated`, `wrong_person`, `wrong_category`.
  final String verdict;
  final DateTime createdAt;
  const SearchFeedbackData({
    required this.id,
    required this.queryId,
    required this.subjectType,
    required this.subjectId,
    required this.verdict,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['query_id'] = Variable<int>(queryId);
    map['subject_type'] = Variable<String>(subjectType);
    map['subject_id'] = Variable<int>(subjectId);
    map['verdict'] = Variable<String>(verdict);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  SearchFeedbackCompanion toCompanion(bool nullToAbsent) {
    return SearchFeedbackCompanion(
      id: Value(id),
      queryId: Value(queryId),
      subjectType: Value(subjectType),
      subjectId: Value(subjectId),
      verdict: Value(verdict),
      createdAt: Value(createdAt),
    );
  }

  factory SearchFeedbackData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SearchFeedbackData(
      id: serializer.fromJson<int>(json['id']),
      queryId: serializer.fromJson<int>(json['queryId']),
      subjectType: serializer.fromJson<String>(json['subjectType']),
      subjectId: serializer.fromJson<int>(json['subjectId']),
      verdict: serializer.fromJson<String>(json['verdict']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'queryId': serializer.toJson<int>(queryId),
      'subjectType': serializer.toJson<String>(subjectType),
      'subjectId': serializer.toJson<int>(subjectId),
      'verdict': serializer.toJson<String>(verdict),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  SearchFeedbackData copyWith({
    int? id,
    int? queryId,
    String? subjectType,
    int? subjectId,
    String? verdict,
    DateTime? createdAt,
  }) => SearchFeedbackData(
    id: id ?? this.id,
    queryId: queryId ?? this.queryId,
    subjectType: subjectType ?? this.subjectType,
    subjectId: subjectId ?? this.subjectId,
    verdict: verdict ?? this.verdict,
    createdAt: createdAt ?? this.createdAt,
  );
  SearchFeedbackData copyWithCompanion(SearchFeedbackCompanion data) {
    return SearchFeedbackData(
      id: data.id.present ? data.id.value : this.id,
      queryId: data.queryId.present ? data.queryId.value : this.queryId,
      subjectType: data.subjectType.present
          ? data.subjectType.value
          : this.subjectType,
      subjectId: data.subjectId.present ? data.subjectId.value : this.subjectId,
      verdict: data.verdict.present ? data.verdict.value : this.verdict,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SearchFeedbackData(')
          ..write('id: $id, ')
          ..write('queryId: $queryId, ')
          ..write('subjectType: $subjectType, ')
          ..write('subjectId: $subjectId, ')
          ..write('verdict: $verdict, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, queryId, subjectType, subjectId, verdict, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SearchFeedbackData &&
          other.id == this.id &&
          other.queryId == this.queryId &&
          other.subjectType == this.subjectType &&
          other.subjectId == this.subjectId &&
          other.verdict == this.verdict &&
          other.createdAt == this.createdAt);
}

class SearchFeedbackCompanion extends UpdateCompanion<SearchFeedbackData> {
  final Value<int> id;
  final Value<int> queryId;
  final Value<String> subjectType;
  final Value<int> subjectId;
  final Value<String> verdict;
  final Value<DateTime> createdAt;
  const SearchFeedbackCompanion({
    this.id = const Value.absent(),
    this.queryId = const Value.absent(),
    this.subjectType = const Value.absent(),
    this.subjectId = const Value.absent(),
    this.verdict = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  SearchFeedbackCompanion.insert({
    this.id = const Value.absent(),
    required int queryId,
    required String subjectType,
    required int subjectId,
    required String verdict,
    this.createdAt = const Value.absent(),
  }) : queryId = Value(queryId),
       subjectType = Value(subjectType),
       subjectId = Value(subjectId),
       verdict = Value(verdict);
  static Insertable<SearchFeedbackData> custom({
    Expression<int>? id,
    Expression<int>? queryId,
    Expression<String>? subjectType,
    Expression<int>? subjectId,
    Expression<String>? verdict,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (queryId != null) 'query_id': queryId,
      if (subjectType != null) 'subject_type': subjectType,
      if (subjectId != null) 'subject_id': subjectId,
      if (verdict != null) 'verdict': verdict,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  SearchFeedbackCompanion copyWith({
    Value<int>? id,
    Value<int>? queryId,
    Value<String>? subjectType,
    Value<int>? subjectId,
    Value<String>? verdict,
    Value<DateTime>? createdAt,
  }) {
    return SearchFeedbackCompanion(
      id: id ?? this.id,
      queryId: queryId ?? this.queryId,
      subjectType: subjectType ?? this.subjectType,
      subjectId: subjectId ?? this.subjectId,
      verdict: verdict ?? this.verdict,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (queryId.present) {
      map['query_id'] = Variable<int>(queryId.value);
    }
    if (subjectType.present) {
      map['subject_type'] = Variable<String>(subjectType.value);
    }
    if (subjectId.present) {
      map['subject_id'] = Variable<int>(subjectId.value);
    }
    if (verdict.present) {
      map['verdict'] = Variable<String>(verdict.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SearchFeedbackCompanion(')
          ..write('id: $id, ')
          ..write('queryId: $queryId, ')
          ..write('subjectType: $subjectType, ')
          ..write('subjectId: $subjectId, ')
          ..write('verdict: $verdict, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $RankingWeightsTable extends RankingWeights
    with TableInfo<$RankingWeightsTable, RankingWeight> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RankingWeightsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<double> value = GeneratedColumn<double>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ranking_weights';
  @override
  VerificationContext validateIntegrity(
    Insertable<RankingWeight> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  RankingWeight map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RankingWeight(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $RankingWeightsTable createAlias(String alias) {
    return $RankingWeightsTable(attachedDatabase, alias);
  }
}

class RankingWeight extends DataClass implements Insertable<RankingWeight> {
  final String key;
  final double value;
  const RankingWeight({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<double>(value);
    return map;
  }

  RankingWeightsCompanion toCompanion(bool nullToAbsent) {
    return RankingWeightsCompanion(key: Value(key), value: Value(value));
  }

  factory RankingWeight.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RankingWeight(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<double>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<double>(value),
    };
  }

  RankingWeight copyWith({String? key, double? value}) =>
      RankingWeight(key: key ?? this.key, value: value ?? this.value);
  RankingWeight copyWithCompanion(RankingWeightsCompanion data) {
    return RankingWeight(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RankingWeight(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RankingWeight &&
          other.key == this.key &&
          other.value == this.value);
}

class RankingWeightsCompanion extends UpdateCompanion<RankingWeight> {
  final Value<String> key;
  final Value<double> value;
  final Value<int> rowid;
  const RankingWeightsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RankingWeightsCompanion.insert({
    required String key,
    required double value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<RankingWeight> custom({
    Expression<String>? key,
    Expression<double>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RankingWeightsCompanion copyWith({
    Value<String>? key,
    Value<double>? value,
    Value<int>? rowid,
  }) {
    return RankingWeightsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<double>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RankingWeightsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DuplicateCandidatesTable extends DuplicateCandidates
    with TableInfo<$DuplicateCandidatesTable, DuplicateCandidate> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DuplicateCandidatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _subjectTypeMeta = const VerificationMeta(
    'subjectType',
  );
  @override
  late final GeneratedColumn<String> subjectType = GeneratedColumn<String>(
    'subject_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _aIdMeta = const VerificationMeta('aId');
  @override
  late final GeneratedColumn<int> aId = GeneratedColumn<int>(
    'a_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bIdMeta = const VerificationMeta('bId');
  @override
  late final GeneratedColumn<int> bId = GeneratedColumn<int>(
    'b_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scoreMeta = const VerificationMeta('score');
  @override
  late final GeneratedColumn<double> score = GeneratedColumn<double>(
    'score',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _signalsJsonMeta = const VerificationMeta(
    'signalsJson',
  );
  @override
  late final GeneratedColumn<String> signalsJson = GeneratedColumn<String>(
    'signals_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    createdAt,
    updatedAt,
    deletedAt,
    id,
    subjectType,
    aId,
    bId,
    score,
    signalsJson,
    status,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'duplicate_candidates';
  @override
  VerificationContext validateIntegrity(
    Insertable<DuplicateCandidate> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('subject_type')) {
      context.handle(
        _subjectTypeMeta,
        subjectType.isAcceptableOrUnknown(
          data['subject_type']!,
          _subjectTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_subjectTypeMeta);
    }
    if (data.containsKey('a_id')) {
      context.handle(
        _aIdMeta,
        aId.isAcceptableOrUnknown(data['a_id']!, _aIdMeta),
      );
    } else if (isInserting) {
      context.missing(_aIdMeta);
    }
    if (data.containsKey('b_id')) {
      context.handle(
        _bIdMeta,
        bId.isAcceptableOrUnknown(data['b_id']!, _bIdMeta),
      );
    } else if (isInserting) {
      context.missing(_bIdMeta);
    }
    if (data.containsKey('score')) {
      context.handle(
        _scoreMeta,
        score.isAcceptableOrUnknown(data['score']!, _scoreMeta),
      );
    } else if (isInserting) {
      context.missing(_scoreMeta);
    }
    if (data.containsKey('signals_json')) {
      context.handle(
        _signalsJsonMeta,
        signalsJson.isAcceptableOrUnknown(
          data['signals_json']!,
          _signalsJsonMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DuplicateCandidate map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DuplicateCandidate(
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      subjectType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subject_type'],
      )!,
      aId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}a_id'],
      )!,
      bId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}b_id'],
      )!,
      score: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}score'],
      )!,
      signalsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}signals_json'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
    );
  }

  @override
  $DuplicateCandidatesTable createAlias(String alias) {
    return $DuplicateCandidatesTable(attachedDatabase, alias);
  }
}

class DuplicateCandidate extends DataClass
    implements Insertable<DuplicateCandidate> {
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final int id;
  final String subjectType;
  final int aId;
  final int bId;
  final double score;

  /// Which signals fired, so the prompt can explain itself: "same phone number,
  /// similar name".
  final String? signalsJson;

  /// `pending`, `linked`, `rejected`.
  final String status;
  const DuplicateCandidate({
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.id,
    required this.subjectType,
    required this.aId,
    required this.bId,
    required this.score,
    this.signalsJson,
    required this.status,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['id'] = Variable<int>(id);
    map['subject_type'] = Variable<String>(subjectType);
    map['a_id'] = Variable<int>(aId);
    map['b_id'] = Variable<int>(bId);
    map['score'] = Variable<double>(score);
    if (!nullToAbsent || signalsJson != null) {
      map['signals_json'] = Variable<String>(signalsJson);
    }
    map['status'] = Variable<String>(status);
    return map;
  }

  DuplicateCandidatesCompanion toCompanion(bool nullToAbsent) {
    return DuplicateCandidatesCompanion(
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      id: Value(id),
      subjectType: Value(subjectType),
      aId: Value(aId),
      bId: Value(bId),
      score: Value(score),
      signalsJson: signalsJson == null && nullToAbsent
          ? const Value.absent()
          : Value(signalsJson),
      status: Value(status),
    );
  }

  factory DuplicateCandidate.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DuplicateCandidate(
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      id: serializer.fromJson<int>(json['id']),
      subjectType: serializer.fromJson<String>(json['subjectType']),
      aId: serializer.fromJson<int>(json['aId']),
      bId: serializer.fromJson<int>(json['bId']),
      score: serializer.fromJson<double>(json['score']),
      signalsJson: serializer.fromJson<String?>(json['signalsJson']),
      status: serializer.fromJson<String>(json['status']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'id': serializer.toJson<int>(id),
      'subjectType': serializer.toJson<String>(subjectType),
      'aId': serializer.toJson<int>(aId),
      'bId': serializer.toJson<int>(bId),
      'score': serializer.toJson<double>(score),
      'signalsJson': serializer.toJson<String?>(signalsJson),
      'status': serializer.toJson<String>(status),
    };
  }

  DuplicateCandidate copyWith({
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
    int? id,
    String? subjectType,
    int? aId,
    int? bId,
    double? score,
    Value<String?> signalsJson = const Value.absent(),
    String? status,
  }) => DuplicateCandidate(
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    id: id ?? this.id,
    subjectType: subjectType ?? this.subjectType,
    aId: aId ?? this.aId,
    bId: bId ?? this.bId,
    score: score ?? this.score,
    signalsJson: signalsJson.present ? signalsJson.value : this.signalsJson,
    status: status ?? this.status,
  );
  DuplicateCandidate copyWithCompanion(DuplicateCandidatesCompanion data) {
    return DuplicateCandidate(
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      id: data.id.present ? data.id.value : this.id,
      subjectType: data.subjectType.present
          ? data.subjectType.value
          : this.subjectType,
      aId: data.aId.present ? data.aId.value : this.aId,
      bId: data.bId.present ? data.bId.value : this.bId,
      score: data.score.present ? data.score.value : this.score,
      signalsJson: data.signalsJson.present
          ? data.signalsJson.value
          : this.signalsJson,
      status: data.status.present ? data.status.value : this.status,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DuplicateCandidate(')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('id: $id, ')
          ..write('subjectType: $subjectType, ')
          ..write('aId: $aId, ')
          ..write('bId: $bId, ')
          ..write('score: $score, ')
          ..write('signalsJson: $signalsJson, ')
          ..write('status: $status')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    createdAt,
    updatedAt,
    deletedAt,
    id,
    subjectType,
    aId,
    bId,
    score,
    signalsJson,
    status,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DuplicateCandidate &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.id == this.id &&
          other.subjectType == this.subjectType &&
          other.aId == this.aId &&
          other.bId == this.bId &&
          other.score == this.score &&
          other.signalsJson == this.signalsJson &&
          other.status == this.status);
}

class DuplicateCandidatesCompanion extends UpdateCompanion<DuplicateCandidate> {
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> id;
  final Value<String> subjectType;
  final Value<int> aId;
  final Value<int> bId;
  final Value<double> score;
  final Value<String?> signalsJson;
  final Value<String> status;
  const DuplicateCandidatesCompanion({
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.id = const Value.absent(),
    this.subjectType = const Value.absent(),
    this.aId = const Value.absent(),
    this.bId = const Value.absent(),
    this.score = const Value.absent(),
    this.signalsJson = const Value.absent(),
    this.status = const Value.absent(),
  });
  DuplicateCandidatesCompanion.insert({
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.id = const Value.absent(),
    required String subjectType,
    required int aId,
    required int bId,
    required double score,
    this.signalsJson = const Value.absent(),
    this.status = const Value.absent(),
  }) : subjectType = Value(subjectType),
       aId = Value(aId),
       bId = Value(bId),
       score = Value(score);
  static Insertable<DuplicateCandidate> custom({
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? id,
    Expression<String>? subjectType,
    Expression<int>? aId,
    Expression<int>? bId,
    Expression<double>? score,
    Expression<String>? signalsJson,
    Expression<String>? status,
  }) {
    return RawValuesInsertable({
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (id != null) 'id': id,
      if (subjectType != null) 'subject_type': subjectType,
      if (aId != null) 'a_id': aId,
      if (bId != null) 'b_id': bId,
      if (score != null) 'score': score,
      if (signalsJson != null) 'signals_json': signalsJson,
      if (status != null) 'status': status,
    });
  }

  DuplicateCandidatesCompanion copyWith({
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? id,
    Value<String>? subjectType,
    Value<int>? aId,
    Value<int>? bId,
    Value<double>? score,
    Value<String?>? signalsJson,
    Value<String>? status,
  }) {
    return DuplicateCandidatesCompanion(
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      id: id ?? this.id,
      subjectType: subjectType ?? this.subjectType,
      aId: aId ?? this.aId,
      bId: bId ?? this.bId,
      score: score ?? this.score,
      signalsJson: signalsJson ?? this.signalsJson,
      status: status ?? this.status,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (subjectType.present) {
      map['subject_type'] = Variable<String>(subjectType.value);
    }
    if (aId.present) {
      map['a_id'] = Variable<int>(aId.value);
    }
    if (bId.present) {
      map['b_id'] = Variable<int>(bId.value);
    }
    if (score.present) {
      map['score'] = Variable<double>(score.value);
    }
    if (signalsJson.present) {
      map['signals_json'] = Variable<String>(signalsJson.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DuplicateCandidatesCompanion(')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('id: $id, ')
          ..write('subjectType: $subjectType, ')
          ..write('aId: $aId, ')
          ..write('bId: $bId, ')
          ..write('score: $score, ')
          ..write('signalsJson: $signalsJson, ')
          ..write('status: $status')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $PeopleTable people = $PeopleTable(this);
  late final $OrganizationsTable organizations = $OrganizationsTable(this);
  late final $OrgBranchesTable orgBranches = $OrgBranchesTable(this);
  late final $RolesTable roles = $RolesTable(this);
  late final $CardsTable cards = $CardsTable(this);
  late final $CardFieldsTable cardFields = $CardFieldsTable(this);
  late final $ContactPointsTable contactPoints = $ContactPointsTable(this);
  late final $OcrBlocksTable ocrBlocks = $OcrBlocksTable(this);
  late final $ExtractionAttemptsTable extractionAttempts =
      $ExtractionAttemptsTable(this);
  late final $NotesTable notes = $NotesTable(this);
  late final $AttributesTable attributes = $AttributesTable(this);
  late final $CapabilityProfilesTable capabilityProfiles =
      $CapabilityProfilesTable(this);
  late final $EmbeddingsTable embeddings = $EmbeddingsTable(this);
  late final $InteractionsTable interactions = $InteractionsTable(this);
  late final $TagsTable tags = $TagsTable(this);
  late final $SubjectTagsTable subjectTags = $SubjectTagsTable(this);
  late final $SearchQueriesTable searchQueries = $SearchQueriesTable(this);
  late final $SearchFeedbackTable searchFeedback = $SearchFeedbackTable(this);
  late final $RankingWeightsTable rankingWeights = $RankingWeightsTable(this);
  late final $DuplicateCandidatesTable duplicateCandidates =
      $DuplicateCandidatesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    people,
    organizations,
    orgBranches,
    roles,
    cards,
    cardFields,
    contactPoints,
    ocrBlocks,
    extractionAttempts,
    notes,
    attributes,
    capabilityProfiles,
    embeddings,
    interactions,
    tags,
    subjectTags,
    searchQueries,
    searchFeedback,
    rankingWeights,
    duplicateCandidates,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'cards',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('card_fields', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'cards',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('ocr_blocks', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'card_fields',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('ocr_blocks', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'cards',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('extraction_attempts', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'tags',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('subject_tags', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'search_queries',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('search_feedback', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$PeopleTableCreateCompanionBuilder =
    PeopleCompanion Function({
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> id,
      required String displayName,
      Value<String?> photoPath,
      Value<String?> relationship,
      Value<double> trustScore,
    });
typedef $$PeopleTableUpdateCompanionBuilder =
    PeopleCompanion Function({
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> id,
      Value<String> displayName,
      Value<String?> photoPath,
      Value<String?> relationship,
      Value<double> trustScore,
    });

final class $$PeopleTableReferences
    extends BaseReferences<_$AppDatabase, $PeopleTable, PeopleData> {
  $$PeopleTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$RolesTable, List<Role>> _rolesRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.roles,
    aliasName: 'people__id__roles__person_id',
  );

  $$RolesTableProcessedTableManager get rolesRefs {
    final manager = $$RolesTableTableManager(
      $_db,
      $_db.roles,
    ).filter((f) => f.personId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_rolesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$CardsTable, List<CardRow>> _cardsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.cards,
    aliasName: 'people__id__cards__person_id',
  );

  $$CardsTableProcessedTableManager get cardsRefs {
    final manager = $$CardsTableTableManager(
      $_db,
      $_db.cards,
    ).filter((f) => f.personId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_cardsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$PeopleTableFilterComposer
    extends Composer<_$AppDatabase, $PeopleTable> {
  $$PeopleTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get photoPath => $composableBuilder(
    column: $table.photoPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get relationship => $composableBuilder(
    column: $table.relationship,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get trustScore => $composableBuilder(
    column: $table.trustScore,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> rolesRefs(
    Expression<bool> Function($$RolesTableFilterComposer f) f,
  ) {
    final $$RolesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.roles,
      getReferencedColumn: (t) => t.personId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RolesTableFilterComposer(
            $db: $db,
            $table: $db.roles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> cardsRefs(
    Expression<bool> Function($$CardsTableFilterComposer f) f,
  ) {
    final $$CardsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.cards,
      getReferencedColumn: (t) => t.personId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CardsTableFilterComposer(
            $db: $db,
            $table: $db.cards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PeopleTableOrderingComposer
    extends Composer<_$AppDatabase, $PeopleTable> {
  $$PeopleTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get photoPath => $composableBuilder(
    column: $table.photoPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get relationship => $composableBuilder(
    column: $table.relationship,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get trustScore => $composableBuilder(
    column: $table.trustScore,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PeopleTableAnnotationComposer
    extends Composer<_$AppDatabase, $PeopleTable> {
  $$PeopleTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get photoPath =>
      $composableBuilder(column: $table.photoPath, builder: (column) => column);

  GeneratedColumn<String> get relationship => $composableBuilder(
    column: $table.relationship,
    builder: (column) => column,
  );

  GeneratedColumn<double> get trustScore => $composableBuilder(
    column: $table.trustScore,
    builder: (column) => column,
  );

  Expression<T> rolesRefs<T extends Object>(
    Expression<T> Function($$RolesTableAnnotationComposer a) f,
  ) {
    final $$RolesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.roles,
      getReferencedColumn: (t) => t.personId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RolesTableAnnotationComposer(
            $db: $db,
            $table: $db.roles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> cardsRefs<T extends Object>(
    Expression<T> Function($$CardsTableAnnotationComposer a) f,
  ) {
    final $$CardsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.cards,
      getReferencedColumn: (t) => t.personId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CardsTableAnnotationComposer(
            $db: $db,
            $table: $db.cards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PeopleTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PeopleTable,
          PeopleData,
          $$PeopleTableFilterComposer,
          $$PeopleTableOrderingComposer,
          $$PeopleTableAnnotationComposer,
          $$PeopleTableCreateCompanionBuilder,
          $$PeopleTableUpdateCompanionBuilder,
          (PeopleData, $$PeopleTableReferences),
          PeopleData,
          PrefetchHooks Function({bool rolesRefs, bool cardsRefs})
        > {
  $$PeopleTableTableManager(_$AppDatabase db, $PeopleTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PeopleTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PeopleTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PeopleTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> id = const Value.absent(),
                Value<String> displayName = const Value.absent(),
                Value<String?> photoPath = const Value.absent(),
                Value<String?> relationship = const Value.absent(),
                Value<double> trustScore = const Value.absent(),
              }) => PeopleCompanion(
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                id: id,
                displayName: displayName,
                photoPath: photoPath,
                relationship: relationship,
                trustScore: trustScore,
              ),
          createCompanionCallback:
              ({
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> id = const Value.absent(),
                required String displayName,
                Value<String?> photoPath = const Value.absent(),
                Value<String?> relationship = const Value.absent(),
                Value<double> trustScore = const Value.absent(),
              }) => PeopleCompanion.insert(
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                id: id,
                displayName: displayName,
                photoPath: photoPath,
                relationship: relationship,
                trustScore: trustScore,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$PeopleTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({rolesRefs = false, cardsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (rolesRefs) db.roles,
                if (cardsRefs) db.cards,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (rolesRefs)
                    await $_getPrefetchedData<PeopleData, $PeopleTable, Role>(
                      currentTable: table,
                      referencedTable: $$PeopleTableReferences._rolesRefsTable(
                        db,
                      ),
                      managerFromTypedResult: (p0) =>
                          $$PeopleTableReferences(db, table, p0).rolesRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.personId == item.id),
                      typedResults: items,
                    ),
                  if (cardsRefs)
                    await $_getPrefetchedData<
                      PeopleData,
                      $PeopleTable,
                      CardRow
                    >(
                      currentTable: table,
                      referencedTable: $$PeopleTableReferences._cardsRefsTable(
                        db,
                      ),
                      managerFromTypedResult: (p0) =>
                          $$PeopleTableReferences(db, table, p0).cardsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.personId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$PeopleTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PeopleTable,
      PeopleData,
      $$PeopleTableFilterComposer,
      $$PeopleTableOrderingComposer,
      $$PeopleTableAnnotationComposer,
      $$PeopleTableCreateCompanionBuilder,
      $$PeopleTableUpdateCompanionBuilder,
      (PeopleData, $$PeopleTableReferences),
      PeopleData,
      PrefetchHooks Function({bool rolesRefs, bool cardsRefs})
    >;
typedef $$OrganizationsTableCreateCompanionBuilder =
    OrganizationsCompanion Function({
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> id,
      required String name,
      Value<String?> category,
      Value<String?> website,
      Value<String?> websiteDomain,
    });
typedef $$OrganizationsTableUpdateCompanionBuilder =
    OrganizationsCompanion Function({
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> id,
      Value<String> name,
      Value<String?> category,
      Value<String?> website,
      Value<String?> websiteDomain,
    });

final class $$OrganizationsTableReferences
    extends BaseReferences<_$AppDatabase, $OrganizationsTable, Organization> {
  $$OrganizationsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$OrgBranchesTable, List<OrgBranche>>
  _orgBranchesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.orgBranches,
    aliasName: 'organizations__id__org_branches__org_id',
  );

  $$OrgBranchesTableProcessedTableManager get orgBranchesRefs {
    final manager = $$OrgBranchesTableTableManager(
      $_db,
      $_db.orgBranches,
    ).filter((f) => f.orgId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_orgBranchesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$RolesTable, List<Role>> _rolesRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.roles,
    aliasName: 'organizations__id__roles__org_id',
  );

  $$RolesTableProcessedTableManager get rolesRefs {
    final manager = $$RolesTableTableManager(
      $_db,
      $_db.roles,
    ).filter((f) => f.orgId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_rolesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$CardsTable, List<CardRow>> _cardsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.cards,
    aliasName: 'organizations__id__cards__org_id',
  );

  $$CardsTableProcessedTableManager get cardsRefs {
    final manager = $$CardsTableTableManager(
      $_db,
      $_db.cards,
    ).filter((f) => f.orgId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_cardsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$OrganizationsTableFilterComposer
    extends Composer<_$AppDatabase, $OrganizationsTable> {
  $$OrganizationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get website => $composableBuilder(
    column: $table.website,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get websiteDomain => $composableBuilder(
    column: $table.websiteDomain,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> orgBranchesRefs(
    Expression<bool> Function($$OrgBranchesTableFilterComposer f) f,
  ) {
    final $$OrgBranchesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.orgBranches,
      getReferencedColumn: (t) => t.orgId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$OrgBranchesTableFilterComposer(
            $db: $db,
            $table: $db.orgBranches,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> rolesRefs(
    Expression<bool> Function($$RolesTableFilterComposer f) f,
  ) {
    final $$RolesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.roles,
      getReferencedColumn: (t) => t.orgId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RolesTableFilterComposer(
            $db: $db,
            $table: $db.roles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> cardsRefs(
    Expression<bool> Function($$CardsTableFilterComposer f) f,
  ) {
    final $$CardsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.cards,
      getReferencedColumn: (t) => t.orgId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CardsTableFilterComposer(
            $db: $db,
            $table: $db.cards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$OrganizationsTableOrderingComposer
    extends Composer<_$AppDatabase, $OrganizationsTable> {
  $$OrganizationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get website => $composableBuilder(
    column: $table.website,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get websiteDomain => $composableBuilder(
    column: $table.websiteDomain,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OrganizationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $OrganizationsTable> {
  $$OrganizationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<String> get website =>
      $composableBuilder(column: $table.website, builder: (column) => column);

  GeneratedColumn<String> get websiteDomain => $composableBuilder(
    column: $table.websiteDomain,
    builder: (column) => column,
  );

  Expression<T> orgBranchesRefs<T extends Object>(
    Expression<T> Function($$OrgBranchesTableAnnotationComposer a) f,
  ) {
    final $$OrgBranchesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.orgBranches,
      getReferencedColumn: (t) => t.orgId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$OrgBranchesTableAnnotationComposer(
            $db: $db,
            $table: $db.orgBranches,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> rolesRefs<T extends Object>(
    Expression<T> Function($$RolesTableAnnotationComposer a) f,
  ) {
    final $$RolesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.roles,
      getReferencedColumn: (t) => t.orgId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RolesTableAnnotationComposer(
            $db: $db,
            $table: $db.roles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> cardsRefs<T extends Object>(
    Expression<T> Function($$CardsTableAnnotationComposer a) f,
  ) {
    final $$CardsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.cards,
      getReferencedColumn: (t) => t.orgId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CardsTableAnnotationComposer(
            $db: $db,
            $table: $db.cards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$OrganizationsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OrganizationsTable,
          Organization,
          $$OrganizationsTableFilterComposer,
          $$OrganizationsTableOrderingComposer,
          $$OrganizationsTableAnnotationComposer,
          $$OrganizationsTableCreateCompanionBuilder,
          $$OrganizationsTableUpdateCompanionBuilder,
          (Organization, $$OrganizationsTableReferences),
          Organization,
          PrefetchHooks Function({
            bool orgBranchesRefs,
            bool rolesRefs,
            bool cardsRefs,
          })
        > {
  $$OrganizationsTableTableManager(_$AppDatabase db, $OrganizationsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OrganizationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OrganizationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OrganizationsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> category = const Value.absent(),
                Value<String?> website = const Value.absent(),
                Value<String?> websiteDomain = const Value.absent(),
              }) => OrganizationsCompanion(
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                id: id,
                name: name,
                category: category,
                website: website,
                websiteDomain: websiteDomain,
              ),
          createCompanionCallback:
              ({
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> id = const Value.absent(),
                required String name,
                Value<String?> category = const Value.absent(),
                Value<String?> website = const Value.absent(),
                Value<String?> websiteDomain = const Value.absent(),
              }) => OrganizationsCompanion.insert(
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                id: id,
                name: name,
                category: category,
                website: website,
                websiteDomain: websiteDomain,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$OrganizationsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                orgBranchesRefs = false,
                rolesRefs = false,
                cardsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (orgBranchesRefs) db.orgBranches,
                    if (rolesRefs) db.roles,
                    if (cardsRefs) db.cards,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (orgBranchesRefs)
                        await $_getPrefetchedData<
                          Organization,
                          $OrganizationsTable,
                          OrgBranche
                        >(
                          currentTable: table,
                          referencedTable: $$OrganizationsTableReferences
                              ._orgBranchesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$OrganizationsTableReferences(
                                db,
                                table,
                                p0,
                              ).orgBranchesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.orgId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (rolesRefs)
                        await $_getPrefetchedData<
                          Organization,
                          $OrganizationsTable,
                          Role
                        >(
                          currentTable: table,
                          referencedTable: $$OrganizationsTableReferences
                              ._rolesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$OrganizationsTableReferences(
                                db,
                                table,
                                p0,
                              ).rolesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.orgId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (cardsRefs)
                        await $_getPrefetchedData<
                          Organization,
                          $OrganizationsTable,
                          CardRow
                        >(
                          currentTable: table,
                          referencedTable: $$OrganizationsTableReferences
                              ._cardsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$OrganizationsTableReferences(
                                db,
                                table,
                                p0,
                              ).cardsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.orgId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$OrganizationsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OrganizationsTable,
      Organization,
      $$OrganizationsTableFilterComposer,
      $$OrganizationsTableOrderingComposer,
      $$OrganizationsTableAnnotationComposer,
      $$OrganizationsTableCreateCompanionBuilder,
      $$OrganizationsTableUpdateCompanionBuilder,
      (Organization, $$OrganizationsTableReferences),
      Organization,
      PrefetchHooks Function({
        bool orgBranchesRefs,
        bool rolesRefs,
        bool cardsRefs,
      })
    >;
typedef $$OrgBranchesTableCreateCompanionBuilder =
    OrgBranchesCompanion Function({
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> id,
      required int orgId,
      Value<String?> address,
      Value<double?> lat,
      Value<double?> lng,
      Value<String?> phone,
      Value<bool> isPrimary,
    });
typedef $$OrgBranchesTableUpdateCompanionBuilder =
    OrgBranchesCompanion Function({
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> id,
      Value<int> orgId,
      Value<String?> address,
      Value<double?> lat,
      Value<double?> lng,
      Value<String?> phone,
      Value<bool> isPrimary,
    });

final class $$OrgBranchesTableReferences
    extends BaseReferences<_$AppDatabase, $OrgBranchesTable, OrgBranche> {
  $$OrgBranchesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $OrganizationsTable _orgIdTable(_$AppDatabase db) =>
      db.organizations.createAlias('org_branches__org_id__organizations__id');

  $$OrganizationsTableProcessedTableManager get orgId {
    final $_column = $_itemColumn<int>('org_id')!;

    final manager = $$OrganizationsTableTableManager(
      $_db,
      $_db.organizations,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_orgIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$OrgBranchesTableFilterComposer
    extends Composer<_$AppDatabase, $OrgBranchesTable> {
  $$OrgBranchesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get address => $composableBuilder(
    column: $table.address,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get lat => $composableBuilder(
    column: $table.lat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get lng => $composableBuilder(
    column: $table.lng,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isPrimary => $composableBuilder(
    column: $table.isPrimary,
    builder: (column) => ColumnFilters(column),
  );

  $$OrganizationsTableFilterComposer get orgId {
    final $$OrganizationsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.orgId,
      referencedTable: $db.organizations,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$OrganizationsTableFilterComposer(
            $db: $db,
            $table: $db.organizations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$OrgBranchesTableOrderingComposer
    extends Composer<_$AppDatabase, $OrgBranchesTable> {
  $$OrgBranchesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get address => $composableBuilder(
    column: $table.address,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get lat => $composableBuilder(
    column: $table.lat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get lng => $composableBuilder(
    column: $table.lng,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isPrimary => $composableBuilder(
    column: $table.isPrimary,
    builder: (column) => ColumnOrderings(column),
  );

  $$OrganizationsTableOrderingComposer get orgId {
    final $$OrganizationsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.orgId,
      referencedTable: $db.organizations,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$OrganizationsTableOrderingComposer(
            $db: $db,
            $table: $db.organizations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$OrgBranchesTableAnnotationComposer
    extends Composer<_$AppDatabase, $OrgBranchesTable> {
  $$OrgBranchesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get address =>
      $composableBuilder(column: $table.address, builder: (column) => column);

  GeneratedColumn<double> get lat =>
      $composableBuilder(column: $table.lat, builder: (column) => column);

  GeneratedColumn<double> get lng =>
      $composableBuilder(column: $table.lng, builder: (column) => column);

  GeneratedColumn<String> get phone =>
      $composableBuilder(column: $table.phone, builder: (column) => column);

  GeneratedColumn<bool> get isPrimary =>
      $composableBuilder(column: $table.isPrimary, builder: (column) => column);

  $$OrganizationsTableAnnotationComposer get orgId {
    final $$OrganizationsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.orgId,
      referencedTable: $db.organizations,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$OrganizationsTableAnnotationComposer(
            $db: $db,
            $table: $db.organizations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$OrgBranchesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OrgBranchesTable,
          OrgBranche,
          $$OrgBranchesTableFilterComposer,
          $$OrgBranchesTableOrderingComposer,
          $$OrgBranchesTableAnnotationComposer,
          $$OrgBranchesTableCreateCompanionBuilder,
          $$OrgBranchesTableUpdateCompanionBuilder,
          (OrgBranche, $$OrgBranchesTableReferences),
          OrgBranche,
          PrefetchHooks Function({bool orgId})
        > {
  $$OrgBranchesTableTableManager(_$AppDatabase db, $OrgBranchesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OrgBranchesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OrgBranchesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OrgBranchesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> id = const Value.absent(),
                Value<int> orgId = const Value.absent(),
                Value<String?> address = const Value.absent(),
                Value<double?> lat = const Value.absent(),
                Value<double?> lng = const Value.absent(),
                Value<String?> phone = const Value.absent(),
                Value<bool> isPrimary = const Value.absent(),
              }) => OrgBranchesCompanion(
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                id: id,
                orgId: orgId,
                address: address,
                lat: lat,
                lng: lng,
                phone: phone,
                isPrimary: isPrimary,
              ),
          createCompanionCallback:
              ({
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> id = const Value.absent(),
                required int orgId,
                Value<String?> address = const Value.absent(),
                Value<double?> lat = const Value.absent(),
                Value<double?> lng = const Value.absent(),
                Value<String?> phone = const Value.absent(),
                Value<bool> isPrimary = const Value.absent(),
              }) => OrgBranchesCompanion.insert(
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                id: id,
                orgId: orgId,
                address: address,
                lat: lat,
                lng: lng,
                phone: phone,
                isPrimary: isPrimary,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$OrgBranchesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({orgId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (orgId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.orgId,
                                referencedTable: $$OrgBranchesTableReferences
                                    ._orgIdTable(db),
                                referencedColumn: $$OrgBranchesTableReferences
                                    ._orgIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$OrgBranchesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OrgBranchesTable,
      OrgBranche,
      $$OrgBranchesTableFilterComposer,
      $$OrgBranchesTableOrderingComposer,
      $$OrgBranchesTableAnnotationComposer,
      $$OrgBranchesTableCreateCompanionBuilder,
      $$OrgBranchesTableUpdateCompanionBuilder,
      (OrgBranche, $$OrgBranchesTableReferences),
      OrgBranche,
      PrefetchHooks Function({bool orgId})
    >;
typedef $$RolesTableCreateCompanionBuilder =
    RolesCompanion Function({
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> id,
      required int personId,
      required int orgId,
      Value<String?> title,
      Value<bool> isCurrent,
      Value<DateTime?> startDate,
      Value<DateTime?> endDate,
    });
typedef $$RolesTableUpdateCompanionBuilder =
    RolesCompanion Function({
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> id,
      Value<int> personId,
      Value<int> orgId,
      Value<String?> title,
      Value<bool> isCurrent,
      Value<DateTime?> startDate,
      Value<DateTime?> endDate,
    });

final class $$RolesTableReferences
    extends BaseReferences<_$AppDatabase, $RolesTable, Role> {
  $$RolesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $PeopleTable _personIdTable(_$AppDatabase db) =>
      db.people.createAlias('roles__person_id__people__id');

  $$PeopleTableProcessedTableManager get personId {
    final $_column = $_itemColumn<int>('person_id')!;

    final manager = $$PeopleTableTableManager(
      $_db,
      $_db.people,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_personIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $OrganizationsTable _orgIdTable(_$AppDatabase db) =>
      db.organizations.createAlias('roles__org_id__organizations__id');

  $$OrganizationsTableProcessedTableManager get orgId {
    final $_column = $_itemColumn<int>('org_id')!;

    final manager = $$OrganizationsTableTableManager(
      $_db,
      $_db.organizations,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_orgIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$CardsTable, List<CardRow>> _cardsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.cards,
    aliasName: 'roles__id__cards__role_id',
  );

  $$CardsTableProcessedTableManager get cardsRefs {
    final manager = $$CardsTableTableManager(
      $_db,
      $_db.cards,
    ).filter((f) => f.roleId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_cardsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ContactPointsTable, List<ContactPoint>>
  _contactPointsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.contactPoints,
    aliasName: 'roles__id__contact_points__role_id',
  );

  $$ContactPointsTableProcessedTableManager get contactPointsRefs {
    final manager = $$ContactPointsTableTableManager(
      $_db,
      $_db.contactPoints,
    ).filter((f) => f.roleId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_contactPointsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$RolesTableFilterComposer extends Composer<_$AppDatabase, $RolesTable> {
  $$RolesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isCurrent => $composableBuilder(
    column: $table.isCurrent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get endDate => $composableBuilder(
    column: $table.endDate,
    builder: (column) => ColumnFilters(column),
  );

  $$PeopleTableFilterComposer get personId {
    final $$PeopleTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.personId,
      referencedTable: $db.people,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PeopleTableFilterComposer(
            $db: $db,
            $table: $db.people,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$OrganizationsTableFilterComposer get orgId {
    final $$OrganizationsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.orgId,
      referencedTable: $db.organizations,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$OrganizationsTableFilterComposer(
            $db: $db,
            $table: $db.organizations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> cardsRefs(
    Expression<bool> Function($$CardsTableFilterComposer f) f,
  ) {
    final $$CardsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.cards,
      getReferencedColumn: (t) => t.roleId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CardsTableFilterComposer(
            $db: $db,
            $table: $db.cards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> contactPointsRefs(
    Expression<bool> Function($$ContactPointsTableFilterComposer f) f,
  ) {
    final $$ContactPointsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.contactPoints,
      getReferencedColumn: (t) => t.roleId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ContactPointsTableFilterComposer(
            $db: $db,
            $table: $db.contactPoints,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$RolesTableOrderingComposer
    extends Composer<_$AppDatabase, $RolesTable> {
  $$RolesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isCurrent => $composableBuilder(
    column: $table.isCurrent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get endDate => $composableBuilder(
    column: $table.endDate,
    builder: (column) => ColumnOrderings(column),
  );

  $$PeopleTableOrderingComposer get personId {
    final $$PeopleTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.personId,
      referencedTable: $db.people,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PeopleTableOrderingComposer(
            $db: $db,
            $table: $db.people,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$OrganizationsTableOrderingComposer get orgId {
    final $$OrganizationsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.orgId,
      referencedTable: $db.organizations,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$OrganizationsTableOrderingComposer(
            $db: $db,
            $table: $db.organizations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RolesTableAnnotationComposer
    extends Composer<_$AppDatabase, $RolesTable> {
  $$RolesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<bool> get isCurrent =>
      $composableBuilder(column: $table.isCurrent, builder: (column) => column);

  GeneratedColumn<DateTime> get startDate =>
      $composableBuilder(column: $table.startDate, builder: (column) => column);

  GeneratedColumn<DateTime> get endDate =>
      $composableBuilder(column: $table.endDate, builder: (column) => column);

  $$PeopleTableAnnotationComposer get personId {
    final $$PeopleTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.personId,
      referencedTable: $db.people,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PeopleTableAnnotationComposer(
            $db: $db,
            $table: $db.people,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$OrganizationsTableAnnotationComposer get orgId {
    final $$OrganizationsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.orgId,
      referencedTable: $db.organizations,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$OrganizationsTableAnnotationComposer(
            $db: $db,
            $table: $db.organizations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> cardsRefs<T extends Object>(
    Expression<T> Function($$CardsTableAnnotationComposer a) f,
  ) {
    final $$CardsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.cards,
      getReferencedColumn: (t) => t.roleId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CardsTableAnnotationComposer(
            $db: $db,
            $table: $db.cards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> contactPointsRefs<T extends Object>(
    Expression<T> Function($$ContactPointsTableAnnotationComposer a) f,
  ) {
    final $$ContactPointsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.contactPoints,
      getReferencedColumn: (t) => t.roleId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ContactPointsTableAnnotationComposer(
            $db: $db,
            $table: $db.contactPoints,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$RolesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RolesTable,
          Role,
          $$RolesTableFilterComposer,
          $$RolesTableOrderingComposer,
          $$RolesTableAnnotationComposer,
          $$RolesTableCreateCompanionBuilder,
          $$RolesTableUpdateCompanionBuilder,
          (Role, $$RolesTableReferences),
          Role,
          PrefetchHooks Function({
            bool personId,
            bool orgId,
            bool cardsRefs,
            bool contactPointsRefs,
          })
        > {
  $$RolesTableTableManager(_$AppDatabase db, $RolesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RolesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RolesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RolesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> id = const Value.absent(),
                Value<int> personId = const Value.absent(),
                Value<int> orgId = const Value.absent(),
                Value<String?> title = const Value.absent(),
                Value<bool> isCurrent = const Value.absent(),
                Value<DateTime?> startDate = const Value.absent(),
                Value<DateTime?> endDate = const Value.absent(),
              }) => RolesCompanion(
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                id: id,
                personId: personId,
                orgId: orgId,
                title: title,
                isCurrent: isCurrent,
                startDate: startDate,
                endDate: endDate,
              ),
          createCompanionCallback:
              ({
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> id = const Value.absent(),
                required int personId,
                required int orgId,
                Value<String?> title = const Value.absent(),
                Value<bool> isCurrent = const Value.absent(),
                Value<DateTime?> startDate = const Value.absent(),
                Value<DateTime?> endDate = const Value.absent(),
              }) => RolesCompanion.insert(
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                id: id,
                personId: personId,
                orgId: orgId,
                title: title,
                isCurrent: isCurrent,
                startDate: startDate,
                endDate: endDate,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$RolesTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                personId = false,
                orgId = false,
                cardsRefs = false,
                contactPointsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (cardsRefs) db.cards,
                    if (contactPointsRefs) db.contactPoints,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (personId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.personId,
                                    referencedTable: $$RolesTableReferences
                                        ._personIdTable(db),
                                    referencedColumn: $$RolesTableReferences
                                        ._personIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }
                        if (orgId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.orgId,
                                    referencedTable: $$RolesTableReferences
                                        ._orgIdTable(db),
                                    referencedColumn: $$RolesTableReferences
                                        ._orgIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (cardsRefs)
                        await $_getPrefetchedData<Role, $RolesTable, CardRow>(
                          currentTable: table,
                          referencedTable: $$RolesTableReferences
                              ._cardsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$RolesTableReferences(db, table, p0).cardsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.roleId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (contactPointsRefs)
                        await $_getPrefetchedData<
                          Role,
                          $RolesTable,
                          ContactPoint
                        >(
                          currentTable: table,
                          referencedTable: $$RolesTableReferences
                              ._contactPointsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$RolesTableReferences(
                                db,
                                table,
                                p0,
                              ).contactPointsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.roleId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$RolesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RolesTable,
      Role,
      $$RolesTableFilterComposer,
      $$RolesTableOrderingComposer,
      $$RolesTableAnnotationComposer,
      $$RolesTableCreateCompanionBuilder,
      $$RolesTableUpdateCompanionBuilder,
      (Role, $$RolesTableReferences),
      Role,
      PrefetchHooks Function({
        bool personId,
        bool orgId,
        bool cardsRefs,
        bool contactPointsRefs,
      })
    >;
typedef $$CardsTableCreateCompanionBuilder =
    CardsCompanion Function({
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> id,
      Value<CardType> type,
      required String imagePath,
      Value<String?> backImagePath,
      Value<String?> thumbPath,
      Value<String?> rawOcrText,
      Value<String?> ocrEngine,
      Value<double?> ocrConfidence,
      Value<ExtractionStatus> extractionStatus,
      required DateTime capturedAt,
      Value<int?> personId,
      Value<int?> orgId,
      Value<int?> roleId,
    });
typedef $$CardsTableUpdateCompanionBuilder =
    CardsCompanion Function({
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> id,
      Value<CardType> type,
      Value<String> imagePath,
      Value<String?> backImagePath,
      Value<String?> thumbPath,
      Value<String?> rawOcrText,
      Value<String?> ocrEngine,
      Value<double?> ocrConfidence,
      Value<ExtractionStatus> extractionStatus,
      Value<DateTime> capturedAt,
      Value<int?> personId,
      Value<int?> orgId,
      Value<int?> roleId,
    });

final class $$CardsTableReferences
    extends BaseReferences<_$AppDatabase, $CardsTable, CardRow> {
  $$CardsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $PeopleTable _personIdTable(_$AppDatabase db) =>
      db.people.createAlias('cards__person_id__people__id');

  $$PeopleTableProcessedTableManager? get personId {
    final $_column = $_itemColumn<int>('person_id');
    if ($_column == null) return null;
    final manager = $$PeopleTableTableManager(
      $_db,
      $_db.people,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_personIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $OrganizationsTable _orgIdTable(_$AppDatabase db) =>
      db.organizations.createAlias('cards__org_id__organizations__id');

  $$OrganizationsTableProcessedTableManager? get orgId {
    final $_column = $_itemColumn<int>('org_id');
    if ($_column == null) return null;
    final manager = $$OrganizationsTableTableManager(
      $_db,
      $_db.organizations,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_orgIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $RolesTable _roleIdTable(_$AppDatabase db) =>
      db.roles.createAlias('cards__role_id__roles__id');

  $$RolesTableProcessedTableManager? get roleId {
    final $_column = $_itemColumn<int>('role_id');
    if ($_column == null) return null;
    final manager = $$RolesTableTableManager(
      $_db,
      $_db.roles,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_roleIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$CardFieldsTable, List<CardField>>
  _cardFieldsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.cardFields,
    aliasName: 'cards__id__card_fields__card_id',
  );

  $$CardFieldsTableProcessedTableManager get cardFieldsRefs {
    final manager = $$CardFieldsTableTableManager(
      $_db,
      $_db.cardFields,
    ).filter((f) => f.cardId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_cardFieldsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$OcrBlocksTable, List<OcrBlockRow>>
  _ocrBlocksRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.ocrBlocks,
    aliasName: 'cards__id__ocr_blocks__card_id',
  );

  $$OcrBlocksTableProcessedTableManager get ocrBlocksRefs {
    final manager = $$OcrBlocksTableTableManager(
      $_db,
      $_db.ocrBlocks,
    ).filter((f) => f.cardId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_ocrBlocksRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ExtractionAttemptsTable, List<ExtractionAttempt>>
  _extractionAttemptsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.extractionAttempts,
        aliasName: 'cards__id__extraction_attempts__card_id',
      );

  $$ExtractionAttemptsTableProcessedTableManager get extractionAttemptsRefs {
    final manager = $$ExtractionAttemptsTableTableManager(
      $_db,
      $_db.extractionAttempts,
    ).filter((f) => f.cardId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _extractionAttemptsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$CardsTableFilterComposer extends Composer<_$AppDatabase, $CardsTable> {
  $$CardsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<CardType, CardType, String> get type =>
      $composableBuilder(
        column: $table.type,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get imagePath => $composableBuilder(
    column: $table.imagePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get backImagePath => $composableBuilder(
    column: $table.backImagePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get thumbPath => $composableBuilder(
    column: $table.thumbPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rawOcrText => $composableBuilder(
    column: $table.rawOcrText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ocrEngine => $composableBuilder(
    column: $table.ocrEngine,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get ocrConfidence => $composableBuilder(
    column: $table.ocrConfidence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<ExtractionStatus, ExtractionStatus, String>
  get extractionStatus => $composableBuilder(
    column: $table.extractionStatus,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<DateTime> get capturedAt => $composableBuilder(
    column: $table.capturedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$PeopleTableFilterComposer get personId {
    final $$PeopleTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.personId,
      referencedTable: $db.people,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PeopleTableFilterComposer(
            $db: $db,
            $table: $db.people,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$OrganizationsTableFilterComposer get orgId {
    final $$OrganizationsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.orgId,
      referencedTable: $db.organizations,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$OrganizationsTableFilterComposer(
            $db: $db,
            $table: $db.organizations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$RolesTableFilterComposer get roleId {
    final $$RolesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.roleId,
      referencedTable: $db.roles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RolesTableFilterComposer(
            $db: $db,
            $table: $db.roles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> cardFieldsRefs(
    Expression<bool> Function($$CardFieldsTableFilterComposer f) f,
  ) {
    final $$CardFieldsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.cardFields,
      getReferencedColumn: (t) => t.cardId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CardFieldsTableFilterComposer(
            $db: $db,
            $table: $db.cardFields,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> ocrBlocksRefs(
    Expression<bool> Function($$OcrBlocksTableFilterComposer f) f,
  ) {
    final $$OcrBlocksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.ocrBlocks,
      getReferencedColumn: (t) => t.cardId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$OcrBlocksTableFilterComposer(
            $db: $db,
            $table: $db.ocrBlocks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> extractionAttemptsRefs(
    Expression<bool> Function($$ExtractionAttemptsTableFilterComposer f) f,
  ) {
    final $$ExtractionAttemptsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.extractionAttempts,
      getReferencedColumn: (t) => t.cardId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ExtractionAttemptsTableFilterComposer(
            $db: $db,
            $table: $db.extractionAttempts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CardsTableOrderingComposer
    extends Composer<_$AppDatabase, $CardsTable> {
  $$CardsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imagePath => $composableBuilder(
    column: $table.imagePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get backImagePath => $composableBuilder(
    column: $table.backImagePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get thumbPath => $composableBuilder(
    column: $table.thumbPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rawOcrText => $composableBuilder(
    column: $table.rawOcrText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ocrEngine => $composableBuilder(
    column: $table.ocrEngine,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get ocrConfidence => $composableBuilder(
    column: $table.ocrConfidence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get extractionStatus => $composableBuilder(
    column: $table.extractionStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get capturedAt => $composableBuilder(
    column: $table.capturedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$PeopleTableOrderingComposer get personId {
    final $$PeopleTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.personId,
      referencedTable: $db.people,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PeopleTableOrderingComposer(
            $db: $db,
            $table: $db.people,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$OrganizationsTableOrderingComposer get orgId {
    final $$OrganizationsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.orgId,
      referencedTable: $db.organizations,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$OrganizationsTableOrderingComposer(
            $db: $db,
            $table: $db.organizations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$RolesTableOrderingComposer get roleId {
    final $$RolesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.roleId,
      referencedTable: $db.roles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RolesTableOrderingComposer(
            $db: $db,
            $table: $db.roles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CardsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CardsTable> {
  $$CardsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<CardType, String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get imagePath =>
      $composableBuilder(column: $table.imagePath, builder: (column) => column);

  GeneratedColumn<String> get backImagePath => $composableBuilder(
    column: $table.backImagePath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get thumbPath =>
      $composableBuilder(column: $table.thumbPath, builder: (column) => column);

  GeneratedColumn<String> get rawOcrText => $composableBuilder(
    column: $table.rawOcrText,
    builder: (column) => column,
  );

  GeneratedColumn<String> get ocrEngine =>
      $composableBuilder(column: $table.ocrEngine, builder: (column) => column);

  GeneratedColumn<double> get ocrConfidence => $composableBuilder(
    column: $table.ocrConfidence,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<ExtractionStatus, String>
  get extractionStatus => $composableBuilder(
    column: $table.extractionStatus,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get capturedAt => $composableBuilder(
    column: $table.capturedAt,
    builder: (column) => column,
  );

  $$PeopleTableAnnotationComposer get personId {
    final $$PeopleTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.personId,
      referencedTable: $db.people,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PeopleTableAnnotationComposer(
            $db: $db,
            $table: $db.people,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$OrganizationsTableAnnotationComposer get orgId {
    final $$OrganizationsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.orgId,
      referencedTable: $db.organizations,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$OrganizationsTableAnnotationComposer(
            $db: $db,
            $table: $db.organizations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$RolesTableAnnotationComposer get roleId {
    final $$RolesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.roleId,
      referencedTable: $db.roles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RolesTableAnnotationComposer(
            $db: $db,
            $table: $db.roles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> cardFieldsRefs<T extends Object>(
    Expression<T> Function($$CardFieldsTableAnnotationComposer a) f,
  ) {
    final $$CardFieldsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.cardFields,
      getReferencedColumn: (t) => t.cardId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CardFieldsTableAnnotationComposer(
            $db: $db,
            $table: $db.cardFields,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> ocrBlocksRefs<T extends Object>(
    Expression<T> Function($$OcrBlocksTableAnnotationComposer a) f,
  ) {
    final $$OcrBlocksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.ocrBlocks,
      getReferencedColumn: (t) => t.cardId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$OcrBlocksTableAnnotationComposer(
            $db: $db,
            $table: $db.ocrBlocks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> extractionAttemptsRefs<T extends Object>(
    Expression<T> Function($$ExtractionAttemptsTableAnnotationComposer a) f,
  ) {
    final $$ExtractionAttemptsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.extractionAttempts,
          getReferencedColumn: (t) => t.cardId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ExtractionAttemptsTableAnnotationComposer(
                $db: $db,
                $table: $db.extractionAttempts,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$CardsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CardsTable,
          CardRow,
          $$CardsTableFilterComposer,
          $$CardsTableOrderingComposer,
          $$CardsTableAnnotationComposer,
          $$CardsTableCreateCompanionBuilder,
          $$CardsTableUpdateCompanionBuilder,
          (CardRow, $$CardsTableReferences),
          CardRow,
          PrefetchHooks Function({
            bool personId,
            bool orgId,
            bool roleId,
            bool cardFieldsRefs,
            bool ocrBlocksRefs,
            bool extractionAttemptsRefs,
          })
        > {
  $$CardsTableTableManager(_$AppDatabase db, $CardsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CardsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CardsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CardsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> id = const Value.absent(),
                Value<CardType> type = const Value.absent(),
                Value<String> imagePath = const Value.absent(),
                Value<String?> backImagePath = const Value.absent(),
                Value<String?> thumbPath = const Value.absent(),
                Value<String?> rawOcrText = const Value.absent(),
                Value<String?> ocrEngine = const Value.absent(),
                Value<double?> ocrConfidence = const Value.absent(),
                Value<ExtractionStatus> extractionStatus = const Value.absent(),
                Value<DateTime> capturedAt = const Value.absent(),
                Value<int?> personId = const Value.absent(),
                Value<int?> orgId = const Value.absent(),
                Value<int?> roleId = const Value.absent(),
              }) => CardsCompanion(
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                id: id,
                type: type,
                imagePath: imagePath,
                backImagePath: backImagePath,
                thumbPath: thumbPath,
                rawOcrText: rawOcrText,
                ocrEngine: ocrEngine,
                ocrConfidence: ocrConfidence,
                extractionStatus: extractionStatus,
                capturedAt: capturedAt,
                personId: personId,
                orgId: orgId,
                roleId: roleId,
              ),
          createCompanionCallback:
              ({
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> id = const Value.absent(),
                Value<CardType> type = const Value.absent(),
                required String imagePath,
                Value<String?> backImagePath = const Value.absent(),
                Value<String?> thumbPath = const Value.absent(),
                Value<String?> rawOcrText = const Value.absent(),
                Value<String?> ocrEngine = const Value.absent(),
                Value<double?> ocrConfidence = const Value.absent(),
                Value<ExtractionStatus> extractionStatus = const Value.absent(),
                required DateTime capturedAt,
                Value<int?> personId = const Value.absent(),
                Value<int?> orgId = const Value.absent(),
                Value<int?> roleId = const Value.absent(),
              }) => CardsCompanion.insert(
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                id: id,
                type: type,
                imagePath: imagePath,
                backImagePath: backImagePath,
                thumbPath: thumbPath,
                rawOcrText: rawOcrText,
                ocrEngine: ocrEngine,
                ocrConfidence: ocrConfidence,
                extractionStatus: extractionStatus,
                capturedAt: capturedAt,
                personId: personId,
                orgId: orgId,
                roleId: roleId,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$CardsTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                personId = false,
                orgId = false,
                roleId = false,
                cardFieldsRefs = false,
                ocrBlocksRefs = false,
                extractionAttemptsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (cardFieldsRefs) db.cardFields,
                    if (ocrBlocksRefs) db.ocrBlocks,
                    if (extractionAttemptsRefs) db.extractionAttempts,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (personId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.personId,
                                    referencedTable: $$CardsTableReferences
                                        ._personIdTable(db),
                                    referencedColumn: $$CardsTableReferences
                                        ._personIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }
                        if (orgId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.orgId,
                                    referencedTable: $$CardsTableReferences
                                        ._orgIdTable(db),
                                    referencedColumn: $$CardsTableReferences
                                        ._orgIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }
                        if (roleId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.roleId,
                                    referencedTable: $$CardsTableReferences
                                        ._roleIdTable(db),
                                    referencedColumn: $$CardsTableReferences
                                        ._roleIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (cardFieldsRefs)
                        await $_getPrefetchedData<
                          CardRow,
                          $CardsTable,
                          CardField
                        >(
                          currentTable: table,
                          referencedTable: $$CardsTableReferences
                              ._cardFieldsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CardsTableReferences(
                                db,
                                table,
                                p0,
                              ).cardFieldsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.cardId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (ocrBlocksRefs)
                        await $_getPrefetchedData<
                          CardRow,
                          $CardsTable,
                          OcrBlockRow
                        >(
                          currentTable: table,
                          referencedTable: $$CardsTableReferences
                              ._ocrBlocksRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CardsTableReferences(
                                db,
                                table,
                                p0,
                              ).ocrBlocksRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.cardId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (extractionAttemptsRefs)
                        await $_getPrefetchedData<
                          CardRow,
                          $CardsTable,
                          ExtractionAttempt
                        >(
                          currentTable: table,
                          referencedTable: $$CardsTableReferences
                              ._extractionAttemptsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CardsTableReferences(
                                db,
                                table,
                                p0,
                              ).extractionAttemptsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.cardId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$CardsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CardsTable,
      CardRow,
      $$CardsTableFilterComposer,
      $$CardsTableOrderingComposer,
      $$CardsTableAnnotationComposer,
      $$CardsTableCreateCompanionBuilder,
      $$CardsTableUpdateCompanionBuilder,
      (CardRow, $$CardsTableReferences),
      CardRow,
      PrefetchHooks Function({
        bool personId,
        bool orgId,
        bool roleId,
        bool cardFieldsRefs,
        bool ocrBlocksRefs,
        bool extractionAttemptsRefs,
      })
    >;
typedef $$CardFieldsTableCreateCompanionBuilder =
    CardFieldsCompanion Function({
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> id,
      required int cardId,
      required String fieldKey,
      required String value,
      Value<String?> normalizedValue,
      required FactSource source,
      Value<double?> confidence,
      Value<bool> verifiedByUser,
      Value<String?> validationIssue,
      Value<FieldValueKind> valueKind,
      Value<String?> regionRect,
    });
typedef $$CardFieldsTableUpdateCompanionBuilder =
    CardFieldsCompanion Function({
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> id,
      Value<int> cardId,
      Value<String> fieldKey,
      Value<String> value,
      Value<String?> normalizedValue,
      Value<FactSource> source,
      Value<double?> confidence,
      Value<bool> verifiedByUser,
      Value<String?> validationIssue,
      Value<FieldValueKind> valueKind,
      Value<String?> regionRect,
    });

final class $$CardFieldsTableReferences
    extends BaseReferences<_$AppDatabase, $CardFieldsTable, CardField> {
  $$CardFieldsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $CardsTable _cardIdTable(_$AppDatabase db) =>
      db.cards.createAlias('card_fields__card_id__cards__id');

  $$CardsTableProcessedTableManager get cardId {
    final $_column = $_itemColumn<int>('card_id')!;

    final manager = $$CardsTableTableManager(
      $_db,
      $_db.cards,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_cardIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$OcrBlocksTable, List<OcrBlockRow>>
  _ocrBlocksRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.ocrBlocks,
    aliasName: 'card_fields__id__ocr_blocks__field_id',
  );

  $$OcrBlocksTableProcessedTableManager get ocrBlocksRefs {
    final manager = $$OcrBlocksTableTableManager(
      $_db,
      $_db.ocrBlocks,
    ).filter((f) => f.fieldId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_ocrBlocksRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$CardFieldsTableFilterComposer
    extends Composer<_$AppDatabase, $CardFieldsTable> {
  $$CardFieldsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fieldKey => $composableBuilder(
    column: $table.fieldKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get normalizedValue => $composableBuilder(
    column: $table.normalizedValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<FactSource, FactSource, String> get source =>
      $composableBuilder(
        column: $table.source,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<double> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get verifiedByUser => $composableBuilder(
    column: $table.verifiedByUser,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get validationIssue => $composableBuilder(
    column: $table.validationIssue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<FieldValueKind, FieldValueKind, String>
  get valueKind => $composableBuilder(
    column: $table.valueKind,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get regionRect => $composableBuilder(
    column: $table.regionRect,
    builder: (column) => ColumnFilters(column),
  );

  $$CardsTableFilterComposer get cardId {
    final $$CardsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cardId,
      referencedTable: $db.cards,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CardsTableFilterComposer(
            $db: $db,
            $table: $db.cards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> ocrBlocksRefs(
    Expression<bool> Function($$OcrBlocksTableFilterComposer f) f,
  ) {
    final $$OcrBlocksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.ocrBlocks,
      getReferencedColumn: (t) => t.fieldId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$OcrBlocksTableFilterComposer(
            $db: $db,
            $table: $db.ocrBlocks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CardFieldsTableOrderingComposer
    extends Composer<_$AppDatabase, $CardFieldsTable> {
  $$CardFieldsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fieldKey => $composableBuilder(
    column: $table.fieldKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get normalizedValue => $composableBuilder(
    column: $table.normalizedValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get verifiedByUser => $composableBuilder(
    column: $table.verifiedByUser,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get validationIssue => $composableBuilder(
    column: $table.validationIssue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get valueKind => $composableBuilder(
    column: $table.valueKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get regionRect => $composableBuilder(
    column: $table.regionRect,
    builder: (column) => ColumnOrderings(column),
  );

  $$CardsTableOrderingComposer get cardId {
    final $$CardsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cardId,
      referencedTable: $db.cards,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CardsTableOrderingComposer(
            $db: $db,
            $table: $db.cards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CardFieldsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CardFieldsTable> {
  $$CardFieldsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get fieldKey =>
      $composableBuilder(column: $table.fieldKey, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<String> get normalizedValue => $composableBuilder(
    column: $table.normalizedValue,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<FactSource, String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<double> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get verifiedByUser => $composableBuilder(
    column: $table.verifiedByUser,
    builder: (column) => column,
  );

  GeneratedColumn<String> get validationIssue => $composableBuilder(
    column: $table.validationIssue,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<FieldValueKind, String> get valueKind =>
      $composableBuilder(column: $table.valueKind, builder: (column) => column);

  GeneratedColumn<String> get regionRect => $composableBuilder(
    column: $table.regionRect,
    builder: (column) => column,
  );

  $$CardsTableAnnotationComposer get cardId {
    final $$CardsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cardId,
      referencedTable: $db.cards,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CardsTableAnnotationComposer(
            $db: $db,
            $table: $db.cards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> ocrBlocksRefs<T extends Object>(
    Expression<T> Function($$OcrBlocksTableAnnotationComposer a) f,
  ) {
    final $$OcrBlocksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.ocrBlocks,
      getReferencedColumn: (t) => t.fieldId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$OcrBlocksTableAnnotationComposer(
            $db: $db,
            $table: $db.ocrBlocks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CardFieldsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CardFieldsTable,
          CardField,
          $$CardFieldsTableFilterComposer,
          $$CardFieldsTableOrderingComposer,
          $$CardFieldsTableAnnotationComposer,
          $$CardFieldsTableCreateCompanionBuilder,
          $$CardFieldsTableUpdateCompanionBuilder,
          (CardField, $$CardFieldsTableReferences),
          CardField,
          PrefetchHooks Function({bool cardId, bool ocrBlocksRefs})
        > {
  $$CardFieldsTableTableManager(_$AppDatabase db, $CardFieldsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CardFieldsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CardFieldsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CardFieldsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> id = const Value.absent(),
                Value<int> cardId = const Value.absent(),
                Value<String> fieldKey = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<String?> normalizedValue = const Value.absent(),
                Value<FactSource> source = const Value.absent(),
                Value<double?> confidence = const Value.absent(),
                Value<bool> verifiedByUser = const Value.absent(),
                Value<String?> validationIssue = const Value.absent(),
                Value<FieldValueKind> valueKind = const Value.absent(),
                Value<String?> regionRect = const Value.absent(),
              }) => CardFieldsCompanion(
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                id: id,
                cardId: cardId,
                fieldKey: fieldKey,
                value: value,
                normalizedValue: normalizedValue,
                source: source,
                confidence: confidence,
                verifiedByUser: verifiedByUser,
                validationIssue: validationIssue,
                valueKind: valueKind,
                regionRect: regionRect,
              ),
          createCompanionCallback:
              ({
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> id = const Value.absent(),
                required int cardId,
                required String fieldKey,
                required String value,
                Value<String?> normalizedValue = const Value.absent(),
                required FactSource source,
                Value<double?> confidence = const Value.absent(),
                Value<bool> verifiedByUser = const Value.absent(),
                Value<String?> validationIssue = const Value.absent(),
                Value<FieldValueKind> valueKind = const Value.absent(),
                Value<String?> regionRect = const Value.absent(),
              }) => CardFieldsCompanion.insert(
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                id: id,
                cardId: cardId,
                fieldKey: fieldKey,
                value: value,
                normalizedValue: normalizedValue,
                source: source,
                confidence: confidence,
                verifiedByUser: verifiedByUser,
                validationIssue: validationIssue,
                valueKind: valueKind,
                regionRect: regionRect,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$CardFieldsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({cardId = false, ocrBlocksRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (ocrBlocksRefs) db.ocrBlocks],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (cardId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.cardId,
                                referencedTable: $$CardFieldsTableReferences
                                    ._cardIdTable(db),
                                referencedColumn: $$CardFieldsTableReferences
                                    ._cardIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (ocrBlocksRefs)
                    await $_getPrefetchedData<
                      CardField,
                      $CardFieldsTable,
                      OcrBlockRow
                    >(
                      currentTable: table,
                      referencedTable: $$CardFieldsTableReferences
                          ._ocrBlocksRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$CardFieldsTableReferences(
                            db,
                            table,
                            p0,
                          ).ocrBlocksRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.fieldId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$CardFieldsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CardFieldsTable,
      CardField,
      $$CardFieldsTableFilterComposer,
      $$CardFieldsTableOrderingComposer,
      $$CardFieldsTableAnnotationComposer,
      $$CardFieldsTableCreateCompanionBuilder,
      $$CardFieldsTableUpdateCompanionBuilder,
      (CardField, $$CardFieldsTableReferences),
      CardField,
      PrefetchHooks Function({bool cardId, bool ocrBlocksRefs})
    >;
typedef $$ContactPointsTableCreateCompanionBuilder =
    ContactPointsCompanion Function({
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> id,
      required String ownerType,
      required int ownerId,
      required ContactKind kind,
      required String value,
      Value<String?> normalizedValue,
      Value<String?> label,
      Value<int?> roleId,
      required FactSource source,
      Value<bool> isActive,
    });
typedef $$ContactPointsTableUpdateCompanionBuilder =
    ContactPointsCompanion Function({
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> id,
      Value<String> ownerType,
      Value<int> ownerId,
      Value<ContactKind> kind,
      Value<String> value,
      Value<String?> normalizedValue,
      Value<String?> label,
      Value<int?> roleId,
      Value<FactSource> source,
      Value<bool> isActive,
    });

final class $$ContactPointsTableReferences
    extends BaseReferences<_$AppDatabase, $ContactPointsTable, ContactPoint> {
  $$ContactPointsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $RolesTable _roleIdTable(_$AppDatabase db) =>
      db.roles.createAlias('contact_points__role_id__roles__id');

  $$RolesTableProcessedTableManager? get roleId {
    final $_column = $_itemColumn<int>('role_id');
    if ($_column == null) return null;
    final manager = $$RolesTableTableManager(
      $_db,
      $_db.roles,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_roleIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ContactPointsTableFilterComposer
    extends Composer<_$AppDatabase, $ContactPointsTable> {
  $$ContactPointsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ownerType => $composableBuilder(
    column: $table.ownerType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<ContactKind, ContactKind, String> get kind =>
      $composableBuilder(
        column: $table.kind,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get normalizedValue => $composableBuilder(
    column: $table.normalizedValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<FactSource, FactSource, String> get source =>
      $composableBuilder(
        column: $table.source,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );

  $$RolesTableFilterComposer get roleId {
    final $$RolesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.roleId,
      referencedTable: $db.roles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RolesTableFilterComposer(
            $db: $db,
            $table: $db.roles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ContactPointsTableOrderingComposer
    extends Composer<_$AppDatabase, $ContactPointsTable> {
  $$ContactPointsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ownerType => $composableBuilder(
    column: $table.ownerType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get normalizedValue => $composableBuilder(
    column: $table.normalizedValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );

  $$RolesTableOrderingComposer get roleId {
    final $$RolesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.roleId,
      referencedTable: $db.roles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RolesTableOrderingComposer(
            $db: $db,
            $table: $db.roles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ContactPointsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ContactPointsTable> {
  $$ContactPointsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get ownerType =>
      $composableBuilder(column: $table.ownerType, builder: (column) => column);

  GeneratedColumn<int> get ownerId =>
      $composableBuilder(column: $table.ownerId, builder: (column) => column);

  GeneratedColumnWithTypeConverter<ContactKind, String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<String> get normalizedValue => $composableBuilder(
    column: $table.normalizedValue,
    builder: (column) => column,
  );

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumnWithTypeConverter<FactSource, String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  $$RolesTableAnnotationComposer get roleId {
    final $$RolesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.roleId,
      referencedTable: $db.roles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RolesTableAnnotationComposer(
            $db: $db,
            $table: $db.roles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ContactPointsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ContactPointsTable,
          ContactPoint,
          $$ContactPointsTableFilterComposer,
          $$ContactPointsTableOrderingComposer,
          $$ContactPointsTableAnnotationComposer,
          $$ContactPointsTableCreateCompanionBuilder,
          $$ContactPointsTableUpdateCompanionBuilder,
          (ContactPoint, $$ContactPointsTableReferences),
          ContactPoint,
          PrefetchHooks Function({bool roleId})
        > {
  $$ContactPointsTableTableManager(_$AppDatabase db, $ContactPointsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ContactPointsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ContactPointsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ContactPointsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> id = const Value.absent(),
                Value<String> ownerType = const Value.absent(),
                Value<int> ownerId = const Value.absent(),
                Value<ContactKind> kind = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<String?> normalizedValue = const Value.absent(),
                Value<String?> label = const Value.absent(),
                Value<int?> roleId = const Value.absent(),
                Value<FactSource> source = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
              }) => ContactPointsCompanion(
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                id: id,
                ownerType: ownerType,
                ownerId: ownerId,
                kind: kind,
                value: value,
                normalizedValue: normalizedValue,
                label: label,
                roleId: roleId,
                source: source,
                isActive: isActive,
              ),
          createCompanionCallback:
              ({
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> id = const Value.absent(),
                required String ownerType,
                required int ownerId,
                required ContactKind kind,
                required String value,
                Value<String?> normalizedValue = const Value.absent(),
                Value<String?> label = const Value.absent(),
                Value<int?> roleId = const Value.absent(),
                required FactSource source,
                Value<bool> isActive = const Value.absent(),
              }) => ContactPointsCompanion.insert(
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                id: id,
                ownerType: ownerType,
                ownerId: ownerId,
                kind: kind,
                value: value,
                normalizedValue: normalizedValue,
                label: label,
                roleId: roleId,
                source: source,
                isActive: isActive,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ContactPointsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({roleId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (roleId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.roleId,
                                referencedTable: $$ContactPointsTableReferences
                                    ._roleIdTable(db),
                                referencedColumn: $$ContactPointsTableReferences
                                    ._roleIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ContactPointsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ContactPointsTable,
      ContactPoint,
      $$ContactPointsTableFilterComposer,
      $$ContactPointsTableOrderingComposer,
      $$ContactPointsTableAnnotationComposer,
      $$ContactPointsTableCreateCompanionBuilder,
      $$ContactPointsTableUpdateCompanionBuilder,
      (ContactPoint, $$ContactPointsTableReferences),
      ContactPoint,
      PrefetchHooks Function({bool roleId})
    >;
typedef $$OcrBlocksTableCreateCompanionBuilder =
    OcrBlocksCompanion Function({
      Value<int> id,
      required int cardId,
      required String blockText,
      required String rect,
      required double confidence,
      required String script,
      Value<String?> engine,
      Value<String?> assignedFieldKey,
      Value<int?> fieldId,
      Value<int> orderIndex,
    });
typedef $$OcrBlocksTableUpdateCompanionBuilder =
    OcrBlocksCompanion Function({
      Value<int> id,
      Value<int> cardId,
      Value<String> blockText,
      Value<String> rect,
      Value<double> confidence,
      Value<String> script,
      Value<String?> engine,
      Value<String?> assignedFieldKey,
      Value<int?> fieldId,
      Value<int> orderIndex,
    });

final class $$OcrBlocksTableReferences
    extends BaseReferences<_$AppDatabase, $OcrBlocksTable, OcrBlockRow> {
  $$OcrBlocksTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $CardsTable _cardIdTable(_$AppDatabase db) =>
      db.cards.createAlias('ocr_blocks__card_id__cards__id');

  $$CardsTableProcessedTableManager get cardId {
    final $_column = $_itemColumn<int>('card_id')!;

    final manager = $$CardsTableTableManager(
      $_db,
      $_db.cards,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_cardIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $CardFieldsTable _fieldIdTable(_$AppDatabase db) =>
      db.cardFields.createAlias('ocr_blocks__field_id__card_fields__id');

  $$CardFieldsTableProcessedTableManager? get fieldId {
    final $_column = $_itemColumn<int>('field_id');
    if ($_column == null) return null;
    final manager = $$CardFieldsTableTableManager(
      $_db,
      $_db.cardFields,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_fieldIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$OcrBlocksTableFilterComposer
    extends Composer<_$AppDatabase, $OcrBlocksTable> {
  $$OcrBlocksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get blockText => $composableBuilder(
    column: $table.blockText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rect => $composableBuilder(
    column: $table.rect,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get script => $composableBuilder(
    column: $table.script,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get engine => $composableBuilder(
    column: $table.engine,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get assignedFieldKey => $composableBuilder(
    column: $table.assignedFieldKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => ColumnFilters(column),
  );

  $$CardsTableFilterComposer get cardId {
    final $$CardsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cardId,
      referencedTable: $db.cards,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CardsTableFilterComposer(
            $db: $db,
            $table: $db.cards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CardFieldsTableFilterComposer get fieldId {
    final $$CardFieldsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.fieldId,
      referencedTable: $db.cardFields,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CardFieldsTableFilterComposer(
            $db: $db,
            $table: $db.cardFields,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$OcrBlocksTableOrderingComposer
    extends Composer<_$AppDatabase, $OcrBlocksTable> {
  $$OcrBlocksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get blockText => $composableBuilder(
    column: $table.blockText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rect => $composableBuilder(
    column: $table.rect,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get script => $composableBuilder(
    column: $table.script,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get engine => $composableBuilder(
    column: $table.engine,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get assignedFieldKey => $composableBuilder(
    column: $table.assignedFieldKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => ColumnOrderings(column),
  );

  $$CardsTableOrderingComposer get cardId {
    final $$CardsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cardId,
      referencedTable: $db.cards,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CardsTableOrderingComposer(
            $db: $db,
            $table: $db.cards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CardFieldsTableOrderingComposer get fieldId {
    final $$CardFieldsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.fieldId,
      referencedTable: $db.cardFields,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CardFieldsTableOrderingComposer(
            $db: $db,
            $table: $db.cardFields,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$OcrBlocksTableAnnotationComposer
    extends Composer<_$AppDatabase, $OcrBlocksTable> {
  $$OcrBlocksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get blockText =>
      $composableBuilder(column: $table.blockText, builder: (column) => column);

  GeneratedColumn<String> get rect =>
      $composableBuilder(column: $table.rect, builder: (column) => column);

  GeneratedColumn<double> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => column,
  );

  GeneratedColumn<String> get script =>
      $composableBuilder(column: $table.script, builder: (column) => column);

  GeneratedColumn<String> get engine =>
      $composableBuilder(column: $table.engine, builder: (column) => column);

  GeneratedColumn<String> get assignedFieldKey => $composableBuilder(
    column: $table.assignedFieldKey,
    builder: (column) => column,
  );

  GeneratedColumn<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => column,
  );

  $$CardsTableAnnotationComposer get cardId {
    final $$CardsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cardId,
      referencedTable: $db.cards,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CardsTableAnnotationComposer(
            $db: $db,
            $table: $db.cards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CardFieldsTableAnnotationComposer get fieldId {
    final $$CardFieldsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.fieldId,
      referencedTable: $db.cardFields,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CardFieldsTableAnnotationComposer(
            $db: $db,
            $table: $db.cardFields,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$OcrBlocksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OcrBlocksTable,
          OcrBlockRow,
          $$OcrBlocksTableFilterComposer,
          $$OcrBlocksTableOrderingComposer,
          $$OcrBlocksTableAnnotationComposer,
          $$OcrBlocksTableCreateCompanionBuilder,
          $$OcrBlocksTableUpdateCompanionBuilder,
          (OcrBlockRow, $$OcrBlocksTableReferences),
          OcrBlockRow,
          PrefetchHooks Function({bool cardId, bool fieldId})
        > {
  $$OcrBlocksTableTableManager(_$AppDatabase db, $OcrBlocksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OcrBlocksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OcrBlocksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OcrBlocksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> cardId = const Value.absent(),
                Value<String> blockText = const Value.absent(),
                Value<String> rect = const Value.absent(),
                Value<double> confidence = const Value.absent(),
                Value<String> script = const Value.absent(),
                Value<String?> engine = const Value.absent(),
                Value<String?> assignedFieldKey = const Value.absent(),
                Value<int?> fieldId = const Value.absent(),
                Value<int> orderIndex = const Value.absent(),
              }) => OcrBlocksCompanion(
                id: id,
                cardId: cardId,
                blockText: blockText,
                rect: rect,
                confidence: confidence,
                script: script,
                engine: engine,
                assignedFieldKey: assignedFieldKey,
                fieldId: fieldId,
                orderIndex: orderIndex,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int cardId,
                required String blockText,
                required String rect,
                required double confidence,
                required String script,
                Value<String?> engine = const Value.absent(),
                Value<String?> assignedFieldKey = const Value.absent(),
                Value<int?> fieldId = const Value.absent(),
                Value<int> orderIndex = const Value.absent(),
              }) => OcrBlocksCompanion.insert(
                id: id,
                cardId: cardId,
                blockText: blockText,
                rect: rect,
                confidence: confidence,
                script: script,
                engine: engine,
                assignedFieldKey: assignedFieldKey,
                fieldId: fieldId,
                orderIndex: orderIndex,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$OcrBlocksTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({cardId = false, fieldId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (cardId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.cardId,
                                referencedTable: $$OcrBlocksTableReferences
                                    ._cardIdTable(db),
                                referencedColumn: $$OcrBlocksTableReferences
                                    ._cardIdTable(db)
                                    .id,
                              )
                              as T;
                    }
                    if (fieldId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.fieldId,
                                referencedTable: $$OcrBlocksTableReferences
                                    ._fieldIdTable(db),
                                referencedColumn: $$OcrBlocksTableReferences
                                    ._fieldIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$OcrBlocksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OcrBlocksTable,
      OcrBlockRow,
      $$OcrBlocksTableFilterComposer,
      $$OcrBlocksTableOrderingComposer,
      $$OcrBlocksTableAnnotationComposer,
      $$OcrBlocksTableCreateCompanionBuilder,
      $$OcrBlocksTableUpdateCompanionBuilder,
      (OcrBlockRow, $$OcrBlocksTableReferences),
      OcrBlockRow,
      PrefetchHooks Function({bool cardId, bool fieldId})
    >;
typedef $$ExtractionAttemptsTableCreateCompanionBuilder =
    ExtractionAttemptsCompanion Function({
      Value<int> id,
      required int cardId,
      required String engine,
      required DateTime startedAt,
      required int durationMs,
      required AttemptStatus status,
      Value<int> fieldsFound,
      Value<String?> errorCode,
      Value<String?> errorDetail,
    });
typedef $$ExtractionAttemptsTableUpdateCompanionBuilder =
    ExtractionAttemptsCompanion Function({
      Value<int> id,
      Value<int> cardId,
      Value<String> engine,
      Value<DateTime> startedAt,
      Value<int> durationMs,
      Value<AttemptStatus> status,
      Value<int> fieldsFound,
      Value<String?> errorCode,
      Value<String?> errorDetail,
    });

final class $$ExtractionAttemptsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $ExtractionAttemptsTable,
          ExtractionAttempt
        > {
  $$ExtractionAttemptsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $CardsTable _cardIdTable(_$AppDatabase db) =>
      db.cards.createAlias('extraction_attempts__card_id__cards__id');

  $$CardsTableProcessedTableManager get cardId {
    final $_column = $_itemColumn<int>('card_id')!;

    final manager = $$CardsTableTableManager(
      $_db,
      $_db.cards,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_cardIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ExtractionAttemptsTableFilterComposer
    extends Composer<_$AppDatabase, $ExtractionAttemptsTable> {
  $$ExtractionAttemptsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get engine => $composableBuilder(
    column: $table.engine,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<AttemptStatus, AttemptStatus, String>
  get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<int> get fieldsFound => $composableBuilder(
    column: $table.fieldsFound,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get errorCode => $composableBuilder(
    column: $table.errorCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get errorDetail => $composableBuilder(
    column: $table.errorDetail,
    builder: (column) => ColumnFilters(column),
  );

  $$CardsTableFilterComposer get cardId {
    final $$CardsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cardId,
      referencedTable: $db.cards,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CardsTableFilterComposer(
            $db: $db,
            $table: $db.cards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ExtractionAttemptsTableOrderingComposer
    extends Composer<_$AppDatabase, $ExtractionAttemptsTable> {
  $$ExtractionAttemptsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get engine => $composableBuilder(
    column: $table.engine,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get fieldsFound => $composableBuilder(
    column: $table.fieldsFound,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get errorCode => $composableBuilder(
    column: $table.errorCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get errorDetail => $composableBuilder(
    column: $table.errorDetail,
    builder: (column) => ColumnOrderings(column),
  );

  $$CardsTableOrderingComposer get cardId {
    final $$CardsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cardId,
      referencedTable: $db.cards,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CardsTableOrderingComposer(
            $db: $db,
            $table: $db.cards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ExtractionAttemptsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ExtractionAttemptsTable> {
  $$ExtractionAttemptsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get engine =>
      $composableBuilder(column: $table.engine, builder: (column) => column);

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<AttemptStatus, String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get fieldsFound => $composableBuilder(
    column: $table.fieldsFound,
    builder: (column) => column,
  );

  GeneratedColumn<String> get errorCode =>
      $composableBuilder(column: $table.errorCode, builder: (column) => column);

  GeneratedColumn<String> get errorDetail => $composableBuilder(
    column: $table.errorDetail,
    builder: (column) => column,
  );

  $$CardsTableAnnotationComposer get cardId {
    final $$CardsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cardId,
      referencedTable: $db.cards,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CardsTableAnnotationComposer(
            $db: $db,
            $table: $db.cards,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ExtractionAttemptsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ExtractionAttemptsTable,
          ExtractionAttempt,
          $$ExtractionAttemptsTableFilterComposer,
          $$ExtractionAttemptsTableOrderingComposer,
          $$ExtractionAttemptsTableAnnotationComposer,
          $$ExtractionAttemptsTableCreateCompanionBuilder,
          $$ExtractionAttemptsTableUpdateCompanionBuilder,
          (ExtractionAttempt, $$ExtractionAttemptsTableReferences),
          ExtractionAttempt,
          PrefetchHooks Function({bool cardId})
        > {
  $$ExtractionAttemptsTableTableManager(
    _$AppDatabase db,
    $ExtractionAttemptsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ExtractionAttemptsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ExtractionAttemptsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ExtractionAttemptsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> cardId = const Value.absent(),
                Value<String> engine = const Value.absent(),
                Value<DateTime> startedAt = const Value.absent(),
                Value<int> durationMs = const Value.absent(),
                Value<AttemptStatus> status = const Value.absent(),
                Value<int> fieldsFound = const Value.absent(),
                Value<String?> errorCode = const Value.absent(),
                Value<String?> errorDetail = const Value.absent(),
              }) => ExtractionAttemptsCompanion(
                id: id,
                cardId: cardId,
                engine: engine,
                startedAt: startedAt,
                durationMs: durationMs,
                status: status,
                fieldsFound: fieldsFound,
                errorCode: errorCode,
                errorDetail: errorDetail,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int cardId,
                required String engine,
                required DateTime startedAt,
                required int durationMs,
                required AttemptStatus status,
                Value<int> fieldsFound = const Value.absent(),
                Value<String?> errorCode = const Value.absent(),
                Value<String?> errorDetail = const Value.absent(),
              }) => ExtractionAttemptsCompanion.insert(
                id: id,
                cardId: cardId,
                engine: engine,
                startedAt: startedAt,
                durationMs: durationMs,
                status: status,
                fieldsFound: fieldsFound,
                errorCode: errorCode,
                errorDetail: errorDetail,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ExtractionAttemptsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({cardId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (cardId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.cardId,
                                referencedTable:
                                    $$ExtractionAttemptsTableReferences
                                        ._cardIdTable(db),
                                referencedColumn:
                                    $$ExtractionAttemptsTableReferences
                                        ._cardIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ExtractionAttemptsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ExtractionAttemptsTable,
      ExtractionAttempt,
      $$ExtractionAttemptsTableFilterComposer,
      $$ExtractionAttemptsTableOrderingComposer,
      $$ExtractionAttemptsTableAnnotationComposer,
      $$ExtractionAttemptsTableCreateCompanionBuilder,
      $$ExtractionAttemptsTableUpdateCompanionBuilder,
      (ExtractionAttempt, $$ExtractionAttemptsTableReferences),
      ExtractionAttempt,
      PrefetchHooks Function({bool cardId})
    >;
typedef $$NotesTableCreateCompanionBuilder =
    NotesCompanion Function({
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> id,
      required String subjectType,
      required int subjectId,
      Value<String?> body,
      Value<String?> audioPath,
      Value<String?> transcript,
      Value<String?> language,
    });
typedef $$NotesTableUpdateCompanionBuilder =
    NotesCompanion Function({
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> id,
      Value<String> subjectType,
      Value<int> subjectId,
      Value<String?> body,
      Value<String?> audioPath,
      Value<String?> transcript,
      Value<String?> language,
    });

class $$NotesTableFilterComposer extends Composer<_$AppDatabase, $NotesTable> {
  $$NotesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subjectType => $composableBuilder(
    column: $table.subjectType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get subjectId => $composableBuilder(
    column: $table.subjectId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get audioPath => $composableBuilder(
    column: $table.audioPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get transcript => $composableBuilder(
    column: $table.transcript,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get language => $composableBuilder(
    column: $table.language,
    builder: (column) => ColumnFilters(column),
  );
}

class $$NotesTableOrderingComposer
    extends Composer<_$AppDatabase, $NotesTable> {
  $$NotesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subjectType => $composableBuilder(
    column: $table.subjectType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get subjectId => $composableBuilder(
    column: $table.subjectId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get audioPath => $composableBuilder(
    column: $table.audioPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get transcript => $composableBuilder(
    column: $table.transcript,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get language => $composableBuilder(
    column: $table.language,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$NotesTableAnnotationComposer
    extends Composer<_$AppDatabase, $NotesTable> {
  $$NotesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get subjectType => $composableBuilder(
    column: $table.subjectType,
    builder: (column) => column,
  );

  GeneratedColumn<int> get subjectId =>
      $composableBuilder(column: $table.subjectId, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<String> get audioPath =>
      $composableBuilder(column: $table.audioPath, builder: (column) => column);

  GeneratedColumn<String> get transcript => $composableBuilder(
    column: $table.transcript,
    builder: (column) => column,
  );

  GeneratedColumn<String> get language =>
      $composableBuilder(column: $table.language, builder: (column) => column);
}

class $$NotesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $NotesTable,
          Note,
          $$NotesTableFilterComposer,
          $$NotesTableOrderingComposer,
          $$NotesTableAnnotationComposer,
          $$NotesTableCreateCompanionBuilder,
          $$NotesTableUpdateCompanionBuilder,
          (Note, BaseReferences<_$AppDatabase, $NotesTable, Note>),
          Note,
          PrefetchHooks Function()
        > {
  $$NotesTableTableManager(_$AppDatabase db, $NotesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NotesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NotesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$NotesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> id = const Value.absent(),
                Value<String> subjectType = const Value.absent(),
                Value<int> subjectId = const Value.absent(),
                Value<String?> body = const Value.absent(),
                Value<String?> audioPath = const Value.absent(),
                Value<String?> transcript = const Value.absent(),
                Value<String?> language = const Value.absent(),
              }) => NotesCompanion(
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                id: id,
                subjectType: subjectType,
                subjectId: subjectId,
                body: body,
                audioPath: audioPath,
                transcript: transcript,
                language: language,
              ),
          createCompanionCallback:
              ({
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> id = const Value.absent(),
                required String subjectType,
                required int subjectId,
                Value<String?> body = const Value.absent(),
                Value<String?> audioPath = const Value.absent(),
                Value<String?> transcript = const Value.absent(),
                Value<String?> language = const Value.absent(),
              }) => NotesCompanion.insert(
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                id: id,
                subjectType: subjectType,
                subjectId: subjectId,
                body: body,
                audioPath: audioPath,
                transcript: transcript,
                language: language,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$NotesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $NotesTable,
      Note,
      $$NotesTableFilterComposer,
      $$NotesTableOrderingComposer,
      $$NotesTableAnnotationComposer,
      $$NotesTableCreateCompanionBuilder,
      $$NotesTableUpdateCompanionBuilder,
      (Note, BaseReferences<_$AppDatabase, $NotesTable, Note>),
      Note,
      PrefetchHooks Function()
    >;
typedef $$AttributesTableCreateCompanionBuilder =
    AttributesCompanion Function({
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> id,
      required String subjectType,
      required int subjectId,
      required String key,
      required String value,
      required FactSource source,
      Value<double?> confidence,
    });
typedef $$AttributesTableUpdateCompanionBuilder =
    AttributesCompanion Function({
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> id,
      Value<String> subjectType,
      Value<int> subjectId,
      Value<String> key,
      Value<String> value,
      Value<FactSource> source,
      Value<double?> confidence,
    });

class $$AttributesTableFilterComposer
    extends Composer<_$AppDatabase, $AttributesTable> {
  $$AttributesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subjectType => $composableBuilder(
    column: $table.subjectType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get subjectId => $composableBuilder(
    column: $table.subjectId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<FactSource, FactSource, String> get source =>
      $composableBuilder(
        column: $table.source,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<double> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AttributesTableOrderingComposer
    extends Composer<_$AppDatabase, $AttributesTable> {
  $$AttributesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subjectType => $composableBuilder(
    column: $table.subjectType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get subjectId => $composableBuilder(
    column: $table.subjectId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AttributesTableAnnotationComposer
    extends Composer<_$AppDatabase, $AttributesTable> {
  $$AttributesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get subjectType => $composableBuilder(
    column: $table.subjectType,
    builder: (column) => column,
  );

  GeneratedColumn<int> get subjectId =>
      $composableBuilder(column: $table.subjectId, builder: (column) => column);

  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumnWithTypeConverter<FactSource, String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<double> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => column,
  );
}

class $$AttributesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AttributesTable,
          Attribute,
          $$AttributesTableFilterComposer,
          $$AttributesTableOrderingComposer,
          $$AttributesTableAnnotationComposer,
          $$AttributesTableCreateCompanionBuilder,
          $$AttributesTableUpdateCompanionBuilder,
          (
            Attribute,
            BaseReferences<_$AppDatabase, $AttributesTable, Attribute>,
          ),
          Attribute,
          PrefetchHooks Function()
        > {
  $$AttributesTableTableManager(_$AppDatabase db, $AttributesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AttributesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AttributesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AttributesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> id = const Value.absent(),
                Value<String> subjectType = const Value.absent(),
                Value<int> subjectId = const Value.absent(),
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<FactSource> source = const Value.absent(),
                Value<double?> confidence = const Value.absent(),
              }) => AttributesCompanion(
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                id: id,
                subjectType: subjectType,
                subjectId: subjectId,
                key: key,
                value: value,
                source: source,
                confidence: confidence,
              ),
          createCompanionCallback:
              ({
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> id = const Value.absent(),
                required String subjectType,
                required int subjectId,
                required String key,
                required String value,
                required FactSource source,
                Value<double?> confidence = const Value.absent(),
              }) => AttributesCompanion.insert(
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                id: id,
                subjectType: subjectType,
                subjectId: subjectId,
                key: key,
                value: value,
                source: source,
                confidence: confidence,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AttributesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AttributesTable,
      Attribute,
      $$AttributesTableFilterComposer,
      $$AttributesTableOrderingComposer,
      $$AttributesTableAnnotationComposer,
      $$AttributesTableCreateCompanionBuilder,
      $$AttributesTableUpdateCompanionBuilder,
      (Attribute, BaseReferences<_$AppDatabase, $AttributesTable, Attribute>),
      Attribute,
      PrefetchHooks Function()
    >;
typedef $$CapabilityProfilesTableCreateCompanionBuilder =
    CapabilityProfilesCompanion Function({
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> id,
      required String subjectType,
      required int subjectId,
      required String canonicalEn,
      Value<String?> servicesJson,
      Value<String?> categoriesJson,
      required String model,
    });
typedef $$CapabilityProfilesTableUpdateCompanionBuilder =
    CapabilityProfilesCompanion Function({
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> id,
      Value<String> subjectType,
      Value<int> subjectId,
      Value<String> canonicalEn,
      Value<String?> servicesJson,
      Value<String?> categoriesJson,
      Value<String> model,
    });

class $$CapabilityProfilesTableFilterComposer
    extends Composer<_$AppDatabase, $CapabilityProfilesTable> {
  $$CapabilityProfilesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subjectType => $composableBuilder(
    column: $table.subjectType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get subjectId => $composableBuilder(
    column: $table.subjectId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get canonicalEn => $composableBuilder(
    column: $table.canonicalEn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get servicesJson => $composableBuilder(
    column: $table.servicesJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get categoriesJson => $composableBuilder(
    column: $table.categoriesJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get model => $composableBuilder(
    column: $table.model,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CapabilityProfilesTableOrderingComposer
    extends Composer<_$AppDatabase, $CapabilityProfilesTable> {
  $$CapabilityProfilesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subjectType => $composableBuilder(
    column: $table.subjectType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get subjectId => $composableBuilder(
    column: $table.subjectId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get canonicalEn => $composableBuilder(
    column: $table.canonicalEn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get servicesJson => $composableBuilder(
    column: $table.servicesJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get categoriesJson => $composableBuilder(
    column: $table.categoriesJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get model => $composableBuilder(
    column: $table.model,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CapabilityProfilesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CapabilityProfilesTable> {
  $$CapabilityProfilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get subjectType => $composableBuilder(
    column: $table.subjectType,
    builder: (column) => column,
  );

  GeneratedColumn<int> get subjectId =>
      $composableBuilder(column: $table.subjectId, builder: (column) => column);

  GeneratedColumn<String> get canonicalEn => $composableBuilder(
    column: $table.canonicalEn,
    builder: (column) => column,
  );

  GeneratedColumn<String> get servicesJson => $composableBuilder(
    column: $table.servicesJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get categoriesJson => $composableBuilder(
    column: $table.categoriesJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get model =>
      $composableBuilder(column: $table.model, builder: (column) => column);
}

class $$CapabilityProfilesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CapabilityProfilesTable,
          CapabilityProfile,
          $$CapabilityProfilesTableFilterComposer,
          $$CapabilityProfilesTableOrderingComposer,
          $$CapabilityProfilesTableAnnotationComposer,
          $$CapabilityProfilesTableCreateCompanionBuilder,
          $$CapabilityProfilesTableUpdateCompanionBuilder,
          (
            CapabilityProfile,
            BaseReferences<
              _$AppDatabase,
              $CapabilityProfilesTable,
              CapabilityProfile
            >,
          ),
          CapabilityProfile,
          PrefetchHooks Function()
        > {
  $$CapabilityProfilesTableTableManager(
    _$AppDatabase db,
    $CapabilityProfilesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CapabilityProfilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CapabilityProfilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CapabilityProfilesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> id = const Value.absent(),
                Value<String> subjectType = const Value.absent(),
                Value<int> subjectId = const Value.absent(),
                Value<String> canonicalEn = const Value.absent(),
                Value<String?> servicesJson = const Value.absent(),
                Value<String?> categoriesJson = const Value.absent(),
                Value<String> model = const Value.absent(),
              }) => CapabilityProfilesCompanion(
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                id: id,
                subjectType: subjectType,
                subjectId: subjectId,
                canonicalEn: canonicalEn,
                servicesJson: servicesJson,
                categoriesJson: categoriesJson,
                model: model,
              ),
          createCompanionCallback:
              ({
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> id = const Value.absent(),
                required String subjectType,
                required int subjectId,
                required String canonicalEn,
                Value<String?> servicesJson = const Value.absent(),
                Value<String?> categoriesJson = const Value.absent(),
                required String model,
              }) => CapabilityProfilesCompanion.insert(
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                id: id,
                subjectType: subjectType,
                subjectId: subjectId,
                canonicalEn: canonicalEn,
                servicesJson: servicesJson,
                categoriesJson: categoriesJson,
                model: model,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CapabilityProfilesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CapabilityProfilesTable,
      CapabilityProfile,
      $$CapabilityProfilesTableFilterComposer,
      $$CapabilityProfilesTableOrderingComposer,
      $$CapabilityProfilesTableAnnotationComposer,
      $$CapabilityProfilesTableCreateCompanionBuilder,
      $$CapabilityProfilesTableUpdateCompanionBuilder,
      (
        CapabilityProfile,
        BaseReferences<
          _$AppDatabase,
          $CapabilityProfilesTable,
          CapabilityProfile
        >,
      ),
      CapabilityProfile,
      PrefetchHooks Function()
    >;
typedef $$EmbeddingsTableCreateCompanionBuilder =
    EmbeddingsCompanion Function({
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> id,
      required String subjectType,
      required int subjectId,
      required Uint8List vector,
      required int dim,
      required String model,
    });
typedef $$EmbeddingsTableUpdateCompanionBuilder =
    EmbeddingsCompanion Function({
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> id,
      Value<String> subjectType,
      Value<int> subjectId,
      Value<Uint8List> vector,
      Value<int> dim,
      Value<String> model,
    });

class $$EmbeddingsTableFilterComposer
    extends Composer<_$AppDatabase, $EmbeddingsTable> {
  $$EmbeddingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subjectType => $composableBuilder(
    column: $table.subjectType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get subjectId => $composableBuilder(
    column: $table.subjectId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get vector => $composableBuilder(
    column: $table.vector,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dim => $composableBuilder(
    column: $table.dim,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get model => $composableBuilder(
    column: $table.model,
    builder: (column) => ColumnFilters(column),
  );
}

class $$EmbeddingsTableOrderingComposer
    extends Composer<_$AppDatabase, $EmbeddingsTable> {
  $$EmbeddingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subjectType => $composableBuilder(
    column: $table.subjectType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get subjectId => $composableBuilder(
    column: $table.subjectId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get vector => $composableBuilder(
    column: $table.vector,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dim => $composableBuilder(
    column: $table.dim,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get model => $composableBuilder(
    column: $table.model,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EmbeddingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $EmbeddingsTable> {
  $$EmbeddingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get subjectType => $composableBuilder(
    column: $table.subjectType,
    builder: (column) => column,
  );

  GeneratedColumn<int> get subjectId =>
      $composableBuilder(column: $table.subjectId, builder: (column) => column);

  GeneratedColumn<Uint8List> get vector =>
      $composableBuilder(column: $table.vector, builder: (column) => column);

  GeneratedColumn<int> get dim =>
      $composableBuilder(column: $table.dim, builder: (column) => column);

  GeneratedColumn<String> get model =>
      $composableBuilder(column: $table.model, builder: (column) => column);
}

class $$EmbeddingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EmbeddingsTable,
          Embedding,
          $$EmbeddingsTableFilterComposer,
          $$EmbeddingsTableOrderingComposer,
          $$EmbeddingsTableAnnotationComposer,
          $$EmbeddingsTableCreateCompanionBuilder,
          $$EmbeddingsTableUpdateCompanionBuilder,
          (
            Embedding,
            BaseReferences<_$AppDatabase, $EmbeddingsTable, Embedding>,
          ),
          Embedding,
          PrefetchHooks Function()
        > {
  $$EmbeddingsTableTableManager(_$AppDatabase db, $EmbeddingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EmbeddingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EmbeddingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EmbeddingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> id = const Value.absent(),
                Value<String> subjectType = const Value.absent(),
                Value<int> subjectId = const Value.absent(),
                Value<Uint8List> vector = const Value.absent(),
                Value<int> dim = const Value.absent(),
                Value<String> model = const Value.absent(),
              }) => EmbeddingsCompanion(
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                id: id,
                subjectType: subjectType,
                subjectId: subjectId,
                vector: vector,
                dim: dim,
                model: model,
              ),
          createCompanionCallback:
              ({
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> id = const Value.absent(),
                required String subjectType,
                required int subjectId,
                required Uint8List vector,
                required int dim,
                required String model,
              }) => EmbeddingsCompanion.insert(
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                id: id,
                subjectType: subjectType,
                subjectId: subjectId,
                vector: vector,
                dim: dim,
                model: model,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$EmbeddingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EmbeddingsTable,
      Embedding,
      $$EmbeddingsTableFilterComposer,
      $$EmbeddingsTableOrderingComposer,
      $$EmbeddingsTableAnnotationComposer,
      $$EmbeddingsTableCreateCompanionBuilder,
      $$EmbeddingsTableUpdateCompanionBuilder,
      (Embedding, BaseReferences<_$AppDatabase, $EmbeddingsTable, Embedding>),
      Embedding,
      PrefetchHooks Function()
    >;
typedef $$InteractionsTableCreateCompanionBuilder =
    InteractionsCompanion Function({
      Value<int> id,
      required String subjectType,
      required int subjectId,
      required InteractionKind kind,
      Value<String?> detail,
      Value<DateTime> occurredAt,
    });
typedef $$InteractionsTableUpdateCompanionBuilder =
    InteractionsCompanion Function({
      Value<int> id,
      Value<String> subjectType,
      Value<int> subjectId,
      Value<InteractionKind> kind,
      Value<String?> detail,
      Value<DateTime> occurredAt,
    });

class $$InteractionsTableFilterComposer
    extends Composer<_$AppDatabase, $InteractionsTable> {
  $$InteractionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subjectType => $composableBuilder(
    column: $table.subjectType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get subjectId => $composableBuilder(
    column: $table.subjectId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<InteractionKind, InteractionKind, String>
  get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get detail => $composableBuilder(
    column: $table.detail,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$InteractionsTableOrderingComposer
    extends Composer<_$AppDatabase, $InteractionsTable> {
  $$InteractionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subjectType => $composableBuilder(
    column: $table.subjectType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get subjectId => $composableBuilder(
    column: $table.subjectId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get detail => $composableBuilder(
    column: $table.detail,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$InteractionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $InteractionsTable> {
  $$InteractionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get subjectType => $composableBuilder(
    column: $table.subjectType,
    builder: (column) => column,
  );

  GeneratedColumn<int> get subjectId =>
      $composableBuilder(column: $table.subjectId, builder: (column) => column);

  GeneratedColumnWithTypeConverter<InteractionKind, String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get detail =>
      $composableBuilder(column: $table.detail, builder: (column) => column);

  GeneratedColumn<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => column,
  );
}

class $$InteractionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $InteractionsTable,
          Interaction,
          $$InteractionsTableFilterComposer,
          $$InteractionsTableOrderingComposer,
          $$InteractionsTableAnnotationComposer,
          $$InteractionsTableCreateCompanionBuilder,
          $$InteractionsTableUpdateCompanionBuilder,
          (
            Interaction,
            BaseReferences<_$AppDatabase, $InteractionsTable, Interaction>,
          ),
          Interaction,
          PrefetchHooks Function()
        > {
  $$InteractionsTableTableManager(_$AppDatabase db, $InteractionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$InteractionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$InteractionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$InteractionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> subjectType = const Value.absent(),
                Value<int> subjectId = const Value.absent(),
                Value<InteractionKind> kind = const Value.absent(),
                Value<String?> detail = const Value.absent(),
                Value<DateTime> occurredAt = const Value.absent(),
              }) => InteractionsCompanion(
                id: id,
                subjectType: subjectType,
                subjectId: subjectId,
                kind: kind,
                detail: detail,
                occurredAt: occurredAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String subjectType,
                required int subjectId,
                required InteractionKind kind,
                Value<String?> detail = const Value.absent(),
                Value<DateTime> occurredAt = const Value.absent(),
              }) => InteractionsCompanion.insert(
                id: id,
                subjectType: subjectType,
                subjectId: subjectId,
                kind: kind,
                detail: detail,
                occurredAt: occurredAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$InteractionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $InteractionsTable,
      Interaction,
      $$InteractionsTableFilterComposer,
      $$InteractionsTableOrderingComposer,
      $$InteractionsTableAnnotationComposer,
      $$InteractionsTableCreateCompanionBuilder,
      $$InteractionsTableUpdateCompanionBuilder,
      (
        Interaction,
        BaseReferences<_$AppDatabase, $InteractionsTable, Interaction>,
      ),
      Interaction,
      PrefetchHooks Function()
    >;
typedef $$TagsTableCreateCompanionBuilder =
    TagsCompanion Function({
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> id,
      required String name,
    });
typedef $$TagsTableUpdateCompanionBuilder =
    TagsCompanion Function({
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> id,
      Value<String> name,
    });

final class $$TagsTableReferences
    extends BaseReferences<_$AppDatabase, $TagsTable, Tag> {
  $$TagsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$SubjectTagsTable, List<SubjectTag>>
  _subjectTagsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.subjectTags,
    aliasName: 'tags__id__subject_tags__tag_id',
  );

  $$SubjectTagsTableProcessedTableManager get subjectTagsRefs {
    final manager = $$SubjectTagsTableTableManager(
      $_db,
      $_db.subjectTags,
    ).filter((f) => f.tagId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_subjectTagsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$TagsTableFilterComposer extends Composer<_$AppDatabase, $TagsTable> {
  $$TagsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> subjectTagsRefs(
    Expression<bool> Function($$SubjectTagsTableFilterComposer f) f,
  ) {
    final $$SubjectTagsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.subjectTags,
      getReferencedColumn: (t) => t.tagId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SubjectTagsTableFilterComposer(
            $db: $db,
            $table: $db.subjectTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TagsTableOrderingComposer extends Composer<_$AppDatabase, $TagsTable> {
  $$TagsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TagsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TagsTable> {
  $$TagsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  Expression<T> subjectTagsRefs<T extends Object>(
    Expression<T> Function($$SubjectTagsTableAnnotationComposer a) f,
  ) {
    final $$SubjectTagsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.subjectTags,
      getReferencedColumn: (t) => t.tagId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SubjectTagsTableAnnotationComposer(
            $db: $db,
            $table: $db.subjectTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TagsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TagsTable,
          Tag,
          $$TagsTableFilterComposer,
          $$TagsTableOrderingComposer,
          $$TagsTableAnnotationComposer,
          $$TagsTableCreateCompanionBuilder,
          $$TagsTableUpdateCompanionBuilder,
          (Tag, $$TagsTableReferences),
          Tag,
          PrefetchHooks Function({bool subjectTagsRefs})
        > {
  $$TagsTableTableManager(_$AppDatabase db, $TagsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TagsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TagsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TagsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
              }) => TagsCompanion(
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                id: id,
                name: name,
              ),
          createCompanionCallback:
              ({
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> id = const Value.absent(),
                required String name,
              }) => TagsCompanion.insert(
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                id: id,
                name: name,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$TagsTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({subjectTagsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (subjectTagsRefs) db.subjectTags],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (subjectTagsRefs)
                    await $_getPrefetchedData<Tag, $TagsTable, SubjectTag>(
                      currentTable: table,
                      referencedTable: $$TagsTableReferences
                          ._subjectTagsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$TagsTableReferences(db, table, p0).subjectTagsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.tagId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$TagsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TagsTable,
      Tag,
      $$TagsTableFilterComposer,
      $$TagsTableOrderingComposer,
      $$TagsTableAnnotationComposer,
      $$TagsTableCreateCompanionBuilder,
      $$TagsTableUpdateCompanionBuilder,
      (Tag, $$TagsTableReferences),
      Tag,
      PrefetchHooks Function({bool subjectTagsRefs})
    >;
typedef $$SubjectTagsTableCreateCompanionBuilder =
    SubjectTagsCompanion Function({
      required int tagId,
      required String subjectType,
      required int subjectId,
      Value<int> rowid,
    });
typedef $$SubjectTagsTableUpdateCompanionBuilder =
    SubjectTagsCompanion Function({
      Value<int> tagId,
      Value<String> subjectType,
      Value<int> subjectId,
      Value<int> rowid,
    });

final class $$SubjectTagsTableReferences
    extends BaseReferences<_$AppDatabase, $SubjectTagsTable, SubjectTag> {
  $$SubjectTagsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $TagsTable _tagIdTable(_$AppDatabase db) =>
      db.tags.createAlias('subject_tags__tag_id__tags__id');

  $$TagsTableProcessedTableManager get tagId {
    final $_column = $_itemColumn<int>('tag_id')!;

    final manager = $$TagsTableTableManager(
      $_db,
      $_db.tags,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_tagIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$SubjectTagsTableFilterComposer
    extends Composer<_$AppDatabase, $SubjectTagsTable> {
  $$SubjectTagsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get subjectType => $composableBuilder(
    column: $table.subjectType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get subjectId => $composableBuilder(
    column: $table.subjectId,
    builder: (column) => ColumnFilters(column),
  );

  $$TagsTableFilterComposer get tagId {
    final $$TagsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tagId,
      referencedTable: $db.tags,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TagsTableFilterComposer(
            $db: $db,
            $table: $db.tags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SubjectTagsTableOrderingComposer
    extends Composer<_$AppDatabase, $SubjectTagsTable> {
  $$SubjectTagsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get subjectType => $composableBuilder(
    column: $table.subjectType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get subjectId => $composableBuilder(
    column: $table.subjectId,
    builder: (column) => ColumnOrderings(column),
  );

  $$TagsTableOrderingComposer get tagId {
    final $$TagsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tagId,
      referencedTable: $db.tags,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TagsTableOrderingComposer(
            $db: $db,
            $table: $db.tags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SubjectTagsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SubjectTagsTable> {
  $$SubjectTagsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get subjectType => $composableBuilder(
    column: $table.subjectType,
    builder: (column) => column,
  );

  GeneratedColumn<int> get subjectId =>
      $composableBuilder(column: $table.subjectId, builder: (column) => column);

  $$TagsTableAnnotationComposer get tagId {
    final $$TagsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tagId,
      referencedTable: $db.tags,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TagsTableAnnotationComposer(
            $db: $db,
            $table: $db.tags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SubjectTagsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SubjectTagsTable,
          SubjectTag,
          $$SubjectTagsTableFilterComposer,
          $$SubjectTagsTableOrderingComposer,
          $$SubjectTagsTableAnnotationComposer,
          $$SubjectTagsTableCreateCompanionBuilder,
          $$SubjectTagsTableUpdateCompanionBuilder,
          (SubjectTag, $$SubjectTagsTableReferences),
          SubjectTag,
          PrefetchHooks Function({bool tagId})
        > {
  $$SubjectTagsTableTableManager(_$AppDatabase db, $SubjectTagsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SubjectTagsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SubjectTagsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SubjectTagsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> tagId = const Value.absent(),
                Value<String> subjectType = const Value.absent(),
                Value<int> subjectId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SubjectTagsCompanion(
                tagId: tagId,
                subjectType: subjectType,
                subjectId: subjectId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int tagId,
                required String subjectType,
                required int subjectId,
                Value<int> rowid = const Value.absent(),
              }) => SubjectTagsCompanion.insert(
                tagId: tagId,
                subjectType: subjectType,
                subjectId: subjectId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$SubjectTagsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({tagId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (tagId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.tagId,
                                referencedTable: $$SubjectTagsTableReferences
                                    ._tagIdTable(db),
                                referencedColumn: $$SubjectTagsTableReferences
                                    ._tagIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$SubjectTagsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SubjectTagsTable,
      SubjectTag,
      $$SubjectTagsTableFilterComposer,
      $$SubjectTagsTableOrderingComposer,
      $$SubjectTagsTableAnnotationComposer,
      $$SubjectTagsTableCreateCompanionBuilder,
      $$SubjectTagsTableUpdateCompanionBuilder,
      (SubjectTag, $$SubjectTagsTableReferences),
      SubjectTag,
      PrefetchHooks Function({bool tagId})
    >;
typedef $$SearchQueriesTableCreateCompanionBuilder =
    SearchQueriesCompanion Function({
      Value<int> id,
      required String raw,
      Value<String?> normalizedJson,
      Value<String?> lang,
      Value<DateTime> createdAt,
    });
typedef $$SearchQueriesTableUpdateCompanionBuilder =
    SearchQueriesCompanion Function({
      Value<int> id,
      Value<String> raw,
      Value<String?> normalizedJson,
      Value<String?> lang,
      Value<DateTime> createdAt,
    });

final class $$SearchQueriesTableReferences
    extends BaseReferences<_$AppDatabase, $SearchQueriesTable, SearchQuery> {
  $$SearchQueriesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$SearchFeedbackTable, List<SearchFeedbackData>>
  _searchFeedbackRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.searchFeedback,
    aliasName: 'search_queries__id__search_feedback__query_id',
  );

  $$SearchFeedbackTableProcessedTableManager get searchFeedbackRefs {
    final manager = $$SearchFeedbackTableTableManager(
      $_db,
      $_db.searchFeedback,
    ).filter((f) => f.queryId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_searchFeedbackRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$SearchQueriesTableFilterComposer
    extends Composer<_$AppDatabase, $SearchQueriesTable> {
  $$SearchQueriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get raw => $composableBuilder(
    column: $table.raw,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get normalizedJson => $composableBuilder(
    column: $table.normalizedJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lang => $composableBuilder(
    column: $table.lang,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> searchFeedbackRefs(
    Expression<bool> Function($$SearchFeedbackTableFilterComposer f) f,
  ) {
    final $$SearchFeedbackTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.searchFeedback,
      getReferencedColumn: (t) => t.queryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SearchFeedbackTableFilterComposer(
            $db: $db,
            $table: $db.searchFeedback,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SearchQueriesTableOrderingComposer
    extends Composer<_$AppDatabase, $SearchQueriesTable> {
  $$SearchQueriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get raw => $composableBuilder(
    column: $table.raw,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get normalizedJson => $composableBuilder(
    column: $table.normalizedJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lang => $composableBuilder(
    column: $table.lang,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SearchQueriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SearchQueriesTable> {
  $$SearchQueriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get raw =>
      $composableBuilder(column: $table.raw, builder: (column) => column);

  GeneratedColumn<String> get normalizedJson => $composableBuilder(
    column: $table.normalizedJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lang =>
      $composableBuilder(column: $table.lang, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> searchFeedbackRefs<T extends Object>(
    Expression<T> Function($$SearchFeedbackTableAnnotationComposer a) f,
  ) {
    final $$SearchFeedbackTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.searchFeedback,
      getReferencedColumn: (t) => t.queryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SearchFeedbackTableAnnotationComposer(
            $db: $db,
            $table: $db.searchFeedback,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SearchQueriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SearchQueriesTable,
          SearchQuery,
          $$SearchQueriesTableFilterComposer,
          $$SearchQueriesTableOrderingComposer,
          $$SearchQueriesTableAnnotationComposer,
          $$SearchQueriesTableCreateCompanionBuilder,
          $$SearchQueriesTableUpdateCompanionBuilder,
          (SearchQuery, $$SearchQueriesTableReferences),
          SearchQuery,
          PrefetchHooks Function({bool searchFeedbackRefs})
        > {
  $$SearchQueriesTableTableManager(_$AppDatabase db, $SearchQueriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SearchQueriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SearchQueriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SearchQueriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> raw = const Value.absent(),
                Value<String?> normalizedJson = const Value.absent(),
                Value<String?> lang = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => SearchQueriesCompanion(
                id: id,
                raw: raw,
                normalizedJson: normalizedJson,
                lang: lang,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String raw,
                Value<String?> normalizedJson = const Value.absent(),
                Value<String?> lang = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => SearchQueriesCompanion.insert(
                id: id,
                raw: raw,
                normalizedJson: normalizedJson,
                lang: lang,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$SearchQueriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({searchFeedbackRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (searchFeedbackRefs) db.searchFeedback,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (searchFeedbackRefs)
                    await $_getPrefetchedData<
                      SearchQuery,
                      $SearchQueriesTable,
                      SearchFeedbackData
                    >(
                      currentTable: table,
                      referencedTable: $$SearchQueriesTableReferences
                          ._searchFeedbackRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$SearchQueriesTableReferences(
                            db,
                            table,
                            p0,
                          ).searchFeedbackRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.queryId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$SearchQueriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SearchQueriesTable,
      SearchQuery,
      $$SearchQueriesTableFilterComposer,
      $$SearchQueriesTableOrderingComposer,
      $$SearchQueriesTableAnnotationComposer,
      $$SearchQueriesTableCreateCompanionBuilder,
      $$SearchQueriesTableUpdateCompanionBuilder,
      (SearchQuery, $$SearchQueriesTableReferences),
      SearchQuery,
      PrefetchHooks Function({bool searchFeedbackRefs})
    >;
typedef $$SearchFeedbackTableCreateCompanionBuilder =
    SearchFeedbackCompanion Function({
      Value<int> id,
      required int queryId,
      required String subjectType,
      required int subjectId,
      required String verdict,
      Value<DateTime> createdAt,
    });
typedef $$SearchFeedbackTableUpdateCompanionBuilder =
    SearchFeedbackCompanion Function({
      Value<int> id,
      Value<int> queryId,
      Value<String> subjectType,
      Value<int> subjectId,
      Value<String> verdict,
      Value<DateTime> createdAt,
    });

final class $$SearchFeedbackTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $SearchFeedbackTable,
          SearchFeedbackData
        > {
  $$SearchFeedbackTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $SearchQueriesTable _queryIdTable(_$AppDatabase db) => db.searchQueries
      .createAlias('search_feedback__query_id__search_queries__id');

  $$SearchQueriesTableProcessedTableManager get queryId {
    final $_column = $_itemColumn<int>('query_id')!;

    final manager = $$SearchQueriesTableTableManager(
      $_db,
      $_db.searchQueries,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_queryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$SearchFeedbackTableFilterComposer
    extends Composer<_$AppDatabase, $SearchFeedbackTable> {
  $$SearchFeedbackTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subjectType => $composableBuilder(
    column: $table.subjectType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get subjectId => $composableBuilder(
    column: $table.subjectId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get verdict => $composableBuilder(
    column: $table.verdict,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$SearchQueriesTableFilterComposer get queryId {
    final $$SearchQueriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.queryId,
      referencedTable: $db.searchQueries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SearchQueriesTableFilterComposer(
            $db: $db,
            $table: $db.searchQueries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SearchFeedbackTableOrderingComposer
    extends Composer<_$AppDatabase, $SearchFeedbackTable> {
  $$SearchFeedbackTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subjectType => $composableBuilder(
    column: $table.subjectType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get subjectId => $composableBuilder(
    column: $table.subjectId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get verdict => $composableBuilder(
    column: $table.verdict,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$SearchQueriesTableOrderingComposer get queryId {
    final $$SearchQueriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.queryId,
      referencedTable: $db.searchQueries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SearchQueriesTableOrderingComposer(
            $db: $db,
            $table: $db.searchQueries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SearchFeedbackTableAnnotationComposer
    extends Composer<_$AppDatabase, $SearchFeedbackTable> {
  $$SearchFeedbackTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get subjectType => $composableBuilder(
    column: $table.subjectType,
    builder: (column) => column,
  );

  GeneratedColumn<int> get subjectId =>
      $composableBuilder(column: $table.subjectId, builder: (column) => column);

  GeneratedColumn<String> get verdict =>
      $composableBuilder(column: $table.verdict, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$SearchQueriesTableAnnotationComposer get queryId {
    final $$SearchQueriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.queryId,
      referencedTable: $db.searchQueries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SearchQueriesTableAnnotationComposer(
            $db: $db,
            $table: $db.searchQueries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SearchFeedbackTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SearchFeedbackTable,
          SearchFeedbackData,
          $$SearchFeedbackTableFilterComposer,
          $$SearchFeedbackTableOrderingComposer,
          $$SearchFeedbackTableAnnotationComposer,
          $$SearchFeedbackTableCreateCompanionBuilder,
          $$SearchFeedbackTableUpdateCompanionBuilder,
          (SearchFeedbackData, $$SearchFeedbackTableReferences),
          SearchFeedbackData,
          PrefetchHooks Function({bool queryId})
        > {
  $$SearchFeedbackTableTableManager(
    _$AppDatabase db,
    $SearchFeedbackTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SearchFeedbackTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SearchFeedbackTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SearchFeedbackTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> queryId = const Value.absent(),
                Value<String> subjectType = const Value.absent(),
                Value<int> subjectId = const Value.absent(),
                Value<String> verdict = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => SearchFeedbackCompanion(
                id: id,
                queryId: queryId,
                subjectType: subjectType,
                subjectId: subjectId,
                verdict: verdict,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int queryId,
                required String subjectType,
                required int subjectId,
                required String verdict,
                Value<DateTime> createdAt = const Value.absent(),
              }) => SearchFeedbackCompanion.insert(
                id: id,
                queryId: queryId,
                subjectType: subjectType,
                subjectId: subjectId,
                verdict: verdict,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$SearchFeedbackTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({queryId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (queryId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.queryId,
                                referencedTable: $$SearchFeedbackTableReferences
                                    ._queryIdTable(db),
                                referencedColumn:
                                    $$SearchFeedbackTableReferences
                                        ._queryIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$SearchFeedbackTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SearchFeedbackTable,
      SearchFeedbackData,
      $$SearchFeedbackTableFilterComposer,
      $$SearchFeedbackTableOrderingComposer,
      $$SearchFeedbackTableAnnotationComposer,
      $$SearchFeedbackTableCreateCompanionBuilder,
      $$SearchFeedbackTableUpdateCompanionBuilder,
      (SearchFeedbackData, $$SearchFeedbackTableReferences),
      SearchFeedbackData,
      PrefetchHooks Function({bool queryId})
    >;
typedef $$RankingWeightsTableCreateCompanionBuilder =
    RankingWeightsCompanion Function({
      required String key,
      required double value,
      Value<int> rowid,
    });
typedef $$RankingWeightsTableUpdateCompanionBuilder =
    RankingWeightsCompanion Function({
      Value<String> key,
      Value<double> value,
      Value<int> rowid,
    });

class $$RankingWeightsTableFilterComposer
    extends Composer<_$AppDatabase, $RankingWeightsTable> {
  $$RankingWeightsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RankingWeightsTableOrderingComposer
    extends Composer<_$AppDatabase, $RankingWeightsTable> {
  $$RankingWeightsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RankingWeightsTableAnnotationComposer
    extends Composer<_$AppDatabase, $RankingWeightsTable> {
  $$RankingWeightsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<double> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$RankingWeightsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RankingWeightsTable,
          RankingWeight,
          $$RankingWeightsTableFilterComposer,
          $$RankingWeightsTableOrderingComposer,
          $$RankingWeightsTableAnnotationComposer,
          $$RankingWeightsTableCreateCompanionBuilder,
          $$RankingWeightsTableUpdateCompanionBuilder,
          (
            RankingWeight,
            BaseReferences<_$AppDatabase, $RankingWeightsTable, RankingWeight>,
          ),
          RankingWeight,
          PrefetchHooks Function()
        > {
  $$RankingWeightsTableTableManager(
    _$AppDatabase db,
    $RankingWeightsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RankingWeightsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RankingWeightsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RankingWeightsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<double> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) =>
                  RankingWeightsCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required double value,
                Value<int> rowid = const Value.absent(),
              }) => RankingWeightsCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RankingWeightsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RankingWeightsTable,
      RankingWeight,
      $$RankingWeightsTableFilterComposer,
      $$RankingWeightsTableOrderingComposer,
      $$RankingWeightsTableAnnotationComposer,
      $$RankingWeightsTableCreateCompanionBuilder,
      $$RankingWeightsTableUpdateCompanionBuilder,
      (
        RankingWeight,
        BaseReferences<_$AppDatabase, $RankingWeightsTable, RankingWeight>,
      ),
      RankingWeight,
      PrefetchHooks Function()
    >;
typedef $$DuplicateCandidatesTableCreateCompanionBuilder =
    DuplicateCandidatesCompanion Function({
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> id,
      required String subjectType,
      required int aId,
      required int bId,
      required double score,
      Value<String?> signalsJson,
      Value<String> status,
    });
typedef $$DuplicateCandidatesTableUpdateCompanionBuilder =
    DuplicateCandidatesCompanion Function({
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> id,
      Value<String> subjectType,
      Value<int> aId,
      Value<int> bId,
      Value<double> score,
      Value<String?> signalsJson,
      Value<String> status,
    });

class $$DuplicateCandidatesTableFilterComposer
    extends Composer<_$AppDatabase, $DuplicateCandidatesTable> {
  $$DuplicateCandidatesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subjectType => $composableBuilder(
    column: $table.subjectType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get aId => $composableBuilder(
    column: $table.aId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get bId => $composableBuilder(
    column: $table.bId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get score => $composableBuilder(
    column: $table.score,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get signalsJson => $composableBuilder(
    column: $table.signalsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DuplicateCandidatesTableOrderingComposer
    extends Composer<_$AppDatabase, $DuplicateCandidatesTable> {
  $$DuplicateCandidatesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subjectType => $composableBuilder(
    column: $table.subjectType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get aId => $composableBuilder(
    column: $table.aId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bId => $composableBuilder(
    column: $table.bId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get score => $composableBuilder(
    column: $table.score,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get signalsJson => $composableBuilder(
    column: $table.signalsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DuplicateCandidatesTableAnnotationComposer
    extends Composer<_$AppDatabase, $DuplicateCandidatesTable> {
  $$DuplicateCandidatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get subjectType => $composableBuilder(
    column: $table.subjectType,
    builder: (column) => column,
  );

  GeneratedColumn<int> get aId =>
      $composableBuilder(column: $table.aId, builder: (column) => column);

  GeneratedColumn<int> get bId =>
      $composableBuilder(column: $table.bId, builder: (column) => column);

  GeneratedColumn<double> get score =>
      $composableBuilder(column: $table.score, builder: (column) => column);

  GeneratedColumn<String> get signalsJson => $composableBuilder(
    column: $table.signalsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);
}

class $$DuplicateCandidatesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DuplicateCandidatesTable,
          DuplicateCandidate,
          $$DuplicateCandidatesTableFilterComposer,
          $$DuplicateCandidatesTableOrderingComposer,
          $$DuplicateCandidatesTableAnnotationComposer,
          $$DuplicateCandidatesTableCreateCompanionBuilder,
          $$DuplicateCandidatesTableUpdateCompanionBuilder,
          (
            DuplicateCandidate,
            BaseReferences<
              _$AppDatabase,
              $DuplicateCandidatesTable,
              DuplicateCandidate
            >,
          ),
          DuplicateCandidate,
          PrefetchHooks Function()
        > {
  $$DuplicateCandidatesTableTableManager(
    _$AppDatabase db,
    $DuplicateCandidatesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DuplicateCandidatesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DuplicateCandidatesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$DuplicateCandidatesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> id = const Value.absent(),
                Value<String> subjectType = const Value.absent(),
                Value<int> aId = const Value.absent(),
                Value<int> bId = const Value.absent(),
                Value<double> score = const Value.absent(),
                Value<String?> signalsJson = const Value.absent(),
                Value<String> status = const Value.absent(),
              }) => DuplicateCandidatesCompanion(
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                id: id,
                subjectType: subjectType,
                aId: aId,
                bId: bId,
                score: score,
                signalsJson: signalsJson,
                status: status,
              ),
          createCompanionCallback:
              ({
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> id = const Value.absent(),
                required String subjectType,
                required int aId,
                required int bId,
                required double score,
                Value<String?> signalsJson = const Value.absent(),
                Value<String> status = const Value.absent(),
              }) => DuplicateCandidatesCompanion.insert(
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                id: id,
                subjectType: subjectType,
                aId: aId,
                bId: bId,
                score: score,
                signalsJson: signalsJson,
                status: status,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DuplicateCandidatesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DuplicateCandidatesTable,
      DuplicateCandidate,
      $$DuplicateCandidatesTableFilterComposer,
      $$DuplicateCandidatesTableOrderingComposer,
      $$DuplicateCandidatesTableAnnotationComposer,
      $$DuplicateCandidatesTableCreateCompanionBuilder,
      $$DuplicateCandidatesTableUpdateCompanionBuilder,
      (
        DuplicateCandidate,
        BaseReferences<
          _$AppDatabase,
          $DuplicateCandidatesTable,
          DuplicateCandidate
        >,
      ),
      DuplicateCandidate,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$PeopleTableTableManager get people =>
      $$PeopleTableTableManager(_db, _db.people);
  $$OrganizationsTableTableManager get organizations =>
      $$OrganizationsTableTableManager(_db, _db.organizations);
  $$OrgBranchesTableTableManager get orgBranches =>
      $$OrgBranchesTableTableManager(_db, _db.orgBranches);
  $$RolesTableTableManager get roles =>
      $$RolesTableTableManager(_db, _db.roles);
  $$CardsTableTableManager get cards =>
      $$CardsTableTableManager(_db, _db.cards);
  $$CardFieldsTableTableManager get cardFields =>
      $$CardFieldsTableTableManager(_db, _db.cardFields);
  $$ContactPointsTableTableManager get contactPoints =>
      $$ContactPointsTableTableManager(_db, _db.contactPoints);
  $$OcrBlocksTableTableManager get ocrBlocks =>
      $$OcrBlocksTableTableManager(_db, _db.ocrBlocks);
  $$ExtractionAttemptsTableTableManager get extractionAttempts =>
      $$ExtractionAttemptsTableTableManager(_db, _db.extractionAttempts);
  $$NotesTableTableManager get notes =>
      $$NotesTableTableManager(_db, _db.notes);
  $$AttributesTableTableManager get attributes =>
      $$AttributesTableTableManager(_db, _db.attributes);
  $$CapabilityProfilesTableTableManager get capabilityProfiles =>
      $$CapabilityProfilesTableTableManager(_db, _db.capabilityProfiles);
  $$EmbeddingsTableTableManager get embeddings =>
      $$EmbeddingsTableTableManager(_db, _db.embeddings);
  $$InteractionsTableTableManager get interactions =>
      $$InteractionsTableTableManager(_db, _db.interactions);
  $$TagsTableTableManager get tags => $$TagsTableTableManager(_db, _db.tags);
  $$SubjectTagsTableTableManager get subjectTags =>
      $$SubjectTagsTableTableManager(_db, _db.subjectTags);
  $$SearchQueriesTableTableManager get searchQueries =>
      $$SearchQueriesTableTableManager(_db, _db.searchQueries);
  $$SearchFeedbackTableTableManager get searchFeedback =>
      $$SearchFeedbackTableTableManager(_db, _db.searchFeedback);
  $$RankingWeightsTableTableManager get rankingWeights =>
      $$RankingWeightsTableTableManager(_db, _db.rankingWeights);
  $$DuplicateCandidatesTableTableManager get duplicateCandidates =>
      $$DuplicateCandidatesTableTableManager(_db, _db.duplicateCandidates);
}
