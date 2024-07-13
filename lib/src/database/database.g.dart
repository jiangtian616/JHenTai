// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $OldSuperResolutionInfoTable extends OldSuperResolutionInfo
    with TableInfo<$OldSuperResolutionInfoTable, OldSuperResolutionInfoData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OldSuperResolutionInfoTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _gidMeta = const VerificationMeta('gid');
  @override
  late final GeneratedColumn<int> gid = GeneratedColumn<int>(
      'gid', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<int> type = GeneratedColumn<int>(
      'type', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<int> status = GeneratedColumn<int>(
      'status', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _imageStatusesMeta =
      const VerificationMeta('imageStatuses');
  @override
  late final GeneratedColumn<String> imageStatuses = GeneratedColumn<String>(
      'imageStatuses', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [gid, type, status, imageStatuses];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'super_resolution_info';
  @override
  VerificationContext validateIntegrity(
      Insertable<OldSuperResolutionInfoData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('gid')) {
      context.handle(
          _gidMeta, gid.isAcceptableOrUnknown(data['gid']!, _gidMeta));
    }
    if (data.containsKey('type')) {
      context.handle(
          _typeMeta, type.isAcceptableOrUnknown(data['type']!, _typeMeta));
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('imageStatuses')) {
      context.handle(
          _imageStatusesMeta,
          imageStatuses.isAcceptableOrUnknown(
              data['imageStatuses']!, _imageStatusesMeta));
    } else if (isInserting) {
      context.missing(_imageStatusesMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {gid};
  @override
  OldSuperResolutionInfoData map(Map<String, dynamic> data,
      {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OldSuperResolutionInfoData(
      gid: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}gid'])!,
      type: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}type'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}status'])!,
      imageStatuses: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}imageStatuses'])!,
    );
  }

  @override
  $OldSuperResolutionInfoTable createAlias(String alias) {
    return $OldSuperResolutionInfoTable(attachedDatabase, alias);
  }
}

class OldSuperResolutionInfoData extends DataClass
    implements Insertable<OldSuperResolutionInfoData> {
  final int gid;
  final int type;
  final int status;
  final String imageStatuses;
  const OldSuperResolutionInfoData(
      {required this.gid,
      required this.type,
      required this.status,
      required this.imageStatuses});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['gid'] = Variable<int>(gid);
    map['type'] = Variable<int>(type);
    map['status'] = Variable<int>(status);
    map['imageStatuses'] = Variable<String>(imageStatuses);
    return map;
  }

  OldSuperResolutionInfoCompanion toCompanion(bool nullToAbsent) {
    return OldSuperResolutionInfoCompanion(
      gid: Value(gid),
      type: Value(type),
      status: Value(status),
      imageStatuses: Value(imageStatuses),
    );
  }

  factory OldSuperResolutionInfoData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OldSuperResolutionInfoData(
      gid: serializer.fromJson<int>(json['gid']),
      type: serializer.fromJson<int>(json['type']),
      status: serializer.fromJson<int>(json['status']),
      imageStatuses: serializer.fromJson<String>(json['imageStatuses']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'gid': serializer.toJson<int>(gid),
      'type': serializer.toJson<int>(type),
      'status': serializer.toJson<int>(status),
      'imageStatuses': serializer.toJson<String>(imageStatuses),
    };
  }

  OldSuperResolutionInfoData copyWith(
          {int? gid, int? type, int? status, String? imageStatuses}) =>
      OldSuperResolutionInfoData(
        gid: gid ?? this.gid,
        type: type ?? this.type,
        status: status ?? this.status,
        imageStatuses: imageStatuses ?? this.imageStatuses,
      );
  @override
  String toString() {
    return (StringBuffer('OldSuperResolutionInfoData(')
          ..write('gid: $gid, ')
          ..write('type: $type, ')
          ..write('status: $status, ')
          ..write('imageStatuses: $imageStatuses')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(gid, type, status, imageStatuses);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OldSuperResolutionInfoData &&
          other.gid == this.gid &&
          other.type == this.type &&
          other.status == this.status &&
          other.imageStatuses == this.imageStatuses);
}

class OldSuperResolutionInfoCompanion
    extends UpdateCompanion<OldSuperResolutionInfoData> {
  final Value<int> gid;
  final Value<int> type;
  final Value<int> status;
  final Value<String> imageStatuses;
  const OldSuperResolutionInfoCompanion({
    this.gid = const Value.absent(),
    this.type = const Value.absent(),
    this.status = const Value.absent(),
    this.imageStatuses = const Value.absent(),
  });
  OldSuperResolutionInfoCompanion.insert({
    this.gid = const Value.absent(),
    required int type,
    required int status,
    required String imageStatuses,
  })  : type = Value(type),
        status = Value(status),
        imageStatuses = Value(imageStatuses);
  static Insertable<OldSuperResolutionInfoData> custom({
    Expression<int>? gid,
    Expression<int>? type,
    Expression<int>? status,
    Expression<String>? imageStatuses,
  }) {
    return RawValuesInsertable({
      if (gid != null) 'gid': gid,
      if (type != null) 'type': type,
      if (status != null) 'status': status,
      if (imageStatuses != null) 'imageStatuses': imageStatuses,
    });
  }

  OldSuperResolutionInfoCompanion copyWith(
      {Value<int>? gid,
      Value<int>? type,
      Value<int>? status,
      Value<String>? imageStatuses}) {
    return OldSuperResolutionInfoCompanion(
      gid: gid ?? this.gid,
      type: type ?? this.type,
      status: status ?? this.status,
      imageStatuses: imageStatuses ?? this.imageStatuses,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (gid.present) {
      map['gid'] = Variable<int>(gid.value);
    }
    if (type.present) {
      map['type'] = Variable<int>(type.value);
    }
    if (status.present) {
      map['status'] = Variable<int>(status.value);
    }
    if (imageStatuses.present) {
      map['imageStatuses'] = Variable<String>(imageStatuses.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OldSuperResolutionInfoCompanion(')
          ..write('gid: $gid, ')
          ..write('type: $type, ')
          ..write('status: $status, ')
          ..write('imageStatuses: $imageStatuses')
          ..write(')'))
        .toString();
  }
}

class $SuperResolutionInfoTable extends SuperResolutionInfo
    with TableInfo<$SuperResolutionInfoTable, SuperResolutionInfoData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SuperResolutionInfoTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _gidMeta = const VerificationMeta('gid');
  @override
  late final GeneratedColumn<int> gid = GeneratedColumn<int>(
      'gid', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<int> type = GeneratedColumn<int>(
      'type', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<int> status = GeneratedColumn<int>(
      'status', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _imageStatusesMeta =
      const VerificationMeta('imageStatuses');
  @override
  late final GeneratedColumn<String> imageStatuses = GeneratedColumn<String>(
      'image_statuses', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [gid, type, status, imageStatuses];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'super_resolution_info_v2';
  @override
  VerificationContext validateIntegrity(
      Insertable<SuperResolutionInfoData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('gid')) {
      context.handle(
          _gidMeta, gid.isAcceptableOrUnknown(data['gid']!, _gidMeta));
    } else if (isInserting) {
      context.missing(_gidMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
          _typeMeta, type.isAcceptableOrUnknown(data['type']!, _typeMeta));
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('image_statuses')) {
      context.handle(
          _imageStatusesMeta,
          imageStatuses.isAcceptableOrUnknown(
              data['image_statuses']!, _imageStatusesMeta));
    } else if (isInserting) {
      context.missing(_imageStatusesMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {gid, type};
  @override
  SuperResolutionInfoData map(Map<String, dynamic> data,
      {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SuperResolutionInfoData(
      gid: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}gid'])!,
      type: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}type'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}status'])!,
      imageStatuses: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}image_statuses'])!,
    );
  }

  @override
  $SuperResolutionInfoTable createAlias(String alias) {
    return $SuperResolutionInfoTable(attachedDatabase, alias);
  }
}

class SuperResolutionInfoData extends DataClass
    implements Insertable<SuperResolutionInfoData> {
  final int gid;
  final int type;
  final int status;
  final String imageStatuses;
  const SuperResolutionInfoData(
      {required this.gid,
      required this.type,
      required this.status,
      required this.imageStatuses});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['gid'] = Variable<int>(gid);
    map['type'] = Variable<int>(type);
    map['status'] = Variable<int>(status);
    map['image_statuses'] = Variable<String>(imageStatuses);
    return map;
  }

  SuperResolutionInfoCompanion toCompanion(bool nullToAbsent) {
    return SuperResolutionInfoCompanion(
      gid: Value(gid),
      type: Value(type),
      status: Value(status),
      imageStatuses: Value(imageStatuses),
    );
  }

  factory SuperResolutionInfoData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SuperResolutionInfoData(
      gid: serializer.fromJson<int>(json['gid']),
      type: serializer.fromJson<int>(json['type']),
      status: serializer.fromJson<int>(json['status']),
      imageStatuses: serializer.fromJson<String>(json['imageStatuses']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'gid': serializer.toJson<int>(gid),
      'type': serializer.toJson<int>(type),
      'status': serializer.toJson<int>(status),
      'imageStatuses': serializer.toJson<String>(imageStatuses),
    };
  }

  SuperResolutionInfoData copyWith(
          {int? gid, int? type, int? status, String? imageStatuses}) =>
      SuperResolutionInfoData(
        gid: gid ?? this.gid,
        type: type ?? this.type,
        status: status ?? this.status,
        imageStatuses: imageStatuses ?? this.imageStatuses,
      );
  @override
  String toString() {
    return (StringBuffer('SuperResolutionInfoData(')
          ..write('gid: $gid, ')
          ..write('type: $type, ')
          ..write('status: $status, ')
          ..write('imageStatuses: $imageStatuses')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(gid, type, status, imageStatuses);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SuperResolutionInfoData &&
          other.gid == this.gid &&
          other.type == this.type &&
          other.status == this.status &&
          other.imageStatuses == this.imageStatuses);
}

class SuperResolutionInfoCompanion
    extends UpdateCompanion<SuperResolutionInfoData> {
  final Value<int> gid;
  final Value<int> type;
  final Value<int> status;
  final Value<String> imageStatuses;
  final Value<int> rowid;
  const SuperResolutionInfoCompanion({
    this.gid = const Value.absent(),
    this.type = const Value.absent(),
    this.status = const Value.absent(),
    this.imageStatuses = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SuperResolutionInfoCompanion.insert({
    required int gid,
    required int type,
    required int status,
    required String imageStatuses,
    this.rowid = const Value.absent(),
  })  : gid = Value(gid),
        type = Value(type),
        status = Value(status),
        imageStatuses = Value(imageStatuses);
  static Insertable<SuperResolutionInfoData> custom({
    Expression<int>? gid,
    Expression<int>? type,
    Expression<int>? status,
    Expression<String>? imageStatuses,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (gid != null) 'gid': gid,
      if (type != null) 'type': type,
      if (status != null) 'status': status,
      if (imageStatuses != null) 'image_statuses': imageStatuses,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SuperResolutionInfoCompanion copyWith(
      {Value<int>? gid,
      Value<int>? type,
      Value<int>? status,
      Value<String>? imageStatuses,
      Value<int>? rowid}) {
    return SuperResolutionInfoCompanion(
      gid: gid ?? this.gid,
      type: type ?? this.type,
      status: status ?? this.status,
      imageStatuses: imageStatuses ?? this.imageStatuses,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (gid.present) {
      map['gid'] = Variable<int>(gid.value);
    }
    if (type.present) {
      map['type'] = Variable<int>(type.value);
    }
    if (status.present) {
      map['status'] = Variable<int>(status.value);
    }
    if (imageStatuses.present) {
      map['image_statuses'] = Variable<String>(imageStatuses.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SuperResolutionInfoCompanion(')
          ..write('gid: $gid, ')
          ..write('type: $type, ')
          ..write('status: $status, ')
          ..write('imageStatuses: $imageStatuses, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TagTable extends Tag with TableInfo<$TagTable, TagData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TagTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _namespaceMeta =
      const VerificationMeta('namespace');
  @override
  late final GeneratedColumn<String> namespace = GeneratedColumn<String>(
      'namespace', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
      '_key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _translatedNamespaceMeta =
      const VerificationMeta('translatedNamespace');
  @override
  late final GeneratedColumn<String> translatedNamespace =
      GeneratedColumn<String>('translatedNamespace', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _tagNameMeta =
      const VerificationMeta('tagName');
  @override
  late final GeneratedColumn<String> tagName = GeneratedColumn<String>(
      'tagName', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _fullTagNameMeta =
      const VerificationMeta('fullTagName');
  @override
  late final GeneratedColumn<String> fullTagName = GeneratedColumn<String>(
      'fullTagName', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _introMeta = const VerificationMeta('intro');
  @override
  late final GeneratedColumn<String> intro = GeneratedColumn<String>(
      'intro', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _linksMeta = const VerificationMeta('links');
  @override
  late final GeneratedColumn<String> links = GeneratedColumn<String>(
      'links', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [namespace, key, translatedNamespace, tagName, fullTagName, intro, links];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tag';
  @override
  VerificationContext validateIntegrity(Insertable<TagData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('namespace')) {
      context.handle(_namespaceMeta,
          namespace.isAcceptableOrUnknown(data['namespace']!, _namespaceMeta));
    } else if (isInserting) {
      context.missing(_namespaceMeta);
    }
    if (data.containsKey('_key')) {
      context.handle(
          _keyMeta, key.isAcceptableOrUnknown(data['_key']!, _keyMeta));
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('translatedNamespace')) {
      context.handle(
          _translatedNamespaceMeta,
          translatedNamespace.isAcceptableOrUnknown(
              data['translatedNamespace']!, _translatedNamespaceMeta));
    }
    if (data.containsKey('tagName')) {
      context.handle(_tagNameMeta,
          tagName.isAcceptableOrUnknown(data['tagName']!, _tagNameMeta));
    }
    if (data.containsKey('fullTagName')) {
      context.handle(
          _fullTagNameMeta,
          fullTagName.isAcceptableOrUnknown(
              data['fullTagName']!, _fullTagNameMeta));
    }
    if (data.containsKey('intro')) {
      context.handle(
          _introMeta, intro.isAcceptableOrUnknown(data['intro']!, _introMeta));
    }
    if (data.containsKey('links')) {
      context.handle(
          _linksMeta, links.isAcceptableOrUnknown(data['links']!, _linksMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {namespace, key};
  @override
  TagData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TagData(
      namespace: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}namespace'])!,
      key: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}_key'])!,
      translatedNamespace: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}translatedNamespace']),
      tagName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}tagName']),
      fullTagName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}fullTagName']),
      intro: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}intro']),
      links: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}links']),
    );
  }

  @override
  $TagTable createAlias(String alias) {
    return $TagTable(attachedDatabase, alias);
  }
}

class TagData extends DataClass implements Insertable<TagData> {
  final String namespace;
  final String key;
  final String? translatedNamespace;
  final String? tagName;
  final String? fullTagName;
  final String? intro;
  final String? links;
  const TagData(
      {required this.namespace,
      required this.key,
      this.translatedNamespace,
      this.tagName,
      this.fullTagName,
      this.intro,
      this.links});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['namespace'] = Variable<String>(namespace);
    map['_key'] = Variable<String>(key);
    if (!nullToAbsent || translatedNamespace != null) {
      map['translatedNamespace'] = Variable<String>(translatedNamespace);
    }
    if (!nullToAbsent || tagName != null) {
      map['tagName'] = Variable<String>(tagName);
    }
    if (!nullToAbsent || fullTagName != null) {
      map['fullTagName'] = Variable<String>(fullTagName);
    }
    if (!nullToAbsent || intro != null) {
      map['intro'] = Variable<String>(intro);
    }
    if (!nullToAbsent || links != null) {
      map['links'] = Variable<String>(links);
    }
    return map;
  }

  TagCompanion toCompanion(bool nullToAbsent) {
    return TagCompanion(
      namespace: Value(namespace),
      key: Value(key),
      translatedNamespace: translatedNamespace == null && nullToAbsent
          ? const Value.absent()
          : Value(translatedNamespace),
      tagName: tagName == null && nullToAbsent
          ? const Value.absent()
          : Value(tagName),
      fullTagName: fullTagName == null && nullToAbsent
          ? const Value.absent()
          : Value(fullTagName),
      intro:
          intro == null && nullToAbsent ? const Value.absent() : Value(intro),
      links:
          links == null && nullToAbsent ? const Value.absent() : Value(links),
    );
  }

  factory TagData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TagData(
      namespace: serializer.fromJson<String>(json['namespace']),
      key: serializer.fromJson<String>(json['_key']),
      translatedNamespace:
          serializer.fromJson<String?>(json['translatedNamespace']),
      tagName: serializer.fromJson<String?>(json['tagName']),
      fullTagName: serializer.fromJson<String?>(json['fullTagName']),
      intro: serializer.fromJson<String?>(json['intro']),
      links: serializer.fromJson<String?>(json['links']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'namespace': serializer.toJson<String>(namespace),
      '_key': serializer.toJson<String>(key),
      'translatedNamespace': serializer.toJson<String?>(translatedNamespace),
      'tagName': serializer.toJson<String?>(tagName),
      'fullTagName': serializer.toJson<String?>(fullTagName),
      'intro': serializer.toJson<String?>(intro),
      'links': serializer.toJson<String?>(links),
    };
  }

  TagData copyWith(
          {String? namespace,
          String? key,
          Value<String?> translatedNamespace = const Value.absent(),
          Value<String?> tagName = const Value.absent(),
          Value<String?> fullTagName = const Value.absent(),
          Value<String?> intro = const Value.absent(),
          Value<String?> links = const Value.absent()}) =>
      TagData(
        namespace: namespace ?? this.namespace,
        key: key ?? this.key,
        translatedNamespace: translatedNamespace.present
            ? translatedNamespace.value
            : this.translatedNamespace,
        tagName: tagName.present ? tagName.value : this.tagName,
        fullTagName: fullTagName.present ? fullTagName.value : this.fullTagName,
        intro: intro.present ? intro.value : this.intro,
        links: links.present ? links.value : this.links,
      );
  @override
  String toString() {
    return (StringBuffer('TagData(')
          ..write('namespace: $namespace, ')
          ..write('key: $key, ')
          ..write('translatedNamespace: $translatedNamespace, ')
          ..write('tagName: $tagName, ')
          ..write('fullTagName: $fullTagName, ')
          ..write('intro: $intro, ')
          ..write('links: $links')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      namespace, key, translatedNamespace, tagName, fullTagName, intro, links);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TagData &&
          other.namespace == this.namespace &&
          other.key == this.key &&
          other.translatedNamespace == this.translatedNamespace &&
          other.tagName == this.tagName &&
          other.fullTagName == this.fullTagName &&
          other.intro == this.intro &&
          other.links == this.links);
}

class TagCompanion extends UpdateCompanion<TagData> {
  final Value<String> namespace;
  final Value<String> key;
  final Value<String?> translatedNamespace;
  final Value<String?> tagName;
  final Value<String?> fullTagName;
  final Value<String?> intro;
  final Value<String?> links;
  final Value<int> rowid;
  const TagCompanion({
    this.namespace = const Value.absent(),
    this.key = const Value.absent(),
    this.translatedNamespace = const Value.absent(),
    this.tagName = const Value.absent(),
    this.fullTagName = const Value.absent(),
    this.intro = const Value.absent(),
    this.links = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TagCompanion.insert({
    required String namespace,
    required String key,
    this.translatedNamespace = const Value.absent(),
    this.tagName = const Value.absent(),
    this.fullTagName = const Value.absent(),
    this.intro = const Value.absent(),
    this.links = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : namespace = Value(namespace),
        key = Value(key);
  static Insertable<TagData> custom({
    Expression<String>? namespace,
    Expression<String>? key,
    Expression<String>? translatedNamespace,
    Expression<String>? tagName,
    Expression<String>? fullTagName,
    Expression<String>? intro,
    Expression<String>? links,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (namespace != null) 'namespace': namespace,
      if (key != null) '_key': key,
      if (translatedNamespace != null)
        'translatedNamespace': translatedNamespace,
      if (tagName != null) 'tagName': tagName,
      if (fullTagName != null) 'fullTagName': fullTagName,
      if (intro != null) 'intro': intro,
      if (links != null) 'links': links,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TagCompanion copyWith(
      {Value<String>? namespace,
      Value<String>? key,
      Value<String?>? translatedNamespace,
      Value<String?>? tagName,
      Value<String?>? fullTagName,
      Value<String?>? intro,
      Value<String?>? links,
      Value<int>? rowid}) {
    return TagCompanion(
      namespace: namespace ?? this.namespace,
      key: key ?? this.key,
      translatedNamespace: translatedNamespace ?? this.translatedNamespace,
      tagName: tagName ?? this.tagName,
      fullTagName: fullTagName ?? this.fullTagName,
      intro: intro ?? this.intro,
      links: links ?? this.links,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (namespace.present) {
      map['namespace'] = Variable<String>(namespace.value);
    }
    if (key.present) {
      map['_key'] = Variable<String>(key.value);
    }
    if (translatedNamespace.present) {
      map['translatedNamespace'] = Variable<String>(translatedNamespace.value);
    }
    if (tagName.present) {
      map['tagName'] = Variable<String>(tagName.value);
    }
    if (fullTagName.present) {
      map['fullTagName'] = Variable<String>(fullTagName.value);
    }
    if (intro.present) {
      map['intro'] = Variable<String>(intro.value);
    }
    if (links.present) {
      map['links'] = Variable<String>(links.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TagCompanion(')
          ..write('namespace: $namespace, ')
          ..write('key: $key, ')
          ..write('translatedNamespace: $translatedNamespace, ')
          ..write('tagName: $tagName, ')
          ..write('fullTagName: $fullTagName, ')
          ..write('intro: $intro, ')
          ..write('links: $links, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ArchiveDownloadedTable extends ArchiveDownloaded
    with TableInfo<$ArchiveDownloadedTable, ArchiveDownloadedData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ArchiveDownloadedTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _gidMeta = const VerificationMeta('gid');
  @override
  late final GeneratedColumn<int> gid = GeneratedColumn<int>(
      'gid', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _tokenMeta = const VerificationMeta('token');
  @override
  late final GeneratedColumn<String> token = GeneratedColumn<String>(
      'token', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _categoryMeta =
      const VerificationMeta('category');
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
      'category', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _pageCountMeta =
      const VerificationMeta('pageCount');
  @override
  late final GeneratedColumn<int> pageCount = GeneratedColumn<int>(
      'page_count', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _galleryUrlMeta =
      const VerificationMeta('galleryUrl');
  @override
  late final GeneratedColumn<String> galleryUrl = GeneratedColumn<String>(
      'gallery_url', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _coverUrlMeta =
      const VerificationMeta('coverUrl');
  @override
  late final GeneratedColumn<String> coverUrl = GeneratedColumn<String>(
      'cover_url', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _uploaderMeta =
      const VerificationMeta('uploader');
  @override
  late final GeneratedColumn<String> uploader = GeneratedColumn<String>(
      'uploader', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _sizeMeta = const VerificationMeta('size');
  @override
  late final GeneratedColumn<int> size = GeneratedColumn<int>(
      'size', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _publishTimeMeta =
      const VerificationMeta('publishTime');
  @override
  late final GeneratedColumn<String> publishTime = GeneratedColumn<String>(
      'publish_time', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _archiveStatusCodeMeta =
      const VerificationMeta('archiveStatusCode');
  @override
  late final GeneratedColumn<int> archiveStatusCode = GeneratedColumn<int>(
      'archive_status_index', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _archivePageUrlMeta =
      const VerificationMeta('archivePageUrl');
  @override
  late final GeneratedColumn<String> archivePageUrl = GeneratedColumn<String>(
      'archive_page_url', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _downloadPageUrlMeta =
      const VerificationMeta('downloadPageUrl');
  @override
  late final GeneratedColumn<String> downloadPageUrl = GeneratedColumn<String>(
      'download_page_url', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _downloadUrlMeta =
      const VerificationMeta('downloadUrl');
  @override
  late final GeneratedColumn<String> downloadUrl = GeneratedColumn<String>(
      'download_url', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _isOriginalMeta =
      const VerificationMeta('isOriginal');
  @override
  late final GeneratedColumn<bool> isOriginal = GeneratedColumn<bool>(
      'is_original', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("is_original" IN (0, 1))'));
  static const VerificationMeta _insertTimeMeta =
      const VerificationMeta('insertTime');
  @override
  late final GeneratedColumn<String> insertTime = GeneratedColumn<String>(
      'insert_time', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _sortOrderMeta =
      const VerificationMeta('sortOrder');
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
      'sort_order', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _groupNameMeta =
      const VerificationMeta('groupName');
  @override
  late final GeneratedColumn<String> groupName = GeneratedColumn<String>(
      'group_name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _tagsMeta = const VerificationMeta('tags');
  @override
  late final GeneratedColumn<String> tags = GeneratedColumn<String>(
      'tags', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _tagRefreshTimeMeta =
      const VerificationMeta('tagRefreshTime');
  @override
  late final GeneratedColumn<String> tagRefreshTime = GeneratedColumn<String>(
      'tag_refresh_time', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        gid,
        token,
        title,
        category,
        pageCount,
        galleryUrl,
        coverUrl,
        uploader,
        size,
        publishTime,
        archiveStatusCode,
        archivePageUrl,
        downloadPageUrl,
        downloadUrl,
        isOriginal,
        insertTime,
        sortOrder,
        groupName,
        tags,
        tagRefreshTime
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'archive_downloaded_v2';
  @override
  VerificationContext validateIntegrity(
      Insertable<ArchiveDownloadedData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('gid')) {
      context.handle(
          _gidMeta, gid.isAcceptableOrUnknown(data['gid']!, _gidMeta));
    }
    if (data.containsKey('token')) {
      context.handle(
          _tokenMeta, token.isAcceptableOrUnknown(data['token']!, _tokenMeta));
    } else if (isInserting) {
      context.missing(_tokenMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('category')) {
      context.handle(_categoryMeta,
          category.isAcceptableOrUnknown(data['category']!, _categoryMeta));
    } else if (isInserting) {
      context.missing(_categoryMeta);
    }
    if (data.containsKey('page_count')) {
      context.handle(_pageCountMeta,
          pageCount.isAcceptableOrUnknown(data['page_count']!, _pageCountMeta));
    } else if (isInserting) {
      context.missing(_pageCountMeta);
    }
    if (data.containsKey('gallery_url')) {
      context.handle(
          _galleryUrlMeta,
          galleryUrl.isAcceptableOrUnknown(
              data['gallery_url']!, _galleryUrlMeta));
    } else if (isInserting) {
      context.missing(_galleryUrlMeta);
    }
    if (data.containsKey('cover_url')) {
      context.handle(_coverUrlMeta,
          coverUrl.isAcceptableOrUnknown(data['cover_url']!, _coverUrlMeta));
    } else if (isInserting) {
      context.missing(_coverUrlMeta);
    }
    if (data.containsKey('uploader')) {
      context.handle(_uploaderMeta,
          uploader.isAcceptableOrUnknown(data['uploader']!, _uploaderMeta));
    }
    if (data.containsKey('size')) {
      context.handle(
          _sizeMeta, size.isAcceptableOrUnknown(data['size']!, _sizeMeta));
    } else if (isInserting) {
      context.missing(_sizeMeta);
    }
    if (data.containsKey('publish_time')) {
      context.handle(
          _publishTimeMeta,
          publishTime.isAcceptableOrUnknown(
              data['publish_time']!, _publishTimeMeta));
    } else if (isInserting) {
      context.missing(_publishTimeMeta);
    }
    if (data.containsKey('archive_status_index')) {
      context.handle(
          _archiveStatusCodeMeta,
          archiveStatusCode.isAcceptableOrUnknown(
              data['archive_status_index']!, _archiveStatusCodeMeta));
    } else if (isInserting) {
      context.missing(_archiveStatusCodeMeta);
    }
    if (data.containsKey('archive_page_url')) {
      context.handle(
          _archivePageUrlMeta,
          archivePageUrl.isAcceptableOrUnknown(
              data['archive_page_url']!, _archivePageUrlMeta));
    } else if (isInserting) {
      context.missing(_archivePageUrlMeta);
    }
    if (data.containsKey('download_page_url')) {
      context.handle(
          _downloadPageUrlMeta,
          downloadPageUrl.isAcceptableOrUnknown(
              data['download_page_url']!, _downloadPageUrlMeta));
    }
    if (data.containsKey('download_url')) {
      context.handle(
          _downloadUrlMeta,
          downloadUrl.isAcceptableOrUnknown(
              data['download_url']!, _downloadUrlMeta));
    }
    if (data.containsKey('is_original')) {
      context.handle(
          _isOriginalMeta,
          isOriginal.isAcceptableOrUnknown(
              data['is_original']!, _isOriginalMeta));
    } else if (isInserting) {
      context.missing(_isOriginalMeta);
    }
    if (data.containsKey('insert_time')) {
      context.handle(
          _insertTimeMeta,
          insertTime.isAcceptableOrUnknown(
              data['insert_time']!, _insertTimeMeta));
    } else if (isInserting) {
      context.missing(_insertTimeMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(_sortOrderMeta,
          sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta));
    }
    if (data.containsKey('group_name')) {
      context.handle(_groupNameMeta,
          groupName.isAcceptableOrUnknown(data['group_name']!, _groupNameMeta));
    } else if (isInserting) {
      context.missing(_groupNameMeta);
    }
    if (data.containsKey('tags')) {
      context.handle(
          _tagsMeta, tags.isAcceptableOrUnknown(data['tags']!, _tagsMeta));
    }
    if (data.containsKey('tag_refresh_time')) {
      context.handle(
          _tagRefreshTimeMeta,
          tagRefreshTime.isAcceptableOrUnknown(
              data['tag_refresh_time']!, _tagRefreshTimeMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {gid};
  @override
  ArchiveDownloadedData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ArchiveDownloadedData(
      gid: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}gid'])!,
      token: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}token'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      category: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}category'])!,
      pageCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}page_count'])!,
      galleryUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}gallery_url'])!,
      coverUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}cover_url'])!,
      uploader: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}uploader']),
      size: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}size'])!,
      publishTime: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}publish_time'])!,
      archiveStatusCode: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}archive_status_index'])!,
      archivePageUrl: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}archive_page_url'])!,
      downloadPageUrl: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}download_page_url']),
      downloadUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}download_url']),
      isOriginal: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_original'])!,
      insertTime: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}insert_time'])!,
      sortOrder: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sort_order'])!,
      groupName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}group_name'])!,
      tags: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}tags'])!,
      tagRefreshTime: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}tag_refresh_time']),
    );
  }

  @override
  $ArchiveDownloadedTable createAlias(String alias) {
    return $ArchiveDownloadedTable(attachedDatabase, alias);
  }
}

class ArchiveDownloadedData extends DataClass
    implements Insertable<ArchiveDownloadedData> {
  final int gid;
  final String token;
  final String title;
  final String category;
  final int pageCount;
  final String galleryUrl;
  final String coverUrl;
  final String? uploader;
  final int size;
  final String publishTime;
  final int archiveStatusCode;
  final String archivePageUrl;
  final String? downloadPageUrl;
  final String? downloadUrl;
  final bool isOriginal;
  final String insertTime;
  final int sortOrder;
  final String groupName;
  final String tags;
  final String? tagRefreshTime;
  const ArchiveDownloadedData(
      {required this.gid,
      required this.token,
      required this.title,
      required this.category,
      required this.pageCount,
      required this.galleryUrl,
      required this.coverUrl,
      this.uploader,
      required this.size,
      required this.publishTime,
      required this.archiveStatusCode,
      required this.archivePageUrl,
      this.downloadPageUrl,
      this.downloadUrl,
      required this.isOriginal,
      required this.insertTime,
      required this.sortOrder,
      required this.groupName,
      required this.tags,
      this.tagRefreshTime});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['gid'] = Variable<int>(gid);
    map['token'] = Variable<String>(token);
    map['title'] = Variable<String>(title);
    map['category'] = Variable<String>(category);
    map['page_count'] = Variable<int>(pageCount);
    map['gallery_url'] = Variable<String>(galleryUrl);
    map['cover_url'] = Variable<String>(coverUrl);
    if (!nullToAbsent || uploader != null) {
      map['uploader'] = Variable<String>(uploader);
    }
    map['size'] = Variable<int>(size);
    map['publish_time'] = Variable<String>(publishTime);
    map['archive_status_index'] = Variable<int>(archiveStatusCode);
    map['archive_page_url'] = Variable<String>(archivePageUrl);
    if (!nullToAbsent || downloadPageUrl != null) {
      map['download_page_url'] = Variable<String>(downloadPageUrl);
    }
    if (!nullToAbsent || downloadUrl != null) {
      map['download_url'] = Variable<String>(downloadUrl);
    }
    map['is_original'] = Variable<bool>(isOriginal);
    map['insert_time'] = Variable<String>(insertTime);
    map['sort_order'] = Variable<int>(sortOrder);
    map['group_name'] = Variable<String>(groupName);
    map['tags'] = Variable<String>(tags);
    if (!nullToAbsent || tagRefreshTime != null) {
      map['tag_refresh_time'] = Variable<String>(tagRefreshTime);
    }
    return map;
  }

  ArchiveDownloadedCompanion toCompanion(bool nullToAbsent) {
    return ArchiveDownloadedCompanion(
      gid: Value(gid),
      token: Value(token),
      title: Value(title),
      category: Value(category),
      pageCount: Value(pageCount),
      galleryUrl: Value(galleryUrl),
      coverUrl: Value(coverUrl),
      uploader: uploader == null && nullToAbsent
          ? const Value.absent()
          : Value(uploader),
      size: Value(size),
      publishTime: Value(publishTime),
      archiveStatusCode: Value(archiveStatusCode),
      archivePageUrl: Value(archivePageUrl),
      downloadPageUrl: downloadPageUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(downloadPageUrl),
      downloadUrl: downloadUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(downloadUrl),
      isOriginal: Value(isOriginal),
      insertTime: Value(insertTime),
      sortOrder: Value(sortOrder),
      groupName: Value(groupName),
      tags: Value(tags),
      tagRefreshTime: tagRefreshTime == null && nullToAbsent
          ? const Value.absent()
          : Value(tagRefreshTime),
    );
  }

  factory ArchiveDownloadedData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ArchiveDownloadedData(
      gid: serializer.fromJson<int>(json['gid']),
      token: serializer.fromJson<String>(json['token']),
      title: serializer.fromJson<String>(json['title']),
      category: serializer.fromJson<String>(json['category']),
      pageCount: serializer.fromJson<int>(json['pageCount']),
      galleryUrl: serializer.fromJson<String>(json['galleryUrl']),
      coverUrl: serializer.fromJson<String>(json['coverUrl']),
      uploader: serializer.fromJson<String?>(json['uploader']),
      size: serializer.fromJson<int>(json['size']),
      publishTime: serializer.fromJson<String>(json['publishTime']),
      archiveStatusCode: serializer.fromJson<int>(json['archiveStatusCode']),
      archivePageUrl: serializer.fromJson<String>(json['archivePageUrl']),
      downloadPageUrl: serializer.fromJson<String?>(json['downloadPageUrl']),
      downloadUrl: serializer.fromJson<String?>(json['downloadUrl']),
      isOriginal: serializer.fromJson<bool>(json['isOriginal']),
      insertTime: serializer.fromJson<String>(json['insertTime']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      groupName: serializer.fromJson<String>(json['groupName']),
      tags: serializer.fromJson<String>(json['tags']),
      tagRefreshTime: serializer.fromJson<String?>(json['tagRefreshTime']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'gid': serializer.toJson<int>(gid),
      'token': serializer.toJson<String>(token),
      'title': serializer.toJson<String>(title),
      'category': serializer.toJson<String>(category),
      'pageCount': serializer.toJson<int>(pageCount),
      'galleryUrl': serializer.toJson<String>(galleryUrl),
      'coverUrl': serializer.toJson<String>(coverUrl),
      'uploader': serializer.toJson<String?>(uploader),
      'size': serializer.toJson<int>(size),
      'publishTime': serializer.toJson<String>(publishTime),
      'archiveStatusCode': serializer.toJson<int>(archiveStatusCode),
      'archivePageUrl': serializer.toJson<String>(archivePageUrl),
      'downloadPageUrl': serializer.toJson<String?>(downloadPageUrl),
      'downloadUrl': serializer.toJson<String?>(downloadUrl),
      'isOriginal': serializer.toJson<bool>(isOriginal),
      'insertTime': serializer.toJson<String>(insertTime),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'groupName': serializer.toJson<String>(groupName),
      'tags': serializer.toJson<String>(tags),
      'tagRefreshTime': serializer.toJson<String?>(tagRefreshTime),
    };
  }

  ArchiveDownloadedData copyWith(
          {int? gid,
          String? token,
          String? title,
          String? category,
          int? pageCount,
          String? galleryUrl,
          String? coverUrl,
          Value<String?> uploader = const Value.absent(),
          int? size,
          String? publishTime,
          int? archiveStatusCode,
          String? archivePageUrl,
          Value<String?> downloadPageUrl = const Value.absent(),
          Value<String?> downloadUrl = const Value.absent(),
          bool? isOriginal,
          String? insertTime,
          int? sortOrder,
          String? groupName,
          String? tags,
          Value<String?> tagRefreshTime = const Value.absent()}) =>
      ArchiveDownloadedData(
        gid: gid ?? this.gid,
        token: token ?? this.token,
        title: title ?? this.title,
        category: category ?? this.category,
        pageCount: pageCount ?? this.pageCount,
        galleryUrl: galleryUrl ?? this.galleryUrl,
        coverUrl: coverUrl ?? this.coverUrl,
        uploader: uploader.present ? uploader.value : this.uploader,
        size: size ?? this.size,
        publishTime: publishTime ?? this.publishTime,
        archiveStatusCode: archiveStatusCode ?? this.archiveStatusCode,
        archivePageUrl: archivePageUrl ?? this.archivePageUrl,
        downloadPageUrl: downloadPageUrl.present
            ? downloadPageUrl.value
            : this.downloadPageUrl,
        downloadUrl: downloadUrl.present ? downloadUrl.value : this.downloadUrl,
        isOriginal: isOriginal ?? this.isOriginal,
        insertTime: insertTime ?? this.insertTime,
        sortOrder: sortOrder ?? this.sortOrder,
        groupName: groupName ?? this.groupName,
        tags: tags ?? this.tags,
        tagRefreshTime:
            tagRefreshTime.present ? tagRefreshTime.value : this.tagRefreshTime,
      );
  @override
  String toString() {
    return (StringBuffer('ArchiveDownloadedData(')
          ..write('gid: $gid, ')
          ..write('token: $token, ')
          ..write('title: $title, ')
          ..write('category: $category, ')
          ..write('pageCount: $pageCount, ')
          ..write('galleryUrl: $galleryUrl, ')
          ..write('coverUrl: $coverUrl, ')
          ..write('uploader: $uploader, ')
          ..write('size: $size, ')
          ..write('publishTime: $publishTime, ')
          ..write('archiveStatusCode: $archiveStatusCode, ')
          ..write('archivePageUrl: $archivePageUrl, ')
          ..write('downloadPageUrl: $downloadPageUrl, ')
          ..write('downloadUrl: $downloadUrl, ')
          ..write('isOriginal: $isOriginal, ')
          ..write('insertTime: $insertTime, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('groupName: $groupName, ')
          ..write('tags: $tags, ')
          ..write('tagRefreshTime: $tagRefreshTime')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      gid,
      token,
      title,
      category,
      pageCount,
      galleryUrl,
      coverUrl,
      uploader,
      size,
      publishTime,
      archiveStatusCode,
      archivePageUrl,
      downloadPageUrl,
      downloadUrl,
      isOriginal,
      insertTime,
      sortOrder,
      groupName,
      tags,
      tagRefreshTime);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ArchiveDownloadedData &&
          other.gid == this.gid &&
          other.token == this.token &&
          other.title == this.title &&
          other.category == this.category &&
          other.pageCount == this.pageCount &&
          other.galleryUrl == this.galleryUrl &&
          other.coverUrl == this.coverUrl &&
          other.uploader == this.uploader &&
          other.size == this.size &&
          other.publishTime == this.publishTime &&
          other.archiveStatusCode == this.archiveStatusCode &&
          other.archivePageUrl == this.archivePageUrl &&
          other.downloadPageUrl == this.downloadPageUrl &&
          other.downloadUrl == this.downloadUrl &&
          other.isOriginal == this.isOriginal &&
          other.insertTime == this.insertTime &&
          other.sortOrder == this.sortOrder &&
          other.groupName == this.groupName &&
          other.tags == this.tags &&
          other.tagRefreshTime == this.tagRefreshTime);
}

class ArchiveDownloadedCompanion
    extends UpdateCompanion<ArchiveDownloadedData> {
  final Value<int> gid;
  final Value<String> token;
  final Value<String> title;
  final Value<String> category;
  final Value<int> pageCount;
  final Value<String> galleryUrl;
  final Value<String> coverUrl;
  final Value<String?> uploader;
  final Value<int> size;
  final Value<String> publishTime;
  final Value<int> archiveStatusCode;
  final Value<String> archivePageUrl;
  final Value<String?> downloadPageUrl;
  final Value<String?> downloadUrl;
  final Value<bool> isOriginal;
  final Value<String> insertTime;
  final Value<int> sortOrder;
  final Value<String> groupName;
  final Value<String> tags;
  final Value<String?> tagRefreshTime;
  const ArchiveDownloadedCompanion({
    this.gid = const Value.absent(),
    this.token = const Value.absent(),
    this.title = const Value.absent(),
    this.category = const Value.absent(),
    this.pageCount = const Value.absent(),
    this.galleryUrl = const Value.absent(),
    this.coverUrl = const Value.absent(),
    this.uploader = const Value.absent(),
    this.size = const Value.absent(),
    this.publishTime = const Value.absent(),
    this.archiveStatusCode = const Value.absent(),
    this.archivePageUrl = const Value.absent(),
    this.downloadPageUrl = const Value.absent(),
    this.downloadUrl = const Value.absent(),
    this.isOriginal = const Value.absent(),
    this.insertTime = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.groupName = const Value.absent(),
    this.tags = const Value.absent(),
    this.tagRefreshTime = const Value.absent(),
  });
  ArchiveDownloadedCompanion.insert({
    this.gid = const Value.absent(),
    required String token,
    required String title,
    required String category,
    required int pageCount,
    required String galleryUrl,
    required String coverUrl,
    this.uploader = const Value.absent(),
    required int size,
    required String publishTime,
    required int archiveStatusCode,
    required String archivePageUrl,
    this.downloadPageUrl = const Value.absent(),
    this.downloadUrl = const Value.absent(),
    required bool isOriginal,
    required String insertTime,
    this.sortOrder = const Value.absent(),
    required String groupName,
    this.tags = const Value.absent(),
    this.tagRefreshTime = const Value.absent(),
  })  : token = Value(token),
        title = Value(title),
        category = Value(category),
        pageCount = Value(pageCount),
        galleryUrl = Value(galleryUrl),
        coverUrl = Value(coverUrl),
        size = Value(size),
        publishTime = Value(publishTime),
        archiveStatusCode = Value(archiveStatusCode),
        archivePageUrl = Value(archivePageUrl),
        isOriginal = Value(isOriginal),
        insertTime = Value(insertTime),
        groupName = Value(groupName);
  static Insertable<ArchiveDownloadedData> custom({
    Expression<int>? gid,
    Expression<String>? token,
    Expression<String>? title,
    Expression<String>? category,
    Expression<int>? pageCount,
    Expression<String>? galleryUrl,
    Expression<String>? coverUrl,
    Expression<String>? uploader,
    Expression<int>? size,
    Expression<String>? publishTime,
    Expression<int>? archiveStatusCode,
    Expression<String>? archivePageUrl,
    Expression<String>? downloadPageUrl,
    Expression<String>? downloadUrl,
    Expression<bool>? isOriginal,
    Expression<String>? insertTime,
    Expression<int>? sortOrder,
    Expression<String>? groupName,
    Expression<String>? tags,
    Expression<String>? tagRefreshTime,
  }) {
    return RawValuesInsertable({
      if (gid != null) 'gid': gid,
      if (token != null) 'token': token,
      if (title != null) 'title': title,
      if (category != null) 'category': category,
      if (pageCount != null) 'page_count': pageCount,
      if (galleryUrl != null) 'gallery_url': galleryUrl,
      if (coverUrl != null) 'cover_url': coverUrl,
      if (uploader != null) 'uploader': uploader,
      if (size != null) 'size': size,
      if (publishTime != null) 'publish_time': publishTime,
      if (archiveStatusCode != null) 'archive_status_index': archiveStatusCode,
      if (archivePageUrl != null) 'archive_page_url': archivePageUrl,
      if (downloadPageUrl != null) 'download_page_url': downloadPageUrl,
      if (downloadUrl != null) 'download_url': downloadUrl,
      if (isOriginal != null) 'is_original': isOriginal,
      if (insertTime != null) 'insert_time': insertTime,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (groupName != null) 'group_name': groupName,
      if (tags != null) 'tags': tags,
      if (tagRefreshTime != null) 'tag_refresh_time': tagRefreshTime,
    });
  }

  ArchiveDownloadedCompanion copyWith(
      {Value<int>? gid,
      Value<String>? token,
      Value<String>? title,
      Value<String>? category,
      Value<int>? pageCount,
      Value<String>? galleryUrl,
      Value<String>? coverUrl,
      Value<String?>? uploader,
      Value<int>? size,
      Value<String>? publishTime,
      Value<int>? archiveStatusCode,
      Value<String>? archivePageUrl,
      Value<String?>? downloadPageUrl,
      Value<String?>? downloadUrl,
      Value<bool>? isOriginal,
      Value<String>? insertTime,
      Value<int>? sortOrder,
      Value<String>? groupName,
      Value<String>? tags,
      Value<String?>? tagRefreshTime}) {
    return ArchiveDownloadedCompanion(
      gid: gid ?? this.gid,
      token: token ?? this.token,
      title: title ?? this.title,
      category: category ?? this.category,
      pageCount: pageCount ?? this.pageCount,
      galleryUrl: galleryUrl ?? this.galleryUrl,
      coverUrl: coverUrl ?? this.coverUrl,
      uploader: uploader ?? this.uploader,
      size: size ?? this.size,
      publishTime: publishTime ?? this.publishTime,
      archiveStatusCode: archiveStatusCode ?? this.archiveStatusCode,
      archivePageUrl: archivePageUrl ?? this.archivePageUrl,
      downloadPageUrl: downloadPageUrl ?? this.downloadPageUrl,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      isOriginal: isOriginal ?? this.isOriginal,
      insertTime: insertTime ?? this.insertTime,
      sortOrder: sortOrder ?? this.sortOrder,
      groupName: groupName ?? this.groupName,
      tags: tags ?? this.tags,
      tagRefreshTime: tagRefreshTime ?? this.tagRefreshTime,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (gid.present) {
      map['gid'] = Variable<int>(gid.value);
    }
    if (token.present) {
      map['token'] = Variable<String>(token.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (pageCount.present) {
      map['page_count'] = Variable<int>(pageCount.value);
    }
    if (galleryUrl.present) {
      map['gallery_url'] = Variable<String>(galleryUrl.value);
    }
    if (coverUrl.present) {
      map['cover_url'] = Variable<String>(coverUrl.value);
    }
    if (uploader.present) {
      map['uploader'] = Variable<String>(uploader.value);
    }
    if (size.present) {
      map['size'] = Variable<int>(size.value);
    }
    if (publishTime.present) {
      map['publish_time'] = Variable<String>(publishTime.value);
    }
    if (archiveStatusCode.present) {
      map['archive_status_index'] = Variable<int>(archiveStatusCode.value);
    }
    if (archivePageUrl.present) {
      map['archive_page_url'] = Variable<String>(archivePageUrl.value);
    }
    if (downloadPageUrl.present) {
      map['download_page_url'] = Variable<String>(downloadPageUrl.value);
    }
    if (downloadUrl.present) {
      map['download_url'] = Variable<String>(downloadUrl.value);
    }
    if (isOriginal.present) {
      map['is_original'] = Variable<bool>(isOriginal.value);
    }
    if (insertTime.present) {
      map['insert_time'] = Variable<String>(insertTime.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (groupName.present) {
      map['group_name'] = Variable<String>(groupName.value);
    }
    if (tags.present) {
      map['tags'] = Variable<String>(tags.value);
    }
    if (tagRefreshTime.present) {
      map['tag_refresh_time'] = Variable<String>(tagRefreshTime.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ArchiveDownloadedCompanion(')
          ..write('gid: $gid, ')
          ..write('token: $token, ')
          ..write('title: $title, ')
          ..write('category: $category, ')
          ..write('pageCount: $pageCount, ')
          ..write('galleryUrl: $galleryUrl, ')
          ..write('coverUrl: $coverUrl, ')
          ..write('uploader: $uploader, ')
          ..write('size: $size, ')
          ..write('publishTime: $publishTime, ')
          ..write('archiveStatusCode: $archiveStatusCode, ')
          ..write('archivePageUrl: $archivePageUrl, ')
          ..write('downloadPageUrl: $downloadPageUrl, ')
          ..write('downloadUrl: $downloadUrl, ')
          ..write('isOriginal: $isOriginal, ')
          ..write('insertTime: $insertTime, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('groupName: $groupName, ')
          ..write('tags: $tags, ')
          ..write('tagRefreshTime: $tagRefreshTime')
          ..write(')'))
        .toString();
  }
}

class $ArchiveDownloadedOldTable extends ArchiveDownloadedOld
    with TableInfo<$ArchiveDownloadedOldTable, ArchiveDownloadedOldData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ArchiveDownloadedOldTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _gidMeta = const VerificationMeta('gid');
  @override
  late final GeneratedColumn<int> gid = GeneratedColumn<int>(
      'gid', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _tokenMeta = const VerificationMeta('token');
  @override
  late final GeneratedColumn<String> token = GeneratedColumn<String>(
      'token', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _categoryMeta =
      const VerificationMeta('category');
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
      'category', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _pageCountMeta =
      const VerificationMeta('pageCount');
  @override
  late final GeneratedColumn<int> pageCount = GeneratedColumn<int>(
      'pageCount', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _galleryUrlMeta =
      const VerificationMeta('galleryUrl');
  @override
  late final GeneratedColumn<String> galleryUrl = GeneratedColumn<String>(
      'galleryUrl', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _coverUrlMeta =
      const VerificationMeta('coverUrl');
  @override
  late final GeneratedColumn<String> coverUrl = GeneratedColumn<String>(
      'coverUrl', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _uploaderMeta =
      const VerificationMeta('uploader');
  @override
  late final GeneratedColumn<String> uploader = GeneratedColumn<String>(
      'uploader', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _sizeMeta = const VerificationMeta('size');
  @override
  late final GeneratedColumn<int> size = GeneratedColumn<int>(
      'size', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _publishTimeMeta =
      const VerificationMeta('publishTime');
  @override
  late final GeneratedColumn<String> publishTime = GeneratedColumn<String>(
      'publishTime', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _archiveStatusIndexMeta =
      const VerificationMeta('archiveStatusIndex');
  @override
  late final GeneratedColumn<int> archiveStatusIndex = GeneratedColumn<int>(
      'archiveStatusIndex', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _archivePageUrlMeta =
      const VerificationMeta('archivePageUrl');
  @override
  late final GeneratedColumn<String> archivePageUrl = GeneratedColumn<String>(
      'archivePageUrl', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _downloadPageUrlMeta =
      const VerificationMeta('downloadPageUrl');
  @override
  late final GeneratedColumn<String> downloadPageUrl = GeneratedColumn<String>(
      'downloadPageUrl', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _downloadUrlMeta =
      const VerificationMeta('downloadUrl');
  @override
  late final GeneratedColumn<String> downloadUrl = GeneratedColumn<String>(
      'downloadUrl', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _isOriginalMeta =
      const VerificationMeta('isOriginal');
  @override
  late final GeneratedColumn<bool> isOriginal = GeneratedColumn<bool>(
      'isOriginal', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("isOriginal" IN (0, 1))'));
  static const VerificationMeta _insertTimeMeta =
      const VerificationMeta('insertTime');
  @override
  late final GeneratedColumn<String> insertTime = GeneratedColumn<String>(
      'insertTime', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _sortOrderMeta =
      const VerificationMeta('sortOrder');
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
      'sortOrder', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _groupNameMeta =
      const VerificationMeta('groupName');
  @override
  late final GeneratedColumn<String> groupName = GeneratedColumn<String>(
      'groupName', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        gid,
        token,
        title,
        category,
        pageCount,
        galleryUrl,
        coverUrl,
        uploader,
        size,
        publishTime,
        archiveStatusIndex,
        archivePageUrl,
        downloadPageUrl,
        downloadUrl,
        isOriginal,
        insertTime,
        sortOrder,
        groupName
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'archive_downloaded';
  @override
  VerificationContext validateIntegrity(
      Insertable<ArchiveDownloadedOldData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('gid')) {
      context.handle(
          _gidMeta, gid.isAcceptableOrUnknown(data['gid']!, _gidMeta));
    } else if (isInserting) {
      context.missing(_gidMeta);
    }
    if (data.containsKey('token')) {
      context.handle(
          _tokenMeta, token.isAcceptableOrUnknown(data['token']!, _tokenMeta));
    } else if (isInserting) {
      context.missing(_tokenMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('category')) {
      context.handle(_categoryMeta,
          category.isAcceptableOrUnknown(data['category']!, _categoryMeta));
    } else if (isInserting) {
      context.missing(_categoryMeta);
    }
    if (data.containsKey('pageCount')) {
      context.handle(_pageCountMeta,
          pageCount.isAcceptableOrUnknown(data['pageCount']!, _pageCountMeta));
    } else if (isInserting) {
      context.missing(_pageCountMeta);
    }
    if (data.containsKey('galleryUrl')) {
      context.handle(
          _galleryUrlMeta,
          galleryUrl.isAcceptableOrUnknown(
              data['galleryUrl']!, _galleryUrlMeta));
    } else if (isInserting) {
      context.missing(_galleryUrlMeta);
    }
    if (data.containsKey('coverUrl')) {
      context.handle(_coverUrlMeta,
          coverUrl.isAcceptableOrUnknown(data['coverUrl']!, _coverUrlMeta));
    } else if (isInserting) {
      context.missing(_coverUrlMeta);
    }
    if (data.containsKey('uploader')) {
      context.handle(_uploaderMeta,
          uploader.isAcceptableOrUnknown(data['uploader']!, _uploaderMeta));
    }
    if (data.containsKey('size')) {
      context.handle(
          _sizeMeta, size.isAcceptableOrUnknown(data['size']!, _sizeMeta));
    } else if (isInserting) {
      context.missing(_sizeMeta);
    }
    if (data.containsKey('publishTime')) {
      context.handle(
          _publishTimeMeta,
          publishTime.isAcceptableOrUnknown(
              data['publishTime']!, _publishTimeMeta));
    } else if (isInserting) {
      context.missing(_publishTimeMeta);
    }
    if (data.containsKey('archiveStatusIndex')) {
      context.handle(
          _archiveStatusIndexMeta,
          archiveStatusIndex.isAcceptableOrUnknown(
              data['archiveStatusIndex']!, _archiveStatusIndexMeta));
    } else if (isInserting) {
      context.missing(_archiveStatusIndexMeta);
    }
    if (data.containsKey('archivePageUrl')) {
      context.handle(
          _archivePageUrlMeta,
          archivePageUrl.isAcceptableOrUnknown(
              data['archivePageUrl']!, _archivePageUrlMeta));
    } else if (isInserting) {
      context.missing(_archivePageUrlMeta);
    }
    if (data.containsKey('downloadPageUrl')) {
      context.handle(
          _downloadPageUrlMeta,
          downloadPageUrl.isAcceptableOrUnknown(
              data['downloadPageUrl']!, _downloadPageUrlMeta));
    }
    if (data.containsKey('downloadUrl')) {
      context.handle(
          _downloadUrlMeta,
          downloadUrl.isAcceptableOrUnknown(
              data['downloadUrl']!, _downloadUrlMeta));
    }
    if (data.containsKey('isOriginal')) {
      context.handle(
          _isOriginalMeta,
          isOriginal.isAcceptableOrUnknown(
              data['isOriginal']!, _isOriginalMeta));
    } else if (isInserting) {
      context.missing(_isOriginalMeta);
    }
    if (data.containsKey('insertTime')) {
      context.handle(
          _insertTimeMeta,
          insertTime.isAcceptableOrUnknown(
              data['insertTime']!, _insertTimeMeta));
    }
    if (data.containsKey('sortOrder')) {
      context.handle(_sortOrderMeta,
          sortOrder.isAcceptableOrUnknown(data['sortOrder']!, _sortOrderMeta));
    }
    if (data.containsKey('groupName')) {
      context.handle(_groupNameMeta,
          groupName.isAcceptableOrUnknown(data['groupName']!, _groupNameMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {gid, isOriginal};
  @override
  ArchiveDownloadedOldData map(Map<String, dynamic> data,
      {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ArchiveDownloadedOldData(
      gid: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}gid'])!,
      token: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}token'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      category: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}category'])!,
      pageCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}pageCount'])!,
      galleryUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}galleryUrl'])!,
      coverUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}coverUrl'])!,
      uploader: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}uploader']),
      size: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}size'])!,
      publishTime: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}publishTime'])!,
      archiveStatusIndex: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}archiveStatusIndex'])!,
      archivePageUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}archivePageUrl'])!,
      downloadPageUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}downloadPageUrl']),
      downloadUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}downloadUrl']),
      isOriginal: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}isOriginal'])!,
      insertTime: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}insertTime']),
      sortOrder: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sortOrder'])!,
      groupName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}groupName']),
    );
  }

  @override
  $ArchiveDownloadedOldTable createAlias(String alias) {
    return $ArchiveDownloadedOldTable(attachedDatabase, alias);
  }
}

class ArchiveDownloadedOldData extends DataClass
    implements Insertable<ArchiveDownloadedOldData> {
  final int gid;
  final String token;
  final String title;
  final String category;
  final int pageCount;
  final String galleryUrl;
  final String coverUrl;
  final String? uploader;
  final int size;
  final String publishTime;
  final int archiveStatusIndex;
  final String archivePageUrl;
  final String? downloadPageUrl;
  final String? downloadUrl;
  final bool isOriginal;
  final String? insertTime;
  final int sortOrder;
  final String? groupName;
  const ArchiveDownloadedOldData(
      {required this.gid,
      required this.token,
      required this.title,
      required this.category,
      required this.pageCount,
      required this.galleryUrl,
      required this.coverUrl,
      this.uploader,
      required this.size,
      required this.publishTime,
      required this.archiveStatusIndex,
      required this.archivePageUrl,
      this.downloadPageUrl,
      this.downloadUrl,
      required this.isOriginal,
      this.insertTime,
      required this.sortOrder,
      this.groupName});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['gid'] = Variable<int>(gid);
    map['token'] = Variable<String>(token);
    map['title'] = Variable<String>(title);
    map['category'] = Variable<String>(category);
    map['pageCount'] = Variable<int>(pageCount);
    map['galleryUrl'] = Variable<String>(galleryUrl);
    map['coverUrl'] = Variable<String>(coverUrl);
    if (!nullToAbsent || uploader != null) {
      map['uploader'] = Variable<String>(uploader);
    }
    map['size'] = Variable<int>(size);
    map['publishTime'] = Variable<String>(publishTime);
    map['archiveStatusIndex'] = Variable<int>(archiveStatusIndex);
    map['archivePageUrl'] = Variable<String>(archivePageUrl);
    if (!nullToAbsent || downloadPageUrl != null) {
      map['downloadPageUrl'] = Variable<String>(downloadPageUrl);
    }
    if (!nullToAbsent || downloadUrl != null) {
      map['downloadUrl'] = Variable<String>(downloadUrl);
    }
    map['isOriginal'] = Variable<bool>(isOriginal);
    if (!nullToAbsent || insertTime != null) {
      map['insertTime'] = Variable<String>(insertTime);
    }
    map['sortOrder'] = Variable<int>(sortOrder);
    if (!nullToAbsent || groupName != null) {
      map['groupName'] = Variable<String>(groupName);
    }
    return map;
  }

  ArchiveDownloadedOldCompanion toCompanion(bool nullToAbsent) {
    return ArchiveDownloadedOldCompanion(
      gid: Value(gid),
      token: Value(token),
      title: Value(title),
      category: Value(category),
      pageCount: Value(pageCount),
      galleryUrl: Value(galleryUrl),
      coverUrl: Value(coverUrl),
      uploader: uploader == null && nullToAbsent
          ? const Value.absent()
          : Value(uploader),
      size: Value(size),
      publishTime: Value(publishTime),
      archiveStatusIndex: Value(archiveStatusIndex),
      archivePageUrl: Value(archivePageUrl),
      downloadPageUrl: downloadPageUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(downloadPageUrl),
      downloadUrl: downloadUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(downloadUrl),
      isOriginal: Value(isOriginal),
      insertTime: insertTime == null && nullToAbsent
          ? const Value.absent()
          : Value(insertTime),
      sortOrder: Value(sortOrder),
      groupName: groupName == null && nullToAbsent
          ? const Value.absent()
          : Value(groupName),
    );
  }

  factory ArchiveDownloadedOldData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ArchiveDownloadedOldData(
      gid: serializer.fromJson<int>(json['gid']),
      token: serializer.fromJson<String>(json['token']),
      title: serializer.fromJson<String>(json['title']),
      category: serializer.fromJson<String>(json['category']),
      pageCount: serializer.fromJson<int>(json['pageCount']),
      galleryUrl: serializer.fromJson<String>(json['galleryUrl']),
      coverUrl: serializer.fromJson<String>(json['coverUrl']),
      uploader: serializer.fromJson<String?>(json['uploader']),
      size: serializer.fromJson<int>(json['size']),
      publishTime: serializer.fromJson<String>(json['publishTime']),
      archiveStatusIndex: serializer.fromJson<int>(json['archiveStatusIndex']),
      archivePageUrl: serializer.fromJson<String>(json['archivePageUrl']),
      downloadPageUrl: serializer.fromJson<String?>(json['downloadPageUrl']),
      downloadUrl: serializer.fromJson<String?>(json['downloadUrl']),
      isOriginal: serializer.fromJson<bool>(json['isOriginal']),
      insertTime: serializer.fromJson<String?>(json['insertTime']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      groupName: serializer.fromJson<String?>(json['groupName']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'gid': serializer.toJson<int>(gid),
      'token': serializer.toJson<String>(token),
      'title': serializer.toJson<String>(title),
      'category': serializer.toJson<String>(category),
      'pageCount': serializer.toJson<int>(pageCount),
      'galleryUrl': serializer.toJson<String>(galleryUrl),
      'coverUrl': serializer.toJson<String>(coverUrl),
      'uploader': serializer.toJson<String?>(uploader),
      'size': serializer.toJson<int>(size),
      'publishTime': serializer.toJson<String>(publishTime),
      'archiveStatusIndex': serializer.toJson<int>(archiveStatusIndex),
      'archivePageUrl': serializer.toJson<String>(archivePageUrl),
      'downloadPageUrl': serializer.toJson<String?>(downloadPageUrl),
      'downloadUrl': serializer.toJson<String?>(downloadUrl),
      'isOriginal': serializer.toJson<bool>(isOriginal),
      'insertTime': serializer.toJson<String?>(insertTime),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'groupName': serializer.toJson<String?>(groupName),
    };
  }

  ArchiveDownloadedOldData copyWith(
          {int? gid,
          String? token,
          String? title,
          String? category,
          int? pageCount,
          String? galleryUrl,
          String? coverUrl,
          Value<String?> uploader = const Value.absent(),
          int? size,
          String? publishTime,
          int? archiveStatusIndex,
          String? archivePageUrl,
          Value<String?> downloadPageUrl = const Value.absent(),
          Value<String?> downloadUrl = const Value.absent(),
          bool? isOriginal,
          Value<String?> insertTime = const Value.absent(),
          int? sortOrder,
          Value<String?> groupName = const Value.absent()}) =>
      ArchiveDownloadedOldData(
        gid: gid ?? this.gid,
        token: token ?? this.token,
        title: title ?? this.title,
        category: category ?? this.category,
        pageCount: pageCount ?? this.pageCount,
        galleryUrl: galleryUrl ?? this.galleryUrl,
        coverUrl: coverUrl ?? this.coverUrl,
        uploader: uploader.present ? uploader.value : this.uploader,
        size: size ?? this.size,
        publishTime: publishTime ?? this.publishTime,
        archiveStatusIndex: archiveStatusIndex ?? this.archiveStatusIndex,
        archivePageUrl: archivePageUrl ?? this.archivePageUrl,
        downloadPageUrl: downloadPageUrl.present
            ? downloadPageUrl.value
            : this.downloadPageUrl,
        downloadUrl: downloadUrl.present ? downloadUrl.value : this.downloadUrl,
        isOriginal: isOriginal ?? this.isOriginal,
        insertTime: insertTime.present ? insertTime.value : this.insertTime,
        sortOrder: sortOrder ?? this.sortOrder,
        groupName: groupName.present ? groupName.value : this.groupName,
      );
  @override
  String toString() {
    return (StringBuffer('ArchiveDownloadedOldData(')
          ..write('gid: $gid, ')
          ..write('token: $token, ')
          ..write('title: $title, ')
          ..write('category: $category, ')
          ..write('pageCount: $pageCount, ')
          ..write('galleryUrl: $galleryUrl, ')
          ..write('coverUrl: $coverUrl, ')
          ..write('uploader: $uploader, ')
          ..write('size: $size, ')
          ..write('publishTime: $publishTime, ')
          ..write('archiveStatusIndex: $archiveStatusIndex, ')
          ..write('archivePageUrl: $archivePageUrl, ')
          ..write('downloadPageUrl: $downloadPageUrl, ')
          ..write('downloadUrl: $downloadUrl, ')
          ..write('isOriginal: $isOriginal, ')
          ..write('insertTime: $insertTime, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('groupName: $groupName')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      gid,
      token,
      title,
      category,
      pageCount,
      galleryUrl,
      coverUrl,
      uploader,
      size,
      publishTime,
      archiveStatusIndex,
      archivePageUrl,
      downloadPageUrl,
      downloadUrl,
      isOriginal,
      insertTime,
      sortOrder,
      groupName);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ArchiveDownloadedOldData &&
          other.gid == this.gid &&
          other.token == this.token &&
          other.title == this.title &&
          other.category == this.category &&
          other.pageCount == this.pageCount &&
          other.galleryUrl == this.galleryUrl &&
          other.coverUrl == this.coverUrl &&
          other.uploader == this.uploader &&
          other.size == this.size &&
          other.publishTime == this.publishTime &&
          other.archiveStatusIndex == this.archiveStatusIndex &&
          other.archivePageUrl == this.archivePageUrl &&
          other.downloadPageUrl == this.downloadPageUrl &&
          other.downloadUrl == this.downloadUrl &&
          other.isOriginal == this.isOriginal &&
          other.insertTime == this.insertTime &&
          other.sortOrder == this.sortOrder &&
          other.groupName == this.groupName);
}

class ArchiveDownloadedOldCompanion
    extends UpdateCompanion<ArchiveDownloadedOldData> {
  final Value<int> gid;
  final Value<String> token;
  final Value<String> title;
  final Value<String> category;
  final Value<int> pageCount;
  final Value<String> galleryUrl;
  final Value<String> coverUrl;
  final Value<String?> uploader;
  final Value<int> size;
  final Value<String> publishTime;
  final Value<int> archiveStatusIndex;
  final Value<String> archivePageUrl;
  final Value<String?> downloadPageUrl;
  final Value<String?> downloadUrl;
  final Value<bool> isOriginal;
  final Value<String?> insertTime;
  final Value<int> sortOrder;
  final Value<String?> groupName;
  final Value<int> rowid;
  const ArchiveDownloadedOldCompanion({
    this.gid = const Value.absent(),
    this.token = const Value.absent(),
    this.title = const Value.absent(),
    this.category = const Value.absent(),
    this.pageCount = const Value.absent(),
    this.galleryUrl = const Value.absent(),
    this.coverUrl = const Value.absent(),
    this.uploader = const Value.absent(),
    this.size = const Value.absent(),
    this.publishTime = const Value.absent(),
    this.archiveStatusIndex = const Value.absent(),
    this.archivePageUrl = const Value.absent(),
    this.downloadPageUrl = const Value.absent(),
    this.downloadUrl = const Value.absent(),
    this.isOriginal = const Value.absent(),
    this.insertTime = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.groupName = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ArchiveDownloadedOldCompanion.insert({
    required int gid,
    required String token,
    required String title,
    required String category,
    required int pageCount,
    required String galleryUrl,
    required String coverUrl,
    this.uploader = const Value.absent(),
    required int size,
    required String publishTime,
    required int archiveStatusIndex,
    required String archivePageUrl,
    this.downloadPageUrl = const Value.absent(),
    this.downloadUrl = const Value.absent(),
    required bool isOriginal,
    this.insertTime = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.groupName = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : gid = Value(gid),
        token = Value(token),
        title = Value(title),
        category = Value(category),
        pageCount = Value(pageCount),
        galleryUrl = Value(galleryUrl),
        coverUrl = Value(coverUrl),
        size = Value(size),
        publishTime = Value(publishTime),
        archiveStatusIndex = Value(archiveStatusIndex),
        archivePageUrl = Value(archivePageUrl),
        isOriginal = Value(isOriginal);
  static Insertable<ArchiveDownloadedOldData> custom({
    Expression<int>? gid,
    Expression<String>? token,
    Expression<String>? title,
    Expression<String>? category,
    Expression<int>? pageCount,
    Expression<String>? galleryUrl,
    Expression<String>? coverUrl,
    Expression<String>? uploader,
    Expression<int>? size,
    Expression<String>? publishTime,
    Expression<int>? archiveStatusIndex,
    Expression<String>? archivePageUrl,
    Expression<String>? downloadPageUrl,
    Expression<String>? downloadUrl,
    Expression<bool>? isOriginal,
    Expression<String>? insertTime,
    Expression<int>? sortOrder,
    Expression<String>? groupName,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (gid != null) 'gid': gid,
      if (token != null) 'token': token,
      if (title != null) 'title': title,
      if (category != null) 'category': category,
      if (pageCount != null) 'pageCount': pageCount,
      if (galleryUrl != null) 'galleryUrl': galleryUrl,
      if (coverUrl != null) 'coverUrl': coverUrl,
      if (uploader != null) 'uploader': uploader,
      if (size != null) 'size': size,
      if (publishTime != null) 'publishTime': publishTime,
      if (archiveStatusIndex != null) 'archiveStatusIndex': archiveStatusIndex,
      if (archivePageUrl != null) 'archivePageUrl': archivePageUrl,
      if (downloadPageUrl != null) 'downloadPageUrl': downloadPageUrl,
      if (downloadUrl != null) 'downloadUrl': downloadUrl,
      if (isOriginal != null) 'isOriginal': isOriginal,
      if (insertTime != null) 'insertTime': insertTime,
      if (sortOrder != null) 'sortOrder': sortOrder,
      if (groupName != null) 'groupName': groupName,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ArchiveDownloadedOldCompanion copyWith(
      {Value<int>? gid,
      Value<String>? token,
      Value<String>? title,
      Value<String>? category,
      Value<int>? pageCount,
      Value<String>? galleryUrl,
      Value<String>? coverUrl,
      Value<String?>? uploader,
      Value<int>? size,
      Value<String>? publishTime,
      Value<int>? archiveStatusIndex,
      Value<String>? archivePageUrl,
      Value<String?>? downloadPageUrl,
      Value<String?>? downloadUrl,
      Value<bool>? isOriginal,
      Value<String?>? insertTime,
      Value<int>? sortOrder,
      Value<String?>? groupName,
      Value<int>? rowid}) {
    return ArchiveDownloadedOldCompanion(
      gid: gid ?? this.gid,
      token: token ?? this.token,
      title: title ?? this.title,
      category: category ?? this.category,
      pageCount: pageCount ?? this.pageCount,
      galleryUrl: galleryUrl ?? this.galleryUrl,
      coverUrl: coverUrl ?? this.coverUrl,
      uploader: uploader ?? this.uploader,
      size: size ?? this.size,
      publishTime: publishTime ?? this.publishTime,
      archiveStatusIndex: archiveStatusIndex ?? this.archiveStatusIndex,
      archivePageUrl: archivePageUrl ?? this.archivePageUrl,
      downloadPageUrl: downloadPageUrl ?? this.downloadPageUrl,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      isOriginal: isOriginal ?? this.isOriginal,
      insertTime: insertTime ?? this.insertTime,
      sortOrder: sortOrder ?? this.sortOrder,
      groupName: groupName ?? this.groupName,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (gid.present) {
      map['gid'] = Variable<int>(gid.value);
    }
    if (token.present) {
      map['token'] = Variable<String>(token.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (pageCount.present) {
      map['pageCount'] = Variable<int>(pageCount.value);
    }
    if (galleryUrl.present) {
      map['galleryUrl'] = Variable<String>(galleryUrl.value);
    }
    if (coverUrl.present) {
      map['coverUrl'] = Variable<String>(coverUrl.value);
    }
    if (uploader.present) {
      map['uploader'] = Variable<String>(uploader.value);
    }
    if (size.present) {
      map['size'] = Variable<int>(size.value);
    }
    if (publishTime.present) {
      map['publishTime'] = Variable<String>(publishTime.value);
    }
    if (archiveStatusIndex.present) {
      map['archiveStatusIndex'] = Variable<int>(archiveStatusIndex.value);
    }
    if (archivePageUrl.present) {
      map['archivePageUrl'] = Variable<String>(archivePageUrl.value);
    }
    if (downloadPageUrl.present) {
      map['downloadPageUrl'] = Variable<String>(downloadPageUrl.value);
    }
    if (downloadUrl.present) {
      map['downloadUrl'] = Variable<String>(downloadUrl.value);
    }
    if (isOriginal.present) {
      map['isOriginal'] = Variable<bool>(isOriginal.value);
    }
    if (insertTime.present) {
      map['insertTime'] = Variable<String>(insertTime.value);
    }
    if (sortOrder.present) {
      map['sortOrder'] = Variable<int>(sortOrder.value);
    }
    if (groupName.present) {
      map['groupName'] = Variable<String>(groupName.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ArchiveDownloadedOldCompanion(')
          ..write('gid: $gid, ')
          ..write('token: $token, ')
          ..write('title: $title, ')
          ..write('category: $category, ')
          ..write('pageCount: $pageCount, ')
          ..write('galleryUrl: $galleryUrl, ')
          ..write('coverUrl: $coverUrl, ')
          ..write('uploader: $uploader, ')
          ..write('size: $size, ')
          ..write('publishTime: $publishTime, ')
          ..write('archiveStatusIndex: $archiveStatusIndex, ')
          ..write('archivePageUrl: $archivePageUrl, ')
          ..write('downloadPageUrl: $downloadPageUrl, ')
          ..write('downloadUrl: $downloadUrl, ')
          ..write('isOriginal: $isOriginal, ')
          ..write('insertTime: $insertTime, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('groupName: $groupName, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ArchiveGroupTable extends ArchiveGroup
    with TableInfo<$ArchiveGroupTable, ArchiveGroupData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ArchiveGroupTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _groupNameMeta =
      const VerificationMeta('groupName');
  @override
  late final GeneratedColumn<String> groupName = GeneratedColumn<String>(
      'groupName', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _sortOrderMeta =
      const VerificationMeta('sortOrder');
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
      'sortOrder', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  @override
  List<GeneratedColumn> get $columns => [groupName, sortOrder];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'archive_group';
  @override
  VerificationContext validateIntegrity(Insertable<ArchiveGroupData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('groupName')) {
      context.handle(_groupNameMeta,
          groupName.isAcceptableOrUnknown(data['groupName']!, _groupNameMeta));
    } else if (isInserting) {
      context.missing(_groupNameMeta);
    }
    if (data.containsKey('sortOrder')) {
      context.handle(_sortOrderMeta,
          sortOrder.isAcceptableOrUnknown(data['sortOrder']!, _sortOrderMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {groupName};
  @override
  ArchiveGroupData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ArchiveGroupData(
      groupName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}groupName'])!,
      sortOrder: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sortOrder'])!,
    );
  }

  @override
  $ArchiveGroupTable createAlias(String alias) {
    return $ArchiveGroupTable(attachedDatabase, alias);
  }
}

class ArchiveGroupData extends DataClass
    implements Insertable<ArchiveGroupData> {
  final String groupName;
  final int sortOrder;
  const ArchiveGroupData({required this.groupName, required this.sortOrder});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['groupName'] = Variable<String>(groupName);
    map['sortOrder'] = Variable<int>(sortOrder);
    return map;
  }

  ArchiveGroupCompanion toCompanion(bool nullToAbsent) {
    return ArchiveGroupCompanion(
      groupName: Value(groupName),
      sortOrder: Value(sortOrder),
    );
  }

  factory ArchiveGroupData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ArchiveGroupData(
      groupName: serializer.fromJson<String>(json['groupName']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'groupName': serializer.toJson<String>(groupName),
      'sortOrder': serializer.toJson<int>(sortOrder),
    };
  }

  ArchiveGroupData copyWith({String? groupName, int? sortOrder}) =>
      ArchiveGroupData(
        groupName: groupName ?? this.groupName,
        sortOrder: sortOrder ?? this.sortOrder,
      );
  @override
  String toString() {
    return (StringBuffer('ArchiveGroupData(')
          ..write('groupName: $groupName, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(groupName, sortOrder);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ArchiveGroupData &&
          other.groupName == this.groupName &&
          other.sortOrder == this.sortOrder);
}

class ArchiveGroupCompanion extends UpdateCompanion<ArchiveGroupData> {
  final Value<String> groupName;
  final Value<int> sortOrder;
  final Value<int> rowid;
  const ArchiveGroupCompanion({
    this.groupName = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ArchiveGroupCompanion.insert({
    required String groupName,
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : groupName = Value(groupName);
  static Insertable<ArchiveGroupData> custom({
    Expression<String>? groupName,
    Expression<int>? sortOrder,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (groupName != null) 'groupName': groupName,
      if (sortOrder != null) 'sortOrder': sortOrder,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ArchiveGroupCompanion copyWith(
      {Value<String>? groupName, Value<int>? sortOrder, Value<int>? rowid}) {
    return ArchiveGroupCompanion(
      groupName: groupName ?? this.groupName,
      sortOrder: sortOrder ?? this.sortOrder,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (groupName.present) {
      map['groupName'] = Variable<String>(groupName.value);
    }
    if (sortOrder.present) {
      map['sortOrder'] = Variable<int>(sortOrder.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ArchiveGroupCompanion(')
          ..write('groupName: $groupName, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $GalleryDownloadedTable extends GalleryDownloaded
    with TableInfo<$GalleryDownloadedTable, GalleryDownloadedData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GalleryDownloadedTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _gidMeta = const VerificationMeta('gid');
  @override
  late final GeneratedColumn<int> gid = GeneratedColumn<int>(
      'gid', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _tokenMeta = const VerificationMeta('token');
  @override
  late final GeneratedColumn<String> token = GeneratedColumn<String>(
      'token', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _categoryMeta =
      const VerificationMeta('category');
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
      'category', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _pageCountMeta =
      const VerificationMeta('pageCount');
  @override
  late final GeneratedColumn<int> pageCount = GeneratedColumn<int>(
      'page_count', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _galleryUrlMeta =
      const VerificationMeta('galleryUrl');
  @override
  late final GeneratedColumn<String> galleryUrl = GeneratedColumn<String>(
      'gallery_url', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _oldVersionGalleryUrlMeta =
      const VerificationMeta('oldVersionGalleryUrl');
  @override
  late final GeneratedColumn<String> oldVersionGalleryUrl =
      GeneratedColumn<String>('old_version_gallery_url', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _uploaderMeta =
      const VerificationMeta('uploader');
  @override
  late final GeneratedColumn<String> uploader = GeneratedColumn<String>(
      'uploader', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _publishTimeMeta =
      const VerificationMeta('publishTime');
  @override
  late final GeneratedColumn<String> publishTime = GeneratedColumn<String>(
      'publish_time', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _downloadStatusIndexMeta =
      const VerificationMeta('downloadStatusIndex');
  @override
  late final GeneratedColumn<int> downloadStatusIndex = GeneratedColumn<int>(
      'download_status_index', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _insertTimeMeta =
      const VerificationMeta('insertTime');
  @override
  late final GeneratedColumn<String> insertTime = GeneratedColumn<String>(
      'insert_time', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _downloadOriginalImageMeta =
      const VerificationMeta('downloadOriginalImage');
  @override
  late final GeneratedColumn<bool> downloadOriginalImage =
      GeneratedColumn<bool>('download_original_image', aliasedName, false,
          type: DriftSqlType.bool,
          requiredDuringInsert: false,
          defaultConstraints: GeneratedColumn.constraintIsAlways(
              'CHECK ("download_original_image" IN (0, 1))'),
          defaultValue: const Constant(false));
  static const VerificationMeta _priorityMeta =
      const VerificationMeta('priority');
  @override
  late final GeneratedColumn<int> priority = GeneratedColumn<int>(
      'priority', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _sortOrderMeta =
      const VerificationMeta('sortOrder');
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
      'sort_order', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _groupNameMeta =
      const VerificationMeta('groupName');
  @override
  late final GeneratedColumn<String> groupName = GeneratedColumn<String>(
      'group_name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _tagsMeta = const VerificationMeta('tags');
  @override
  late final GeneratedColumn<String> tags = GeneratedColumn<String>(
      'tags', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _tagRefreshTimeMeta =
      const VerificationMeta('tagRefreshTime');
  @override
  late final GeneratedColumn<String> tagRefreshTime = GeneratedColumn<String>(
      'tag_refresh_time', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        gid,
        token,
        title,
        category,
        pageCount,
        galleryUrl,
        oldVersionGalleryUrl,
        uploader,
        publishTime,
        downloadStatusIndex,
        insertTime,
        downloadOriginalImage,
        priority,
        sortOrder,
        groupName,
        tags,
        tagRefreshTime
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'gallery_downloaded_v2';
  @override
  VerificationContext validateIntegrity(
      Insertable<GalleryDownloadedData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('gid')) {
      context.handle(
          _gidMeta, gid.isAcceptableOrUnknown(data['gid']!, _gidMeta));
    }
    if (data.containsKey('token')) {
      context.handle(
          _tokenMeta, token.isAcceptableOrUnknown(data['token']!, _tokenMeta));
    } else if (isInserting) {
      context.missing(_tokenMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('category')) {
      context.handle(_categoryMeta,
          category.isAcceptableOrUnknown(data['category']!, _categoryMeta));
    } else if (isInserting) {
      context.missing(_categoryMeta);
    }
    if (data.containsKey('page_count')) {
      context.handle(_pageCountMeta,
          pageCount.isAcceptableOrUnknown(data['page_count']!, _pageCountMeta));
    } else if (isInserting) {
      context.missing(_pageCountMeta);
    }
    if (data.containsKey('gallery_url')) {
      context.handle(
          _galleryUrlMeta,
          galleryUrl.isAcceptableOrUnknown(
              data['gallery_url']!, _galleryUrlMeta));
    } else if (isInserting) {
      context.missing(_galleryUrlMeta);
    }
    if (data.containsKey('old_version_gallery_url')) {
      context.handle(
          _oldVersionGalleryUrlMeta,
          oldVersionGalleryUrl.isAcceptableOrUnknown(
              data['old_version_gallery_url']!, _oldVersionGalleryUrlMeta));
    }
    if (data.containsKey('uploader')) {
      context.handle(_uploaderMeta,
          uploader.isAcceptableOrUnknown(data['uploader']!, _uploaderMeta));
    }
    if (data.containsKey('publish_time')) {
      context.handle(
          _publishTimeMeta,
          publishTime.isAcceptableOrUnknown(
              data['publish_time']!, _publishTimeMeta));
    } else if (isInserting) {
      context.missing(_publishTimeMeta);
    }
    if (data.containsKey('download_status_index')) {
      context.handle(
          _downloadStatusIndexMeta,
          downloadStatusIndex.isAcceptableOrUnknown(
              data['download_status_index']!, _downloadStatusIndexMeta));
    } else if (isInserting) {
      context.missing(_downloadStatusIndexMeta);
    }
    if (data.containsKey('insert_time')) {
      context.handle(
          _insertTimeMeta,
          insertTime.isAcceptableOrUnknown(
              data['insert_time']!, _insertTimeMeta));
    } else if (isInserting) {
      context.missing(_insertTimeMeta);
    }
    if (data.containsKey('download_original_image')) {
      context.handle(
          _downloadOriginalImageMeta,
          downloadOriginalImage.isAcceptableOrUnknown(
              data['download_original_image']!, _downloadOriginalImageMeta));
    }
    if (data.containsKey('priority')) {
      context.handle(_priorityMeta,
          priority.isAcceptableOrUnknown(data['priority']!, _priorityMeta));
    } else if (isInserting) {
      context.missing(_priorityMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(_sortOrderMeta,
          sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta));
    }
    if (data.containsKey('group_name')) {
      context.handle(_groupNameMeta,
          groupName.isAcceptableOrUnknown(data['group_name']!, _groupNameMeta));
    } else if (isInserting) {
      context.missing(_groupNameMeta);
    }
    if (data.containsKey('tags')) {
      context.handle(
          _tagsMeta, tags.isAcceptableOrUnknown(data['tags']!, _tagsMeta));
    }
    if (data.containsKey('tag_refresh_time')) {
      context.handle(
          _tagRefreshTimeMeta,
          tagRefreshTime.isAcceptableOrUnknown(
              data['tag_refresh_time']!, _tagRefreshTimeMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {gid};
  @override
  GalleryDownloadedData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GalleryDownloadedData(
      gid: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}gid'])!,
      token: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}token'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      category: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}category'])!,
      pageCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}page_count'])!,
      galleryUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}gallery_url'])!,
      oldVersionGalleryUrl: attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}old_version_gallery_url']),
      uploader: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}uploader']),
      publishTime: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}publish_time'])!,
      downloadStatusIndex: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}download_status_index'])!,
      insertTime: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}insert_time'])!,
      downloadOriginalImage: attachedDatabase.typeMapping.read(
          DriftSqlType.bool,
          data['${effectivePrefix}download_original_image'])!,
      priority: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}priority'])!,
      sortOrder: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sort_order'])!,
      groupName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}group_name'])!,
      tags: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}tags'])!,
      tagRefreshTime: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}tag_refresh_time']),
    );
  }

  @override
  $GalleryDownloadedTable createAlias(String alias) {
    return $GalleryDownloadedTable(attachedDatabase, alias);
  }
}

class GalleryDownloadedData extends DataClass
    implements Insertable<GalleryDownloadedData> {
  final int gid;
  final String token;
  final String title;
  final String category;
  final int pageCount;
  final String galleryUrl;
  final String? oldVersionGalleryUrl;
  final String? uploader;
  final String publishTime;
  final int downloadStatusIndex;
  final String insertTime;
  final bool downloadOriginalImage;
  final int priority;
  final int sortOrder;
  final String groupName;
  final String tags;
  final String? tagRefreshTime;
  const GalleryDownloadedData(
      {required this.gid,
      required this.token,
      required this.title,
      required this.category,
      required this.pageCount,
      required this.galleryUrl,
      this.oldVersionGalleryUrl,
      this.uploader,
      required this.publishTime,
      required this.downloadStatusIndex,
      required this.insertTime,
      required this.downloadOriginalImage,
      required this.priority,
      required this.sortOrder,
      required this.groupName,
      required this.tags,
      this.tagRefreshTime});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['gid'] = Variable<int>(gid);
    map['token'] = Variable<String>(token);
    map['title'] = Variable<String>(title);
    map['category'] = Variable<String>(category);
    map['page_count'] = Variable<int>(pageCount);
    map['gallery_url'] = Variable<String>(galleryUrl);
    if (!nullToAbsent || oldVersionGalleryUrl != null) {
      map['old_version_gallery_url'] = Variable<String>(oldVersionGalleryUrl);
    }
    if (!nullToAbsent || uploader != null) {
      map['uploader'] = Variable<String>(uploader);
    }
    map['publish_time'] = Variable<String>(publishTime);
    map['download_status_index'] = Variable<int>(downloadStatusIndex);
    map['insert_time'] = Variable<String>(insertTime);
    map['download_original_image'] = Variable<bool>(downloadOriginalImage);
    map['priority'] = Variable<int>(priority);
    map['sort_order'] = Variable<int>(sortOrder);
    map['group_name'] = Variable<String>(groupName);
    map['tags'] = Variable<String>(tags);
    if (!nullToAbsent || tagRefreshTime != null) {
      map['tag_refresh_time'] = Variable<String>(tagRefreshTime);
    }
    return map;
  }

  GalleryDownloadedCompanion toCompanion(bool nullToAbsent) {
    return GalleryDownloadedCompanion(
      gid: Value(gid),
      token: Value(token),
      title: Value(title),
      category: Value(category),
      pageCount: Value(pageCount),
      galleryUrl: Value(galleryUrl),
      oldVersionGalleryUrl: oldVersionGalleryUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(oldVersionGalleryUrl),
      uploader: uploader == null && nullToAbsent
          ? const Value.absent()
          : Value(uploader),
      publishTime: Value(publishTime),
      downloadStatusIndex: Value(downloadStatusIndex),
      insertTime: Value(insertTime),
      downloadOriginalImage: Value(downloadOriginalImage),
      priority: Value(priority),
      sortOrder: Value(sortOrder),
      groupName: Value(groupName),
      tags: Value(tags),
      tagRefreshTime: tagRefreshTime == null && nullToAbsent
          ? const Value.absent()
          : Value(tagRefreshTime),
    );
  }

  factory GalleryDownloadedData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GalleryDownloadedData(
      gid: serializer.fromJson<int>(json['gid']),
      token: serializer.fromJson<String>(json['token']),
      title: serializer.fromJson<String>(json['title']),
      category: serializer.fromJson<String>(json['category']),
      pageCount: serializer.fromJson<int>(json['pageCount']),
      galleryUrl: serializer.fromJson<String>(json['galleryUrl']),
      oldVersionGalleryUrl:
          serializer.fromJson<String?>(json['oldVersionGalleryUrl']),
      uploader: serializer.fromJson<String?>(json['uploader']),
      publishTime: serializer.fromJson<String>(json['publishTime']),
      downloadStatusIndex:
          serializer.fromJson<int>(json['downloadStatusIndex']),
      insertTime: serializer.fromJson<String>(json['insertTime']),
      downloadOriginalImage:
          serializer.fromJson<bool>(json['downloadOriginalImage']),
      priority: serializer.fromJson<int>(json['priority']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      groupName: serializer.fromJson<String>(json['groupName']),
      tags: serializer.fromJson<String>(json['tags']),
      tagRefreshTime: serializer.fromJson<String?>(json['tagRefreshTime']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'gid': serializer.toJson<int>(gid),
      'token': serializer.toJson<String>(token),
      'title': serializer.toJson<String>(title),
      'category': serializer.toJson<String>(category),
      'pageCount': serializer.toJson<int>(pageCount),
      'galleryUrl': serializer.toJson<String>(galleryUrl),
      'oldVersionGalleryUrl': serializer.toJson<String?>(oldVersionGalleryUrl),
      'uploader': serializer.toJson<String?>(uploader),
      'publishTime': serializer.toJson<String>(publishTime),
      'downloadStatusIndex': serializer.toJson<int>(downloadStatusIndex),
      'insertTime': serializer.toJson<String>(insertTime),
      'downloadOriginalImage': serializer.toJson<bool>(downloadOriginalImage),
      'priority': serializer.toJson<int>(priority),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'groupName': serializer.toJson<String>(groupName),
      'tags': serializer.toJson<String>(tags),
      'tagRefreshTime': serializer.toJson<String?>(tagRefreshTime),
    };
  }

  GalleryDownloadedData copyWith(
          {int? gid,
          String? token,
          String? title,
          String? category,
          int? pageCount,
          String? galleryUrl,
          Value<String?> oldVersionGalleryUrl = const Value.absent(),
          Value<String?> uploader = const Value.absent(),
          String? publishTime,
          int? downloadStatusIndex,
          String? insertTime,
          bool? downloadOriginalImage,
          int? priority,
          int? sortOrder,
          String? groupName,
          String? tags,
          Value<String?> tagRefreshTime = const Value.absent()}) =>
      GalleryDownloadedData(
        gid: gid ?? this.gid,
        token: token ?? this.token,
        title: title ?? this.title,
        category: category ?? this.category,
        pageCount: pageCount ?? this.pageCount,
        galleryUrl: galleryUrl ?? this.galleryUrl,
        oldVersionGalleryUrl: oldVersionGalleryUrl.present
            ? oldVersionGalleryUrl.value
            : this.oldVersionGalleryUrl,
        uploader: uploader.present ? uploader.value : this.uploader,
        publishTime: publishTime ?? this.publishTime,
        downloadStatusIndex: downloadStatusIndex ?? this.downloadStatusIndex,
        insertTime: insertTime ?? this.insertTime,
        downloadOriginalImage:
            downloadOriginalImage ?? this.downloadOriginalImage,
        priority: priority ?? this.priority,
        sortOrder: sortOrder ?? this.sortOrder,
        groupName: groupName ?? this.groupName,
        tags: tags ?? this.tags,
        tagRefreshTime:
            tagRefreshTime.present ? tagRefreshTime.value : this.tagRefreshTime,
      );
  @override
  String toString() {
    return (StringBuffer('GalleryDownloadedData(')
          ..write('gid: $gid, ')
          ..write('token: $token, ')
          ..write('title: $title, ')
          ..write('category: $category, ')
          ..write('pageCount: $pageCount, ')
          ..write('galleryUrl: $galleryUrl, ')
          ..write('oldVersionGalleryUrl: $oldVersionGalleryUrl, ')
          ..write('uploader: $uploader, ')
          ..write('publishTime: $publishTime, ')
          ..write('downloadStatusIndex: $downloadStatusIndex, ')
          ..write('insertTime: $insertTime, ')
          ..write('downloadOriginalImage: $downloadOriginalImage, ')
          ..write('priority: $priority, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('groupName: $groupName, ')
          ..write('tags: $tags, ')
          ..write('tagRefreshTime: $tagRefreshTime')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      gid,
      token,
      title,
      category,
      pageCount,
      galleryUrl,
      oldVersionGalleryUrl,
      uploader,
      publishTime,
      downloadStatusIndex,
      insertTime,
      downloadOriginalImage,
      priority,
      sortOrder,
      groupName,
      tags,
      tagRefreshTime);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GalleryDownloadedData &&
          other.gid == this.gid &&
          other.token == this.token &&
          other.title == this.title &&
          other.category == this.category &&
          other.pageCount == this.pageCount &&
          other.galleryUrl == this.galleryUrl &&
          other.oldVersionGalleryUrl == this.oldVersionGalleryUrl &&
          other.uploader == this.uploader &&
          other.publishTime == this.publishTime &&
          other.downloadStatusIndex == this.downloadStatusIndex &&
          other.insertTime == this.insertTime &&
          other.downloadOriginalImage == this.downloadOriginalImage &&
          other.priority == this.priority &&
          other.sortOrder == this.sortOrder &&
          other.groupName == this.groupName &&
          other.tags == this.tags &&
          other.tagRefreshTime == this.tagRefreshTime);
}

class GalleryDownloadedCompanion
    extends UpdateCompanion<GalleryDownloadedData> {
  final Value<int> gid;
  final Value<String> token;
  final Value<String> title;
  final Value<String> category;
  final Value<int> pageCount;
  final Value<String> galleryUrl;
  final Value<String?> oldVersionGalleryUrl;
  final Value<String?> uploader;
  final Value<String> publishTime;
  final Value<int> downloadStatusIndex;
  final Value<String> insertTime;
  final Value<bool> downloadOriginalImage;
  final Value<int> priority;
  final Value<int> sortOrder;
  final Value<String> groupName;
  final Value<String> tags;
  final Value<String?> tagRefreshTime;
  const GalleryDownloadedCompanion({
    this.gid = const Value.absent(),
    this.token = const Value.absent(),
    this.title = const Value.absent(),
    this.category = const Value.absent(),
    this.pageCount = const Value.absent(),
    this.galleryUrl = const Value.absent(),
    this.oldVersionGalleryUrl = const Value.absent(),
    this.uploader = const Value.absent(),
    this.publishTime = const Value.absent(),
    this.downloadStatusIndex = const Value.absent(),
    this.insertTime = const Value.absent(),
    this.downloadOriginalImage = const Value.absent(),
    this.priority = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.groupName = const Value.absent(),
    this.tags = const Value.absent(),
    this.tagRefreshTime = const Value.absent(),
  });
  GalleryDownloadedCompanion.insert({
    this.gid = const Value.absent(),
    required String token,
    required String title,
    required String category,
    required int pageCount,
    required String galleryUrl,
    this.oldVersionGalleryUrl = const Value.absent(),
    this.uploader = const Value.absent(),
    required String publishTime,
    required int downloadStatusIndex,
    required String insertTime,
    this.downloadOriginalImage = const Value.absent(),
    required int priority,
    this.sortOrder = const Value.absent(),
    required String groupName,
    this.tags = const Value.absent(),
    this.tagRefreshTime = const Value.absent(),
  })  : token = Value(token),
        title = Value(title),
        category = Value(category),
        pageCount = Value(pageCount),
        galleryUrl = Value(galleryUrl),
        publishTime = Value(publishTime),
        downloadStatusIndex = Value(downloadStatusIndex),
        insertTime = Value(insertTime),
        priority = Value(priority),
        groupName = Value(groupName);
  static Insertable<GalleryDownloadedData> custom({
    Expression<int>? gid,
    Expression<String>? token,
    Expression<String>? title,
    Expression<String>? category,
    Expression<int>? pageCount,
    Expression<String>? galleryUrl,
    Expression<String>? oldVersionGalleryUrl,
    Expression<String>? uploader,
    Expression<String>? publishTime,
    Expression<int>? downloadStatusIndex,
    Expression<String>? insertTime,
    Expression<bool>? downloadOriginalImage,
    Expression<int>? priority,
    Expression<int>? sortOrder,
    Expression<String>? groupName,
    Expression<String>? tags,
    Expression<String>? tagRefreshTime,
  }) {
    return RawValuesInsertable({
      if (gid != null) 'gid': gid,
      if (token != null) 'token': token,
      if (title != null) 'title': title,
      if (category != null) 'category': category,
      if (pageCount != null) 'page_count': pageCount,
      if (galleryUrl != null) 'gallery_url': galleryUrl,
      if (oldVersionGalleryUrl != null)
        'old_version_gallery_url': oldVersionGalleryUrl,
      if (uploader != null) 'uploader': uploader,
      if (publishTime != null) 'publish_time': publishTime,
      if (downloadStatusIndex != null)
        'download_status_index': downloadStatusIndex,
      if (insertTime != null) 'insert_time': insertTime,
      if (downloadOriginalImage != null)
        'download_original_image': downloadOriginalImage,
      if (priority != null) 'priority': priority,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (groupName != null) 'group_name': groupName,
      if (tags != null) 'tags': tags,
      if (tagRefreshTime != null) 'tag_refresh_time': tagRefreshTime,
    });
  }

  GalleryDownloadedCompanion copyWith(
      {Value<int>? gid,
      Value<String>? token,
      Value<String>? title,
      Value<String>? category,
      Value<int>? pageCount,
      Value<String>? galleryUrl,
      Value<String?>? oldVersionGalleryUrl,
      Value<String?>? uploader,
      Value<String>? publishTime,
      Value<int>? downloadStatusIndex,
      Value<String>? insertTime,
      Value<bool>? downloadOriginalImage,
      Value<int>? priority,
      Value<int>? sortOrder,
      Value<String>? groupName,
      Value<String>? tags,
      Value<String?>? tagRefreshTime}) {
    return GalleryDownloadedCompanion(
      gid: gid ?? this.gid,
      token: token ?? this.token,
      title: title ?? this.title,
      category: category ?? this.category,
      pageCount: pageCount ?? this.pageCount,
      galleryUrl: galleryUrl ?? this.galleryUrl,
      oldVersionGalleryUrl: oldVersionGalleryUrl ?? this.oldVersionGalleryUrl,
      uploader: uploader ?? this.uploader,
      publishTime: publishTime ?? this.publishTime,
      downloadStatusIndex: downloadStatusIndex ?? this.downloadStatusIndex,
      insertTime: insertTime ?? this.insertTime,
      downloadOriginalImage:
          downloadOriginalImage ?? this.downloadOriginalImage,
      priority: priority ?? this.priority,
      sortOrder: sortOrder ?? this.sortOrder,
      groupName: groupName ?? this.groupName,
      tags: tags ?? this.tags,
      tagRefreshTime: tagRefreshTime ?? this.tagRefreshTime,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (gid.present) {
      map['gid'] = Variable<int>(gid.value);
    }
    if (token.present) {
      map['token'] = Variable<String>(token.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (pageCount.present) {
      map['page_count'] = Variable<int>(pageCount.value);
    }
    if (galleryUrl.present) {
      map['gallery_url'] = Variable<String>(galleryUrl.value);
    }
    if (oldVersionGalleryUrl.present) {
      map['old_version_gallery_url'] =
          Variable<String>(oldVersionGalleryUrl.value);
    }
    if (uploader.present) {
      map['uploader'] = Variable<String>(uploader.value);
    }
    if (publishTime.present) {
      map['publish_time'] = Variable<String>(publishTime.value);
    }
    if (downloadStatusIndex.present) {
      map['download_status_index'] = Variable<int>(downloadStatusIndex.value);
    }
    if (insertTime.present) {
      map['insert_time'] = Variable<String>(insertTime.value);
    }
    if (downloadOriginalImage.present) {
      map['download_original_image'] =
          Variable<bool>(downloadOriginalImage.value);
    }
    if (priority.present) {
      map['priority'] = Variable<int>(priority.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (groupName.present) {
      map['group_name'] = Variable<String>(groupName.value);
    }
    if (tags.present) {
      map['tags'] = Variable<String>(tags.value);
    }
    if (tagRefreshTime.present) {
      map['tag_refresh_time'] = Variable<String>(tagRefreshTime.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GalleryDownloadedCompanion(')
          ..write('gid: $gid, ')
          ..write('token: $token, ')
          ..write('title: $title, ')
          ..write('category: $category, ')
          ..write('pageCount: $pageCount, ')
          ..write('galleryUrl: $galleryUrl, ')
          ..write('oldVersionGalleryUrl: $oldVersionGalleryUrl, ')
          ..write('uploader: $uploader, ')
          ..write('publishTime: $publishTime, ')
          ..write('downloadStatusIndex: $downloadStatusIndex, ')
          ..write('insertTime: $insertTime, ')
          ..write('downloadOriginalImage: $downloadOriginalImage, ')
          ..write('priority: $priority, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('groupName: $groupName, ')
          ..write('tags: $tags, ')
          ..write('tagRefreshTime: $tagRefreshTime')
          ..write(')'))
        .toString();
  }
}

class $GalleryDownloadedOldTable extends GalleryDownloadedOld
    with TableInfo<$GalleryDownloadedOldTable, GalleryDownloadedOldData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GalleryDownloadedOldTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _gidMeta = const VerificationMeta('gid');
  @override
  late final GeneratedColumn<int> gid = GeneratedColumn<int>(
      'gid', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _tokenMeta = const VerificationMeta('token');
  @override
  late final GeneratedColumn<String> token = GeneratedColumn<String>(
      'token', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _categoryMeta =
      const VerificationMeta('category');
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
      'category', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _pageCountMeta =
      const VerificationMeta('pageCount');
  @override
  late final GeneratedColumn<int> pageCount = GeneratedColumn<int>(
      'pageCount', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _galleryUrlMeta =
      const VerificationMeta('galleryUrl');
  @override
  late final GeneratedColumn<String> galleryUrl = GeneratedColumn<String>(
      'galleryUrl', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _oldVersionGalleryUrlMeta =
      const VerificationMeta('oldVersionGalleryUrl');
  @override
  late final GeneratedColumn<String> oldVersionGalleryUrl =
      GeneratedColumn<String>('oldVersionGalleryUrl', aliasedName, true,
          type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _uploaderMeta =
      const VerificationMeta('uploader');
  @override
  late final GeneratedColumn<String> uploader = GeneratedColumn<String>(
      'uploader', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _publishTimeMeta =
      const VerificationMeta('publishTime');
  @override
  late final GeneratedColumn<String> publishTime = GeneratedColumn<String>(
      'publishTime', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _downloadStatusIndexMeta =
      const VerificationMeta('downloadStatusIndex');
  @override
  late final GeneratedColumn<int> downloadStatusIndex = GeneratedColumn<int>(
      'downloadStatusIndex', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _insertTimeMeta =
      const VerificationMeta('insertTime');
  @override
  late final GeneratedColumn<String> insertTime = GeneratedColumn<String>(
      'insertTime', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _downloadOriginalImageMeta =
      const VerificationMeta('downloadOriginalImage');
  @override
  late final GeneratedColumn<bool> downloadOriginalImage =
      GeneratedColumn<bool>('downloadOriginalImage', aliasedName, false,
          type: DriftSqlType.bool,
          requiredDuringInsert: false,
          defaultConstraints: GeneratedColumn.constraintIsAlways(
              'CHECK ("downloadOriginalImage" IN (0, 1))'),
          defaultValue: const Constant(false));
  static const VerificationMeta _priorityMeta =
      const VerificationMeta('priority');
  @override
  late final GeneratedColumn<int> priority = GeneratedColumn<int>(
      'priority', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _sortOrderMeta =
      const VerificationMeta('sortOrder');
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
      'sortOrder', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _groupNameMeta =
      const VerificationMeta('groupName');
  @override
  late final GeneratedColumn<String> groupName = GeneratedColumn<String>(
      'groupName', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        gid,
        token,
        title,
        category,
        pageCount,
        galleryUrl,
        oldVersionGalleryUrl,
        uploader,
        publishTime,
        downloadStatusIndex,
        insertTime,
        downloadOriginalImage,
        priority,
        sortOrder,
        groupName
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'gallery_downloaded';
  @override
  VerificationContext validateIntegrity(
      Insertable<GalleryDownloadedOldData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('gid')) {
      context.handle(
          _gidMeta, gid.isAcceptableOrUnknown(data['gid']!, _gidMeta));
    }
    if (data.containsKey('token')) {
      context.handle(
          _tokenMeta, token.isAcceptableOrUnknown(data['token']!, _tokenMeta));
    } else if (isInserting) {
      context.missing(_tokenMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('category')) {
      context.handle(_categoryMeta,
          category.isAcceptableOrUnknown(data['category']!, _categoryMeta));
    } else if (isInserting) {
      context.missing(_categoryMeta);
    }
    if (data.containsKey('pageCount')) {
      context.handle(_pageCountMeta,
          pageCount.isAcceptableOrUnknown(data['pageCount']!, _pageCountMeta));
    } else if (isInserting) {
      context.missing(_pageCountMeta);
    }
    if (data.containsKey('galleryUrl')) {
      context.handle(
          _galleryUrlMeta,
          galleryUrl.isAcceptableOrUnknown(
              data['galleryUrl']!, _galleryUrlMeta));
    } else if (isInserting) {
      context.missing(_galleryUrlMeta);
    }
    if (data.containsKey('oldVersionGalleryUrl')) {
      context.handle(
          _oldVersionGalleryUrlMeta,
          oldVersionGalleryUrl.isAcceptableOrUnknown(
              data['oldVersionGalleryUrl']!, _oldVersionGalleryUrlMeta));
    }
    if (data.containsKey('uploader')) {
      context.handle(_uploaderMeta,
          uploader.isAcceptableOrUnknown(data['uploader']!, _uploaderMeta));
    }
    if (data.containsKey('publishTime')) {
      context.handle(
          _publishTimeMeta,
          publishTime.isAcceptableOrUnknown(
              data['publishTime']!, _publishTimeMeta));
    } else if (isInserting) {
      context.missing(_publishTimeMeta);
    }
    if (data.containsKey('downloadStatusIndex')) {
      context.handle(
          _downloadStatusIndexMeta,
          downloadStatusIndex.isAcceptableOrUnknown(
              data['downloadStatusIndex']!, _downloadStatusIndexMeta));
    } else if (isInserting) {
      context.missing(_downloadStatusIndexMeta);
    }
    if (data.containsKey('insertTime')) {
      context.handle(
          _insertTimeMeta,
          insertTime.isAcceptableOrUnknown(
              data['insertTime']!, _insertTimeMeta));
    }
    if (data.containsKey('downloadOriginalImage')) {
      context.handle(
          _downloadOriginalImageMeta,
          downloadOriginalImage.isAcceptableOrUnknown(
              data['downloadOriginalImage']!, _downloadOriginalImageMeta));
    }
    if (data.containsKey('priority')) {
      context.handle(_priorityMeta,
          priority.isAcceptableOrUnknown(data['priority']!, _priorityMeta));
    }
    if (data.containsKey('sortOrder')) {
      context.handle(_sortOrderMeta,
          sortOrder.isAcceptableOrUnknown(data['sortOrder']!, _sortOrderMeta));
    }
    if (data.containsKey('groupName')) {
      context.handle(_groupNameMeta,
          groupName.isAcceptableOrUnknown(data['groupName']!, _groupNameMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {gid};
  @override
  GalleryDownloadedOldData map(Map<String, dynamic> data,
      {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GalleryDownloadedOldData(
      gid: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}gid'])!,
      token: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}token'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      category: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}category'])!,
      pageCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}pageCount'])!,
      galleryUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}galleryUrl'])!,
      oldVersionGalleryUrl: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}oldVersionGalleryUrl']),
      uploader: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}uploader']),
      publishTime: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}publishTime'])!,
      downloadStatusIndex: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}downloadStatusIndex'])!,
      insertTime: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}insertTime']),
      downloadOriginalImage: attachedDatabase.typeMapping.read(
          DriftSqlType.bool, data['${effectivePrefix}downloadOriginalImage'])!,
      priority: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}priority']),
      sortOrder: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sortOrder'])!,
      groupName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}groupName']),
    );
  }

  @override
  $GalleryDownloadedOldTable createAlias(String alias) {
    return $GalleryDownloadedOldTable(attachedDatabase, alias);
  }
}

class GalleryDownloadedOldData extends DataClass
    implements Insertable<GalleryDownloadedOldData> {
  final int gid;
  final String token;
  final String title;
  final String category;
  final int pageCount;
  final String galleryUrl;
  final String? oldVersionGalleryUrl;
  final String? uploader;
  final String publishTime;
  final int downloadStatusIndex;
  final String? insertTime;
  final bool downloadOriginalImage;
  final int? priority;
  final int sortOrder;
  final String? groupName;
  const GalleryDownloadedOldData(
      {required this.gid,
      required this.token,
      required this.title,
      required this.category,
      required this.pageCount,
      required this.galleryUrl,
      this.oldVersionGalleryUrl,
      this.uploader,
      required this.publishTime,
      required this.downloadStatusIndex,
      this.insertTime,
      required this.downloadOriginalImage,
      this.priority,
      required this.sortOrder,
      this.groupName});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['gid'] = Variable<int>(gid);
    map['token'] = Variable<String>(token);
    map['title'] = Variable<String>(title);
    map['category'] = Variable<String>(category);
    map['pageCount'] = Variable<int>(pageCount);
    map['galleryUrl'] = Variable<String>(galleryUrl);
    if (!nullToAbsent || oldVersionGalleryUrl != null) {
      map['oldVersionGalleryUrl'] = Variable<String>(oldVersionGalleryUrl);
    }
    if (!nullToAbsent || uploader != null) {
      map['uploader'] = Variable<String>(uploader);
    }
    map['publishTime'] = Variable<String>(publishTime);
    map['downloadStatusIndex'] = Variable<int>(downloadStatusIndex);
    if (!nullToAbsent || insertTime != null) {
      map['insertTime'] = Variable<String>(insertTime);
    }
    map['downloadOriginalImage'] = Variable<bool>(downloadOriginalImage);
    if (!nullToAbsent || priority != null) {
      map['priority'] = Variable<int>(priority);
    }
    map['sortOrder'] = Variable<int>(sortOrder);
    if (!nullToAbsent || groupName != null) {
      map['groupName'] = Variable<String>(groupName);
    }
    return map;
  }

  GalleryDownloadedOldCompanion toCompanion(bool nullToAbsent) {
    return GalleryDownloadedOldCompanion(
      gid: Value(gid),
      token: Value(token),
      title: Value(title),
      category: Value(category),
      pageCount: Value(pageCount),
      galleryUrl: Value(galleryUrl),
      oldVersionGalleryUrl: oldVersionGalleryUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(oldVersionGalleryUrl),
      uploader: uploader == null && nullToAbsent
          ? const Value.absent()
          : Value(uploader),
      publishTime: Value(publishTime),
      downloadStatusIndex: Value(downloadStatusIndex),
      insertTime: insertTime == null && nullToAbsent
          ? const Value.absent()
          : Value(insertTime),
      downloadOriginalImage: Value(downloadOriginalImage),
      priority: priority == null && nullToAbsent
          ? const Value.absent()
          : Value(priority),
      sortOrder: Value(sortOrder),
      groupName: groupName == null && nullToAbsent
          ? const Value.absent()
          : Value(groupName),
    );
  }

  factory GalleryDownloadedOldData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GalleryDownloadedOldData(
      gid: serializer.fromJson<int>(json['gid']),
      token: serializer.fromJson<String>(json['token']),
      title: serializer.fromJson<String>(json['title']),
      category: serializer.fromJson<String>(json['category']),
      pageCount: serializer.fromJson<int>(json['pageCount']),
      galleryUrl: serializer.fromJson<String>(json['galleryUrl']),
      oldVersionGalleryUrl:
          serializer.fromJson<String?>(json['oldVersionGalleryUrl']),
      uploader: serializer.fromJson<String?>(json['uploader']),
      publishTime: serializer.fromJson<String>(json['publishTime']),
      downloadStatusIndex:
          serializer.fromJson<int>(json['downloadStatusIndex']),
      insertTime: serializer.fromJson<String?>(json['insertTime']),
      downloadOriginalImage:
          serializer.fromJson<bool>(json['downloadOriginalImage']),
      priority: serializer.fromJson<int?>(json['priority']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      groupName: serializer.fromJson<String?>(json['groupName']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'gid': serializer.toJson<int>(gid),
      'token': serializer.toJson<String>(token),
      'title': serializer.toJson<String>(title),
      'category': serializer.toJson<String>(category),
      'pageCount': serializer.toJson<int>(pageCount),
      'galleryUrl': serializer.toJson<String>(galleryUrl),
      'oldVersionGalleryUrl': serializer.toJson<String?>(oldVersionGalleryUrl),
      'uploader': serializer.toJson<String?>(uploader),
      'publishTime': serializer.toJson<String>(publishTime),
      'downloadStatusIndex': serializer.toJson<int>(downloadStatusIndex),
      'insertTime': serializer.toJson<String?>(insertTime),
      'downloadOriginalImage': serializer.toJson<bool>(downloadOriginalImage),
      'priority': serializer.toJson<int?>(priority),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'groupName': serializer.toJson<String?>(groupName),
    };
  }

  GalleryDownloadedOldData copyWith(
          {int? gid,
          String? token,
          String? title,
          String? category,
          int? pageCount,
          String? galleryUrl,
          Value<String?> oldVersionGalleryUrl = const Value.absent(),
          Value<String?> uploader = const Value.absent(),
          String? publishTime,
          int? downloadStatusIndex,
          Value<String?> insertTime = const Value.absent(),
          bool? downloadOriginalImage,
          Value<int?> priority = const Value.absent(),
          int? sortOrder,
          Value<String?> groupName = const Value.absent()}) =>
      GalleryDownloadedOldData(
        gid: gid ?? this.gid,
        token: token ?? this.token,
        title: title ?? this.title,
        category: category ?? this.category,
        pageCount: pageCount ?? this.pageCount,
        galleryUrl: galleryUrl ?? this.galleryUrl,
        oldVersionGalleryUrl: oldVersionGalleryUrl.present
            ? oldVersionGalleryUrl.value
            : this.oldVersionGalleryUrl,
        uploader: uploader.present ? uploader.value : this.uploader,
        publishTime: publishTime ?? this.publishTime,
        downloadStatusIndex: downloadStatusIndex ?? this.downloadStatusIndex,
        insertTime: insertTime.present ? insertTime.value : this.insertTime,
        downloadOriginalImage:
            downloadOriginalImage ?? this.downloadOriginalImage,
        priority: priority.present ? priority.value : this.priority,
        sortOrder: sortOrder ?? this.sortOrder,
        groupName: groupName.present ? groupName.value : this.groupName,
      );
  @override
  String toString() {
    return (StringBuffer('GalleryDownloadedOldData(')
          ..write('gid: $gid, ')
          ..write('token: $token, ')
          ..write('title: $title, ')
          ..write('category: $category, ')
          ..write('pageCount: $pageCount, ')
          ..write('galleryUrl: $galleryUrl, ')
          ..write('oldVersionGalleryUrl: $oldVersionGalleryUrl, ')
          ..write('uploader: $uploader, ')
          ..write('publishTime: $publishTime, ')
          ..write('downloadStatusIndex: $downloadStatusIndex, ')
          ..write('insertTime: $insertTime, ')
          ..write('downloadOriginalImage: $downloadOriginalImage, ')
          ..write('priority: $priority, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('groupName: $groupName')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      gid,
      token,
      title,
      category,
      pageCount,
      galleryUrl,
      oldVersionGalleryUrl,
      uploader,
      publishTime,
      downloadStatusIndex,
      insertTime,
      downloadOriginalImage,
      priority,
      sortOrder,
      groupName);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GalleryDownloadedOldData &&
          other.gid == this.gid &&
          other.token == this.token &&
          other.title == this.title &&
          other.category == this.category &&
          other.pageCount == this.pageCount &&
          other.galleryUrl == this.galleryUrl &&
          other.oldVersionGalleryUrl == this.oldVersionGalleryUrl &&
          other.uploader == this.uploader &&
          other.publishTime == this.publishTime &&
          other.downloadStatusIndex == this.downloadStatusIndex &&
          other.insertTime == this.insertTime &&
          other.downloadOriginalImage == this.downloadOriginalImage &&
          other.priority == this.priority &&
          other.sortOrder == this.sortOrder &&
          other.groupName == this.groupName);
}

class GalleryDownloadedOldCompanion
    extends UpdateCompanion<GalleryDownloadedOldData> {
  final Value<int> gid;
  final Value<String> token;
  final Value<String> title;
  final Value<String> category;
  final Value<int> pageCount;
  final Value<String> galleryUrl;
  final Value<String?> oldVersionGalleryUrl;
  final Value<String?> uploader;
  final Value<String> publishTime;
  final Value<int> downloadStatusIndex;
  final Value<String?> insertTime;
  final Value<bool> downloadOriginalImage;
  final Value<int?> priority;
  final Value<int> sortOrder;
  final Value<String?> groupName;
  const GalleryDownloadedOldCompanion({
    this.gid = const Value.absent(),
    this.token = const Value.absent(),
    this.title = const Value.absent(),
    this.category = const Value.absent(),
    this.pageCount = const Value.absent(),
    this.galleryUrl = const Value.absent(),
    this.oldVersionGalleryUrl = const Value.absent(),
    this.uploader = const Value.absent(),
    this.publishTime = const Value.absent(),
    this.downloadStatusIndex = const Value.absent(),
    this.insertTime = const Value.absent(),
    this.downloadOriginalImage = const Value.absent(),
    this.priority = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.groupName = const Value.absent(),
  });
  GalleryDownloadedOldCompanion.insert({
    this.gid = const Value.absent(),
    required String token,
    required String title,
    required String category,
    required int pageCount,
    required String galleryUrl,
    this.oldVersionGalleryUrl = const Value.absent(),
    this.uploader = const Value.absent(),
    required String publishTime,
    required int downloadStatusIndex,
    this.insertTime = const Value.absent(),
    this.downloadOriginalImage = const Value.absent(),
    this.priority = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.groupName = const Value.absent(),
  })  : token = Value(token),
        title = Value(title),
        category = Value(category),
        pageCount = Value(pageCount),
        galleryUrl = Value(galleryUrl),
        publishTime = Value(publishTime),
        downloadStatusIndex = Value(downloadStatusIndex);
  static Insertable<GalleryDownloadedOldData> custom({
    Expression<int>? gid,
    Expression<String>? token,
    Expression<String>? title,
    Expression<String>? category,
    Expression<int>? pageCount,
    Expression<String>? galleryUrl,
    Expression<String>? oldVersionGalleryUrl,
    Expression<String>? uploader,
    Expression<String>? publishTime,
    Expression<int>? downloadStatusIndex,
    Expression<String>? insertTime,
    Expression<bool>? downloadOriginalImage,
    Expression<int>? priority,
    Expression<int>? sortOrder,
    Expression<String>? groupName,
  }) {
    return RawValuesInsertable({
      if (gid != null) 'gid': gid,
      if (token != null) 'token': token,
      if (title != null) 'title': title,
      if (category != null) 'category': category,
      if (pageCount != null) 'pageCount': pageCount,
      if (galleryUrl != null) 'galleryUrl': galleryUrl,
      if (oldVersionGalleryUrl != null)
        'oldVersionGalleryUrl': oldVersionGalleryUrl,
      if (uploader != null) 'uploader': uploader,
      if (publishTime != null) 'publishTime': publishTime,
      if (downloadStatusIndex != null)
        'downloadStatusIndex': downloadStatusIndex,
      if (insertTime != null) 'insertTime': insertTime,
      if (downloadOriginalImage != null)
        'downloadOriginalImage': downloadOriginalImage,
      if (priority != null) 'priority': priority,
      if (sortOrder != null) 'sortOrder': sortOrder,
      if (groupName != null) 'groupName': groupName,
    });
  }

  GalleryDownloadedOldCompanion copyWith(
      {Value<int>? gid,
      Value<String>? token,
      Value<String>? title,
      Value<String>? category,
      Value<int>? pageCount,
      Value<String>? galleryUrl,
      Value<String?>? oldVersionGalleryUrl,
      Value<String?>? uploader,
      Value<String>? publishTime,
      Value<int>? downloadStatusIndex,
      Value<String?>? insertTime,
      Value<bool>? downloadOriginalImage,
      Value<int?>? priority,
      Value<int>? sortOrder,
      Value<String?>? groupName}) {
    return GalleryDownloadedOldCompanion(
      gid: gid ?? this.gid,
      token: token ?? this.token,
      title: title ?? this.title,
      category: category ?? this.category,
      pageCount: pageCount ?? this.pageCount,
      galleryUrl: galleryUrl ?? this.galleryUrl,
      oldVersionGalleryUrl: oldVersionGalleryUrl ?? this.oldVersionGalleryUrl,
      uploader: uploader ?? this.uploader,
      publishTime: publishTime ?? this.publishTime,
      downloadStatusIndex: downloadStatusIndex ?? this.downloadStatusIndex,
      insertTime: insertTime ?? this.insertTime,
      downloadOriginalImage:
          downloadOriginalImage ?? this.downloadOriginalImage,
      priority: priority ?? this.priority,
      sortOrder: sortOrder ?? this.sortOrder,
      groupName: groupName ?? this.groupName,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (gid.present) {
      map['gid'] = Variable<int>(gid.value);
    }
    if (token.present) {
      map['token'] = Variable<String>(token.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (pageCount.present) {
      map['pageCount'] = Variable<int>(pageCount.value);
    }
    if (galleryUrl.present) {
      map['galleryUrl'] = Variable<String>(galleryUrl.value);
    }
    if (oldVersionGalleryUrl.present) {
      map['oldVersionGalleryUrl'] =
          Variable<String>(oldVersionGalleryUrl.value);
    }
    if (uploader.present) {
      map['uploader'] = Variable<String>(uploader.value);
    }
    if (publishTime.present) {
      map['publishTime'] = Variable<String>(publishTime.value);
    }
    if (downloadStatusIndex.present) {
      map['downloadStatusIndex'] = Variable<int>(downloadStatusIndex.value);
    }
    if (insertTime.present) {
      map['insertTime'] = Variable<String>(insertTime.value);
    }
    if (downloadOriginalImage.present) {
      map['downloadOriginalImage'] =
          Variable<bool>(downloadOriginalImage.value);
    }
    if (priority.present) {
      map['priority'] = Variable<int>(priority.value);
    }
    if (sortOrder.present) {
      map['sortOrder'] = Variable<int>(sortOrder.value);
    }
    if (groupName.present) {
      map['groupName'] = Variable<String>(groupName.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GalleryDownloadedOldCompanion(')
          ..write('gid: $gid, ')
          ..write('token: $token, ')
          ..write('title: $title, ')
          ..write('category: $category, ')
          ..write('pageCount: $pageCount, ')
          ..write('galleryUrl: $galleryUrl, ')
          ..write('oldVersionGalleryUrl: $oldVersionGalleryUrl, ')
          ..write('uploader: $uploader, ')
          ..write('publishTime: $publishTime, ')
          ..write('downloadStatusIndex: $downloadStatusIndex, ')
          ..write('insertTime: $insertTime, ')
          ..write('downloadOriginalImage: $downloadOriginalImage, ')
          ..write('priority: $priority, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('groupName: $groupName')
          ..write(')'))
        .toString();
  }
}

class $GalleryGroupTable extends GalleryGroup
    with TableInfo<$GalleryGroupTable, GalleryGroupData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GalleryGroupTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _groupNameMeta =
      const VerificationMeta('groupName');
  @override
  late final GeneratedColumn<String> groupName = GeneratedColumn<String>(
      'groupName', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _sortOrderMeta =
      const VerificationMeta('sortOrder');
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
      'sortOrder', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  @override
  List<GeneratedColumn> get $columns => [groupName, sortOrder];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'gallery_group';
  @override
  VerificationContext validateIntegrity(Insertable<GalleryGroupData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('groupName')) {
      context.handle(_groupNameMeta,
          groupName.isAcceptableOrUnknown(data['groupName']!, _groupNameMeta));
    } else if (isInserting) {
      context.missing(_groupNameMeta);
    }
    if (data.containsKey('sortOrder')) {
      context.handle(_sortOrderMeta,
          sortOrder.isAcceptableOrUnknown(data['sortOrder']!, _sortOrderMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {groupName};
  @override
  GalleryGroupData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GalleryGroupData(
      groupName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}groupName'])!,
      sortOrder: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sortOrder'])!,
    );
  }

  @override
  $GalleryGroupTable createAlias(String alias) {
    return $GalleryGroupTable(attachedDatabase, alias);
  }
}

class GalleryGroupData extends DataClass
    implements Insertable<GalleryGroupData> {
  final String groupName;
  final int sortOrder;
  const GalleryGroupData({required this.groupName, required this.sortOrder});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['groupName'] = Variable<String>(groupName);
    map['sortOrder'] = Variable<int>(sortOrder);
    return map;
  }

  GalleryGroupCompanion toCompanion(bool nullToAbsent) {
    return GalleryGroupCompanion(
      groupName: Value(groupName),
      sortOrder: Value(sortOrder),
    );
  }

  factory GalleryGroupData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GalleryGroupData(
      groupName: serializer.fromJson<String>(json['groupName']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'groupName': serializer.toJson<String>(groupName),
      'sortOrder': serializer.toJson<int>(sortOrder),
    };
  }

  GalleryGroupData copyWith({String? groupName, int? sortOrder}) =>
      GalleryGroupData(
        groupName: groupName ?? this.groupName,
        sortOrder: sortOrder ?? this.sortOrder,
      );
  @override
  String toString() {
    return (StringBuffer('GalleryGroupData(')
          ..write('groupName: $groupName, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(groupName, sortOrder);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GalleryGroupData &&
          other.groupName == this.groupName &&
          other.sortOrder == this.sortOrder);
}

class GalleryGroupCompanion extends UpdateCompanion<GalleryGroupData> {
  final Value<String> groupName;
  final Value<int> sortOrder;
  final Value<int> rowid;
  const GalleryGroupCompanion({
    this.groupName = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  GalleryGroupCompanion.insert({
    required String groupName,
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : groupName = Value(groupName);
  static Insertable<GalleryGroupData> custom({
    Expression<String>? groupName,
    Expression<int>? sortOrder,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (groupName != null) 'groupName': groupName,
      if (sortOrder != null) 'sortOrder': sortOrder,
      if (rowid != null) 'rowid': rowid,
    });
  }

  GalleryGroupCompanion copyWith(
      {Value<String>? groupName, Value<int>? sortOrder, Value<int>? rowid}) {
    return GalleryGroupCompanion(
      groupName: groupName ?? this.groupName,
      sortOrder: sortOrder ?? this.sortOrder,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (groupName.present) {
      map['groupName'] = Variable<String>(groupName.value);
    }
    if (sortOrder.present) {
      map['sortOrder'] = Variable<int>(sortOrder.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GalleryGroupCompanion(')
          ..write('groupName: $groupName, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ImageTable extends Image with TableInfo<$ImageTable, ImageData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ImageTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _gidMeta = const VerificationMeta('gid');
  @override
  late final GeneratedColumn<int> gid = GeneratedColumn<int>(
      'gid', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES gallery_downloaded_v2 (gid)'));
  static const VerificationMeta _urlMeta = const VerificationMeta('url');
  @override
  late final GeneratedColumn<String> url = GeneratedColumn<String>(
      'url', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _serialNoMeta =
      const VerificationMeta('serialNo');
  @override
  late final GeneratedColumn<int> serialNo = GeneratedColumn<int>(
      'serialNo', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
      'path', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _imageHashMeta =
      const VerificationMeta('imageHash');
  @override
  late final GeneratedColumn<String> imageHash = GeneratedColumn<String>(
      'imageHash', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _downloadStatusIndexMeta =
      const VerificationMeta('downloadStatusIndex');
  @override
  late final GeneratedColumn<int> downloadStatusIndex = GeneratedColumn<int>(
      'downloadStatusIndex', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [gid, url, serialNo, path, imageHash, downloadStatusIndex];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'image';
  @override
  VerificationContext validateIntegrity(Insertable<ImageData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('gid')) {
      context.handle(
          _gidMeta, gid.isAcceptableOrUnknown(data['gid']!, _gidMeta));
    } else if (isInserting) {
      context.missing(_gidMeta);
    }
    if (data.containsKey('url')) {
      context.handle(
          _urlMeta, url.isAcceptableOrUnknown(data['url']!, _urlMeta));
    } else if (isInserting) {
      context.missing(_urlMeta);
    }
    if (data.containsKey('serialNo')) {
      context.handle(_serialNoMeta,
          serialNo.isAcceptableOrUnknown(data['serialNo']!, _serialNoMeta));
    } else if (isInserting) {
      context.missing(_serialNoMeta);
    }
    if (data.containsKey('path')) {
      context.handle(
          _pathMeta, path.isAcceptableOrUnknown(data['path']!, _pathMeta));
    } else if (isInserting) {
      context.missing(_pathMeta);
    }
    if (data.containsKey('imageHash')) {
      context.handle(_imageHashMeta,
          imageHash.isAcceptableOrUnknown(data['imageHash']!, _imageHashMeta));
    } else if (isInserting) {
      context.missing(_imageHashMeta);
    }
    if (data.containsKey('downloadStatusIndex')) {
      context.handle(
          _downloadStatusIndexMeta,
          downloadStatusIndex.isAcceptableOrUnknown(
              data['downloadStatusIndex']!, _downloadStatusIndexMeta));
    } else if (isInserting) {
      context.missing(_downloadStatusIndexMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {gid, serialNo};
  @override
  ImageData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ImageData(
      gid: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}gid'])!,
      url: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}url'])!,
      serialNo: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}serialNo'])!,
      path: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}path'])!,
      imageHash: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}imageHash'])!,
      downloadStatusIndex: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}downloadStatusIndex'])!,
    );
  }

  @override
  $ImageTable createAlias(String alias) {
    return $ImageTable(attachedDatabase, alias);
  }
}

class ImageData extends DataClass implements Insertable<ImageData> {
  final int gid;
  final String url;
  final int serialNo;
  final String path;
  final String imageHash;
  final int downloadStatusIndex;
  const ImageData(
      {required this.gid,
      required this.url,
      required this.serialNo,
      required this.path,
      required this.imageHash,
      required this.downloadStatusIndex});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['gid'] = Variable<int>(gid);
    map['url'] = Variable<String>(url);
    map['serialNo'] = Variable<int>(serialNo);
    map['path'] = Variable<String>(path);
    map['imageHash'] = Variable<String>(imageHash);
    map['downloadStatusIndex'] = Variable<int>(downloadStatusIndex);
    return map;
  }

  ImageCompanion toCompanion(bool nullToAbsent) {
    return ImageCompanion(
      gid: Value(gid),
      url: Value(url),
      serialNo: Value(serialNo),
      path: Value(path),
      imageHash: Value(imageHash),
      downloadStatusIndex: Value(downloadStatusIndex),
    );
  }

  factory ImageData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ImageData(
      gid: serializer.fromJson<int>(json['gid']),
      url: serializer.fromJson<String>(json['url']),
      serialNo: serializer.fromJson<int>(json['serialNo']),
      path: serializer.fromJson<String>(json['path']),
      imageHash: serializer.fromJson<String>(json['imageHash']),
      downloadStatusIndex:
          serializer.fromJson<int>(json['downloadStatusIndex']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'gid': serializer.toJson<int>(gid),
      'url': serializer.toJson<String>(url),
      'serialNo': serializer.toJson<int>(serialNo),
      'path': serializer.toJson<String>(path),
      'imageHash': serializer.toJson<String>(imageHash),
      'downloadStatusIndex': serializer.toJson<int>(downloadStatusIndex),
    };
  }

  ImageData copyWith(
          {int? gid,
          String? url,
          int? serialNo,
          String? path,
          String? imageHash,
          int? downloadStatusIndex}) =>
      ImageData(
        gid: gid ?? this.gid,
        url: url ?? this.url,
        serialNo: serialNo ?? this.serialNo,
        path: path ?? this.path,
        imageHash: imageHash ?? this.imageHash,
        downloadStatusIndex: downloadStatusIndex ?? this.downloadStatusIndex,
      );
  @override
  String toString() {
    return (StringBuffer('ImageData(')
          ..write('gid: $gid, ')
          ..write('url: $url, ')
          ..write('serialNo: $serialNo, ')
          ..write('path: $path, ')
          ..write('imageHash: $imageHash, ')
          ..write('downloadStatusIndex: $downloadStatusIndex')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(gid, url, serialNo, path, imageHash, downloadStatusIndex);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ImageData &&
          other.gid == this.gid &&
          other.url == this.url &&
          other.serialNo == this.serialNo &&
          other.path == this.path &&
          other.imageHash == this.imageHash &&
          other.downloadStatusIndex == this.downloadStatusIndex);
}

class ImageCompanion extends UpdateCompanion<ImageData> {
  final Value<int> gid;
  final Value<String> url;
  final Value<int> serialNo;
  final Value<String> path;
  final Value<String> imageHash;
  final Value<int> downloadStatusIndex;
  final Value<int> rowid;
  const ImageCompanion({
    this.gid = const Value.absent(),
    this.url = const Value.absent(),
    this.serialNo = const Value.absent(),
    this.path = const Value.absent(),
    this.imageHash = const Value.absent(),
    this.downloadStatusIndex = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ImageCompanion.insert({
    required int gid,
    required String url,
    required int serialNo,
    required String path,
    required String imageHash,
    required int downloadStatusIndex,
    this.rowid = const Value.absent(),
  })  : gid = Value(gid),
        url = Value(url),
        serialNo = Value(serialNo),
        path = Value(path),
        imageHash = Value(imageHash),
        downloadStatusIndex = Value(downloadStatusIndex);
  static Insertable<ImageData> custom({
    Expression<int>? gid,
    Expression<String>? url,
    Expression<int>? serialNo,
    Expression<String>? path,
    Expression<String>? imageHash,
    Expression<int>? downloadStatusIndex,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (gid != null) 'gid': gid,
      if (url != null) 'url': url,
      if (serialNo != null) 'serialNo': serialNo,
      if (path != null) 'path': path,
      if (imageHash != null) 'imageHash': imageHash,
      if (downloadStatusIndex != null)
        'downloadStatusIndex': downloadStatusIndex,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ImageCompanion copyWith(
      {Value<int>? gid,
      Value<String>? url,
      Value<int>? serialNo,
      Value<String>? path,
      Value<String>? imageHash,
      Value<int>? downloadStatusIndex,
      Value<int>? rowid}) {
    return ImageCompanion(
      gid: gid ?? this.gid,
      url: url ?? this.url,
      serialNo: serialNo ?? this.serialNo,
      path: path ?? this.path,
      imageHash: imageHash ?? this.imageHash,
      downloadStatusIndex: downloadStatusIndex ?? this.downloadStatusIndex,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (gid.present) {
      map['gid'] = Variable<int>(gid.value);
    }
    if (url.present) {
      map['url'] = Variable<String>(url.value);
    }
    if (serialNo.present) {
      map['serialNo'] = Variable<int>(serialNo.value);
    }
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (imageHash.present) {
      map['imageHash'] = Variable<String>(imageHash.value);
    }
    if (downloadStatusIndex.present) {
      map['downloadStatusIndex'] = Variable<int>(downloadStatusIndex.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ImageCompanion(')
          ..write('gid: $gid, ')
          ..write('url: $url, ')
          ..write('serialNo: $serialNo, ')
          ..write('path: $path, ')
          ..write('imageHash: $imageHash, ')
          ..write('downloadStatusIndex: $downloadStatusIndex, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $GalleryHistoryTable extends GalleryHistory
    with TableInfo<$GalleryHistoryTable, GalleryHistoryData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GalleryHistoryTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _gidMeta = const VerificationMeta('gid');
  @override
  late final GeneratedColumn<int> gid = GeneratedColumn<int>(
      'gid', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _jsonBodyMeta =
      const VerificationMeta('jsonBody');
  @override
  late final GeneratedColumn<String> jsonBody = GeneratedColumn<String>(
      'jsonBody', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _lastReadTimeMeta =
      const VerificationMeta('lastReadTime');
  @override
  late final GeneratedColumn<String> lastReadTime = GeneratedColumn<String>(
      'lastReadTime', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [gid, jsonBody, lastReadTime];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'gallery_history';
  @override
  VerificationContext validateIntegrity(Insertable<GalleryHistoryData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('gid')) {
      context.handle(
          _gidMeta, gid.isAcceptableOrUnknown(data['gid']!, _gidMeta));
    }
    if (data.containsKey('jsonBody')) {
      context.handle(_jsonBodyMeta,
          jsonBody.isAcceptableOrUnknown(data['jsonBody']!, _jsonBodyMeta));
    } else if (isInserting) {
      context.missing(_jsonBodyMeta);
    }
    if (data.containsKey('lastReadTime')) {
      context.handle(
          _lastReadTimeMeta,
          lastReadTime.isAcceptableOrUnknown(
              data['lastReadTime']!, _lastReadTimeMeta));
    } else if (isInserting) {
      context.missing(_lastReadTimeMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {gid};
  @override
  GalleryHistoryData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GalleryHistoryData(
      gid: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}gid'])!,
      jsonBody: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}jsonBody'])!,
      lastReadTime: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}lastReadTime'])!,
    );
  }

  @override
  $GalleryHistoryTable createAlias(String alias) {
    return $GalleryHistoryTable(attachedDatabase, alias);
  }
}

class GalleryHistoryData extends DataClass
    implements Insertable<GalleryHistoryData> {
  final int gid;
  final String jsonBody;
  final String lastReadTime;
  const GalleryHistoryData(
      {required this.gid, required this.jsonBody, required this.lastReadTime});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['gid'] = Variable<int>(gid);
    map['jsonBody'] = Variable<String>(jsonBody);
    map['lastReadTime'] = Variable<String>(lastReadTime);
    return map;
  }

  GalleryHistoryCompanion toCompanion(bool nullToAbsent) {
    return GalleryHistoryCompanion(
      gid: Value(gid),
      jsonBody: Value(jsonBody),
      lastReadTime: Value(lastReadTime),
    );
  }

  factory GalleryHistoryData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GalleryHistoryData(
      gid: serializer.fromJson<int>(json['gid']),
      jsonBody: serializer.fromJson<String>(json['jsonBody']),
      lastReadTime: serializer.fromJson<String>(json['lastReadTime']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'gid': serializer.toJson<int>(gid),
      'jsonBody': serializer.toJson<String>(jsonBody),
      'lastReadTime': serializer.toJson<String>(lastReadTime),
    };
  }

  GalleryHistoryData copyWith(
          {int? gid, String? jsonBody, String? lastReadTime}) =>
      GalleryHistoryData(
        gid: gid ?? this.gid,
        jsonBody: jsonBody ?? this.jsonBody,
        lastReadTime: lastReadTime ?? this.lastReadTime,
      );
  @override
  String toString() {
    return (StringBuffer('GalleryHistoryData(')
          ..write('gid: $gid, ')
          ..write('jsonBody: $jsonBody, ')
          ..write('lastReadTime: $lastReadTime')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(gid, jsonBody, lastReadTime);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GalleryHistoryData &&
          other.gid == this.gid &&
          other.jsonBody == this.jsonBody &&
          other.lastReadTime == this.lastReadTime);
}

class GalleryHistoryCompanion extends UpdateCompanion<GalleryHistoryData> {
  final Value<int> gid;
  final Value<String> jsonBody;
  final Value<String> lastReadTime;
  const GalleryHistoryCompanion({
    this.gid = const Value.absent(),
    this.jsonBody = const Value.absent(),
    this.lastReadTime = const Value.absent(),
  });
  GalleryHistoryCompanion.insert({
    this.gid = const Value.absent(),
    required String jsonBody,
    required String lastReadTime,
  })  : jsonBody = Value(jsonBody),
        lastReadTime = Value(lastReadTime);
  static Insertable<GalleryHistoryData> custom({
    Expression<int>? gid,
    Expression<String>? jsonBody,
    Expression<String>? lastReadTime,
  }) {
    return RawValuesInsertable({
      if (gid != null) 'gid': gid,
      if (jsonBody != null) 'jsonBody': jsonBody,
      if (lastReadTime != null) 'lastReadTime': lastReadTime,
    });
  }

  GalleryHistoryCompanion copyWith(
      {Value<int>? gid, Value<String>? jsonBody, Value<String>? lastReadTime}) {
    return GalleryHistoryCompanion(
      gid: gid ?? this.gid,
      jsonBody: jsonBody ?? this.jsonBody,
      lastReadTime: lastReadTime ?? this.lastReadTime,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (gid.present) {
      map['gid'] = Variable<int>(gid.value);
    }
    if (jsonBody.present) {
      map['jsonBody'] = Variable<String>(jsonBody.value);
    }
    if (lastReadTime.present) {
      map['lastReadTime'] = Variable<String>(lastReadTime.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GalleryHistoryCompanion(')
          ..write('gid: $gid, ')
          ..write('jsonBody: $jsonBody, ')
          ..write('lastReadTime: $lastReadTime')
          ..write(')'))
        .toString();
  }
}

class $GalleryHistoryV2Table extends GalleryHistoryV2
    with TableInfo<$GalleryHistoryV2Table, GalleryHistoryV2Data> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GalleryHistoryV2Table(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _gidMeta = const VerificationMeta('gid');
  @override
  late final GeneratedColumn<int> gid = GeneratedColumn<int>(
      'gid', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _jsonBodyMeta =
      const VerificationMeta('jsonBody');
  @override
  late final GeneratedColumn<String> jsonBody = GeneratedColumn<String>(
      'jsonBody', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _lastReadTimeMeta =
      const VerificationMeta('lastReadTime');
  @override
  late final GeneratedColumn<String> lastReadTime = GeneratedColumn<String>(
      'lastReadTime', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [gid, jsonBody, lastReadTime];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'gallery_history_v2';
  @override
  VerificationContext validateIntegrity(
      Insertable<GalleryHistoryV2Data> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('gid')) {
      context.handle(
          _gidMeta, gid.isAcceptableOrUnknown(data['gid']!, _gidMeta));
    }
    if (data.containsKey('jsonBody')) {
      context.handle(_jsonBodyMeta,
          jsonBody.isAcceptableOrUnknown(data['jsonBody']!, _jsonBodyMeta));
    } else if (isInserting) {
      context.missing(_jsonBodyMeta);
    }
    if (data.containsKey('lastReadTime')) {
      context.handle(
          _lastReadTimeMeta,
          lastReadTime.isAcceptableOrUnknown(
              data['lastReadTime']!, _lastReadTimeMeta));
    } else if (isInserting) {
      context.missing(_lastReadTimeMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {gid};
  @override
  GalleryHistoryV2Data map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GalleryHistoryV2Data(
      gid: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}gid'])!,
      jsonBody: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}jsonBody'])!,
      lastReadTime: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}lastReadTime'])!,
    );
  }

  @override
  $GalleryHistoryV2Table createAlias(String alias) {
    return $GalleryHistoryV2Table(attachedDatabase, alias);
  }
}

class GalleryHistoryV2Data extends DataClass
    implements Insertable<GalleryHistoryV2Data> {
  final int gid;
  final String jsonBody;
  final String lastReadTime;
  const GalleryHistoryV2Data(
      {required this.gid, required this.jsonBody, required this.lastReadTime});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['gid'] = Variable<int>(gid);
    map['jsonBody'] = Variable<String>(jsonBody);
    map['lastReadTime'] = Variable<String>(lastReadTime);
    return map;
  }

  GalleryHistoryV2Companion toCompanion(bool nullToAbsent) {
    return GalleryHistoryV2Companion(
      gid: Value(gid),
      jsonBody: Value(jsonBody),
      lastReadTime: Value(lastReadTime),
    );
  }

  factory GalleryHistoryV2Data.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GalleryHistoryV2Data(
      gid: serializer.fromJson<int>(json['gid']),
      jsonBody: serializer.fromJson<String>(json['jsonBody']),
      lastReadTime: serializer.fromJson<String>(json['lastReadTime']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'gid': serializer.toJson<int>(gid),
      'jsonBody': serializer.toJson<String>(jsonBody),
      'lastReadTime': serializer.toJson<String>(lastReadTime),
    };
  }

  GalleryHistoryV2Data copyWith(
          {int? gid, String? jsonBody, String? lastReadTime}) =>
      GalleryHistoryV2Data(
        gid: gid ?? this.gid,
        jsonBody: jsonBody ?? this.jsonBody,
        lastReadTime: lastReadTime ?? this.lastReadTime,
      );
  @override
  String toString() {
    return (StringBuffer('GalleryHistoryV2Data(')
          ..write('gid: $gid, ')
          ..write('jsonBody: $jsonBody, ')
          ..write('lastReadTime: $lastReadTime')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(gid, jsonBody, lastReadTime);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GalleryHistoryV2Data &&
          other.gid == this.gid &&
          other.jsonBody == this.jsonBody &&
          other.lastReadTime == this.lastReadTime);
}

class GalleryHistoryV2Companion extends UpdateCompanion<GalleryHistoryV2Data> {
  final Value<int> gid;
  final Value<String> jsonBody;
  final Value<String> lastReadTime;
  const GalleryHistoryV2Companion({
    this.gid = const Value.absent(),
    this.jsonBody = const Value.absent(),
    this.lastReadTime = const Value.absent(),
  });
  GalleryHistoryV2Companion.insert({
    this.gid = const Value.absent(),
    required String jsonBody,
    required String lastReadTime,
  })  : jsonBody = Value(jsonBody),
        lastReadTime = Value(lastReadTime);
  static Insertable<GalleryHistoryV2Data> custom({
    Expression<int>? gid,
    Expression<String>? jsonBody,
    Expression<String>? lastReadTime,
  }) {
    return RawValuesInsertable({
      if (gid != null) 'gid': gid,
      if (jsonBody != null) 'jsonBody': jsonBody,
      if (lastReadTime != null) 'lastReadTime': lastReadTime,
    });
  }

  GalleryHistoryV2Companion copyWith(
      {Value<int>? gid, Value<String>? jsonBody, Value<String>? lastReadTime}) {
    return GalleryHistoryV2Companion(
      gid: gid ?? this.gid,
      jsonBody: jsonBody ?? this.jsonBody,
      lastReadTime: lastReadTime ?? this.lastReadTime,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (gid.present) {
      map['gid'] = Variable<int>(gid.value);
    }
    if (jsonBody.present) {
      map['jsonBody'] = Variable<String>(jsonBody.value);
    }
    if (lastReadTime.present) {
      map['lastReadTime'] = Variable<String>(lastReadTime.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GalleryHistoryV2Companion(')
          ..write('gid: $gid, ')
          ..write('jsonBody: $jsonBody, ')
          ..write('lastReadTime: $lastReadTime')
          ..write(')'))
        .toString();
  }
}

class $TagCountTable extends TagCount
    with TableInfo<$TagCountTable, TagCountData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TagCountTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _namespaceWithKeyMeta =
      const VerificationMeta('namespaceWithKey');
  @override
  late final GeneratedColumn<String> namespaceWithKey = GeneratedColumn<String>(
      'namespaceWithKey', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _countMeta = const VerificationMeta('count');
  @override
  late final GeneratedColumn<int> count = GeneratedColumn<int>(
      'count', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [namespaceWithKey, count];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tag_count';
  @override
  VerificationContext validateIntegrity(Insertable<TagCountData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('namespaceWithKey')) {
      context.handle(
          _namespaceWithKeyMeta,
          namespaceWithKey.isAcceptableOrUnknown(
              data['namespaceWithKey']!, _namespaceWithKeyMeta));
    } else if (isInserting) {
      context.missing(_namespaceWithKeyMeta);
    }
    if (data.containsKey('count')) {
      context.handle(
          _countMeta, count.isAcceptableOrUnknown(data['count']!, _countMeta));
    } else if (isInserting) {
      context.missing(_countMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {namespaceWithKey};
  @override
  TagCountData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TagCountData(
      namespaceWithKey: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}namespaceWithKey'])!,
      count: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}count'])!,
    );
  }

  @override
  $TagCountTable createAlias(String alias) {
    return $TagCountTable(attachedDatabase, alias);
  }
}

class TagCountData extends DataClass implements Insertable<TagCountData> {
  final String namespaceWithKey;
  final int count;
  const TagCountData({required this.namespaceWithKey, required this.count});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['namespaceWithKey'] = Variable<String>(namespaceWithKey);
    map['count'] = Variable<int>(count);
    return map;
  }

  TagCountCompanion toCompanion(bool nullToAbsent) {
    return TagCountCompanion(
      namespaceWithKey: Value(namespaceWithKey),
      count: Value(count),
    );
  }

  factory TagCountData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TagCountData(
      namespaceWithKey: serializer.fromJson<String>(json['namespaceWithKey']),
      count: serializer.fromJson<int>(json['count']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'namespaceWithKey': serializer.toJson<String>(namespaceWithKey),
      'count': serializer.toJson<int>(count),
    };
  }

  TagCountData copyWith({String? namespaceWithKey, int? count}) => TagCountData(
        namespaceWithKey: namespaceWithKey ?? this.namespaceWithKey,
        count: count ?? this.count,
      );
  @override
  String toString() {
    return (StringBuffer('TagCountData(')
          ..write('namespaceWithKey: $namespaceWithKey, ')
          ..write('count: $count')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(namespaceWithKey, count);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TagCountData &&
          other.namespaceWithKey == this.namespaceWithKey &&
          other.count == this.count);
}

class TagCountCompanion extends UpdateCompanion<TagCountData> {
  final Value<String> namespaceWithKey;
  final Value<int> count;
  final Value<int> rowid;
  const TagCountCompanion({
    this.namespaceWithKey = const Value.absent(),
    this.count = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TagCountCompanion.insert({
    required String namespaceWithKey,
    required int count,
    this.rowid = const Value.absent(),
  })  : namespaceWithKey = Value(namespaceWithKey),
        count = Value(count);
  static Insertable<TagCountData> custom({
    Expression<String>? namespaceWithKey,
    Expression<int>? count,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (namespaceWithKey != null) 'namespaceWithKey': namespaceWithKey,
      if (count != null) 'count': count,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TagCountCompanion copyWith(
      {Value<String>? namespaceWithKey, Value<int>? count, Value<int>? rowid}) {
    return TagCountCompanion(
      namespaceWithKey: namespaceWithKey ?? this.namespaceWithKey,
      count: count ?? this.count,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (namespaceWithKey.present) {
      map['namespaceWithKey'] = Variable<String>(namespaceWithKey.value);
    }
    if (count.present) {
      map['count'] = Variable<int>(count.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TagCountCompanion(')
          ..write('namespaceWithKey: $namespaceWithKey, ')
          ..write('count: $count, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DioCacheTable extends DioCache
    with TableInfo<$DioCacheTable, DioCacheData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DioCacheTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _cacheKeyMeta =
      const VerificationMeta('cacheKey');
  @override
  late final GeneratedColumn<String> cacheKey = GeneratedColumn<String>(
      'cacheKey', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _urlMeta = const VerificationMeta('url');
  @override
  late final GeneratedColumn<String> url = GeneratedColumn<String>(
      'url', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _expireDateMeta =
      const VerificationMeta('expireDate');
  @override
  late final GeneratedColumn<DateTime> expireDate = GeneratedColumn<DateTime>(
      'expireDate', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _contentMeta =
      const VerificationMeta('content');
  @override
  late final GeneratedColumn<Uint8List> content = GeneratedColumn<Uint8List>(
      'content', aliasedName, false,
      type: DriftSqlType.blob, requiredDuringInsert: true);
  static const VerificationMeta _headersMeta =
      const VerificationMeta('headers');
  @override
  late final GeneratedColumn<Uint8List> headers = GeneratedColumn<Uint8List>(
      'headers', aliasedName, false,
      type: DriftSqlType.blob, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [cacheKey, url, expireDate, content, headers];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'dio_cache';
  @override
  VerificationContext validateIntegrity(Insertable<DioCacheData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('cacheKey')) {
      context.handle(_cacheKeyMeta,
          cacheKey.isAcceptableOrUnknown(data['cacheKey']!, _cacheKeyMeta));
    } else if (isInserting) {
      context.missing(_cacheKeyMeta);
    }
    if (data.containsKey('url')) {
      context.handle(
          _urlMeta, url.isAcceptableOrUnknown(data['url']!, _urlMeta));
    } else if (isInserting) {
      context.missing(_urlMeta);
    }
    if (data.containsKey('expireDate')) {
      context.handle(
          _expireDateMeta,
          expireDate.isAcceptableOrUnknown(
              data['expireDate']!, _expireDateMeta));
    } else if (isInserting) {
      context.missing(_expireDateMeta);
    }
    if (data.containsKey('content')) {
      context.handle(_contentMeta,
          content.isAcceptableOrUnknown(data['content']!, _contentMeta));
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('headers')) {
      context.handle(_headersMeta,
          headers.isAcceptableOrUnknown(data['headers']!, _headersMeta));
    } else if (isInserting) {
      context.missing(_headersMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {cacheKey};
  @override
  DioCacheData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DioCacheData(
      cacheKey: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}cacheKey'])!,
      url: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}url'])!,
      expireDate: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}expireDate'])!,
      content: attachedDatabase.typeMapping
          .read(DriftSqlType.blob, data['${effectivePrefix}content'])!,
      headers: attachedDatabase.typeMapping
          .read(DriftSqlType.blob, data['${effectivePrefix}headers'])!,
    );
  }

  @override
  $DioCacheTable createAlias(String alias) {
    return $DioCacheTable(attachedDatabase, alias);
  }
}

class DioCacheData extends DataClass implements Insertable<DioCacheData> {
  final String cacheKey;
  final String url;
  final DateTime expireDate;
  final Uint8List content;
  final Uint8List headers;
  const DioCacheData(
      {required this.cacheKey,
      required this.url,
      required this.expireDate,
      required this.content,
      required this.headers});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['cacheKey'] = Variable<String>(cacheKey);
    map['url'] = Variable<String>(url);
    map['expireDate'] = Variable<DateTime>(expireDate);
    map['content'] = Variable<Uint8List>(content);
    map['headers'] = Variable<Uint8List>(headers);
    return map;
  }

  DioCacheCompanion toCompanion(bool nullToAbsent) {
    return DioCacheCompanion(
      cacheKey: Value(cacheKey),
      url: Value(url),
      expireDate: Value(expireDate),
      content: Value(content),
      headers: Value(headers),
    );
  }

  factory DioCacheData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DioCacheData(
      cacheKey: serializer.fromJson<String>(json['cacheKey']),
      url: serializer.fromJson<String>(json['url']),
      expireDate: serializer.fromJson<DateTime>(json['expireDate']),
      content: serializer.fromJson<Uint8List>(json['content']),
      headers: serializer.fromJson<Uint8List>(json['headers']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'cacheKey': serializer.toJson<String>(cacheKey),
      'url': serializer.toJson<String>(url),
      'expireDate': serializer.toJson<DateTime>(expireDate),
      'content': serializer.toJson<Uint8List>(content),
      'headers': serializer.toJson<Uint8List>(headers),
    };
  }

  DioCacheData copyWith(
          {String? cacheKey,
          String? url,
          DateTime? expireDate,
          Uint8List? content,
          Uint8List? headers}) =>
      DioCacheData(
        cacheKey: cacheKey ?? this.cacheKey,
        url: url ?? this.url,
        expireDate: expireDate ?? this.expireDate,
        content: content ?? this.content,
        headers: headers ?? this.headers,
      );
  @override
  String toString() {
    return (StringBuffer('DioCacheData(')
          ..write('cacheKey: $cacheKey, ')
          ..write('url: $url, ')
          ..write('expireDate: $expireDate, ')
          ..write('content: $content, ')
          ..write('headers: $headers')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(cacheKey, url, expireDate,
      $driftBlobEquality.hash(content), $driftBlobEquality.hash(headers));
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DioCacheData &&
          other.cacheKey == this.cacheKey &&
          other.url == this.url &&
          other.expireDate == this.expireDate &&
          $driftBlobEquality.equals(other.content, this.content) &&
          $driftBlobEquality.equals(other.headers, this.headers));
}

class DioCacheCompanion extends UpdateCompanion<DioCacheData> {
  final Value<String> cacheKey;
  final Value<String> url;
  final Value<DateTime> expireDate;
  final Value<Uint8List> content;
  final Value<Uint8List> headers;
  final Value<int> rowid;
  const DioCacheCompanion({
    this.cacheKey = const Value.absent(),
    this.url = const Value.absent(),
    this.expireDate = const Value.absent(),
    this.content = const Value.absent(),
    this.headers = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DioCacheCompanion.insert({
    required String cacheKey,
    required String url,
    required DateTime expireDate,
    required Uint8List content,
    required Uint8List headers,
    this.rowid = const Value.absent(),
  })  : cacheKey = Value(cacheKey),
        url = Value(url),
        expireDate = Value(expireDate),
        content = Value(content),
        headers = Value(headers);
  static Insertable<DioCacheData> custom({
    Expression<String>? cacheKey,
    Expression<String>? url,
    Expression<DateTime>? expireDate,
    Expression<Uint8List>? content,
    Expression<Uint8List>? headers,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (cacheKey != null) 'cacheKey': cacheKey,
      if (url != null) 'url': url,
      if (expireDate != null) 'expireDate': expireDate,
      if (content != null) 'content': content,
      if (headers != null) 'headers': headers,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DioCacheCompanion copyWith(
      {Value<String>? cacheKey,
      Value<String>? url,
      Value<DateTime>? expireDate,
      Value<Uint8List>? content,
      Value<Uint8List>? headers,
      Value<int>? rowid}) {
    return DioCacheCompanion(
      cacheKey: cacheKey ?? this.cacheKey,
      url: url ?? this.url,
      expireDate: expireDate ?? this.expireDate,
      content: content ?? this.content,
      headers: headers ?? this.headers,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (cacheKey.present) {
      map['cacheKey'] = Variable<String>(cacheKey.value);
    }
    if (url.present) {
      map['url'] = Variable<String>(url.value);
    }
    if (expireDate.present) {
      map['expireDate'] = Variable<DateTime>(expireDate.value);
    }
    if (content.present) {
      map['content'] = Variable<Uint8List>(content.value);
    }
    if (headers.present) {
      map['headers'] = Variable<Uint8List>(headers.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DioCacheCompanion(')
          ..write('cacheKey: $cacheKey, ')
          ..write('url: $url, ')
          ..write('expireDate: $expireDate, ')
          ..write('content: $content, ')
          ..write('headers: $headers, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BlockRuleTable extends BlockRule
    with TableInfo<$BlockRuleTable, BlockRuleData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BlockRuleTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _groupIdMeta =
      const VerificationMeta('groupId');
  @override
  late final GeneratedColumn<String> groupId = GeneratedColumn<String>(
      'group_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _targetMeta = const VerificationMeta('target');
  @override
  late final GeneratedColumn<int> target = GeneratedColumn<int>(
      'target', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _attributeMeta =
      const VerificationMeta('attribute');
  @override
  late final GeneratedColumn<int> attribute = GeneratedColumn<int>(
      'attribute', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _patternMeta =
      const VerificationMeta('pattern');
  @override
  late final GeneratedColumn<int> pattern = GeneratedColumn<int>(
      'pattern', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _expressionMeta =
      const VerificationMeta('expression');
  @override
  late final GeneratedColumn<String> expression = GeneratedColumn<String>(
      'expression', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [id, groupId, target, attribute, pattern, expression];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'block_rule';
  @override
  VerificationContext validateIntegrity(Insertable<BlockRuleData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('group_id')) {
      context.handle(_groupIdMeta,
          groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta));
    } else if (isInserting) {
      context.missing(_groupIdMeta);
    }
    if (data.containsKey('target')) {
      context.handle(_targetMeta,
          target.isAcceptableOrUnknown(data['target']!, _targetMeta));
    } else if (isInserting) {
      context.missing(_targetMeta);
    }
    if (data.containsKey('attribute')) {
      context.handle(_attributeMeta,
          attribute.isAcceptableOrUnknown(data['attribute']!, _attributeMeta));
    } else if (isInserting) {
      context.missing(_attributeMeta);
    }
    if (data.containsKey('pattern')) {
      context.handle(_patternMeta,
          pattern.isAcceptableOrUnknown(data['pattern']!, _patternMeta));
    } else if (isInserting) {
      context.missing(_patternMeta);
    }
    if (data.containsKey('expression')) {
      context.handle(
          _expressionMeta,
          expression.isAcceptableOrUnknown(
              data['expression']!, _expressionMeta));
    } else if (isInserting) {
      context.missing(_expressionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BlockRuleData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BlockRuleData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      groupId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}group_id'])!,
      target: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}target'])!,
      attribute: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}attribute'])!,
      pattern: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}pattern'])!,
      expression: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}expression'])!,
    );
  }

  @override
  $BlockRuleTable createAlias(String alias) {
    return $BlockRuleTable(attachedDatabase, alias);
  }
}

class BlockRuleData extends DataClass implements Insertable<BlockRuleData> {
  final int id;
  final String groupId;
  final int target;
  final int attribute;
  final int pattern;
  final String expression;
  const BlockRuleData(
      {required this.id,
      required this.groupId,
      required this.target,
      required this.attribute,
      required this.pattern,
      required this.expression});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['group_id'] = Variable<String>(groupId);
    map['target'] = Variable<int>(target);
    map['attribute'] = Variable<int>(attribute);
    map['pattern'] = Variable<int>(pattern);
    map['expression'] = Variable<String>(expression);
    return map;
  }

  BlockRuleCompanion toCompanion(bool nullToAbsent) {
    return BlockRuleCompanion(
      id: Value(id),
      groupId: Value(groupId),
      target: Value(target),
      attribute: Value(attribute),
      pattern: Value(pattern),
      expression: Value(expression),
    );
  }

  factory BlockRuleData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BlockRuleData(
      id: serializer.fromJson<int>(json['id']),
      groupId: serializer.fromJson<String>(json['groupId']),
      target: serializer.fromJson<int>(json['target']),
      attribute: serializer.fromJson<int>(json['attribute']),
      pattern: serializer.fromJson<int>(json['pattern']),
      expression: serializer.fromJson<String>(json['expression']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'groupId': serializer.toJson<String>(groupId),
      'target': serializer.toJson<int>(target),
      'attribute': serializer.toJson<int>(attribute),
      'pattern': serializer.toJson<int>(pattern),
      'expression': serializer.toJson<String>(expression),
    };
  }

  BlockRuleData copyWith(
          {int? id,
          String? groupId,
          int? target,
          int? attribute,
          int? pattern,
          String? expression}) =>
      BlockRuleData(
        id: id ?? this.id,
        groupId: groupId ?? this.groupId,
        target: target ?? this.target,
        attribute: attribute ?? this.attribute,
        pattern: pattern ?? this.pattern,
        expression: expression ?? this.expression,
      );
  @override
  String toString() {
    return (StringBuffer('BlockRuleData(')
          ..write('id: $id, ')
          ..write('groupId: $groupId, ')
          ..write('target: $target, ')
          ..write('attribute: $attribute, ')
          ..write('pattern: $pattern, ')
          ..write('expression: $expression')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, groupId, target, attribute, pattern, expression);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BlockRuleData &&
          other.id == this.id &&
          other.groupId == this.groupId &&
          other.target == this.target &&
          other.attribute == this.attribute &&
          other.pattern == this.pattern &&
          other.expression == this.expression);
}

class BlockRuleCompanion extends UpdateCompanion<BlockRuleData> {
  final Value<int> id;
  final Value<String> groupId;
  final Value<int> target;
  final Value<int> attribute;
  final Value<int> pattern;
  final Value<String> expression;
  const BlockRuleCompanion({
    this.id = const Value.absent(),
    this.groupId = const Value.absent(),
    this.target = const Value.absent(),
    this.attribute = const Value.absent(),
    this.pattern = const Value.absent(),
    this.expression = const Value.absent(),
  });
  BlockRuleCompanion.insert({
    this.id = const Value.absent(),
    required String groupId,
    required int target,
    required int attribute,
    required int pattern,
    required String expression,
  })  : groupId = Value(groupId),
        target = Value(target),
        attribute = Value(attribute),
        pattern = Value(pattern),
        expression = Value(expression);
  static Insertable<BlockRuleData> custom({
    Expression<int>? id,
    Expression<String>? groupId,
    Expression<int>? target,
    Expression<int>? attribute,
    Expression<int>? pattern,
    Expression<String>? expression,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (groupId != null) 'group_id': groupId,
      if (target != null) 'target': target,
      if (attribute != null) 'attribute': attribute,
      if (pattern != null) 'pattern': pattern,
      if (expression != null) 'expression': expression,
    });
  }

  BlockRuleCompanion copyWith(
      {Value<int>? id,
      Value<String>? groupId,
      Value<int>? target,
      Value<int>? attribute,
      Value<int>? pattern,
      Value<String>? expression}) {
    return BlockRuleCompanion(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      target: target ?? this.target,
      attribute: attribute ?? this.attribute,
      pattern: pattern ?? this.pattern,
      expression: expression ?? this.expression,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (groupId.present) {
      map['group_id'] = Variable<String>(groupId.value);
    }
    if (target.present) {
      map['target'] = Variable<int>(target.value);
    }
    if (attribute.present) {
      map['attribute'] = Variable<int>(attribute.value);
    }
    if (pattern.present) {
      map['pattern'] = Variable<int>(pattern.value);
    }
    if (expression.present) {
      map['expression'] = Variable<String>(expression.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BlockRuleCompanion(')
          ..write('id: $id, ')
          ..write('groupId: $groupId, ')
          ..write('target: $target, ')
          ..write('attribute: $attribute, ')
          ..write('pattern: $pattern, ')
          ..write('expression: $expression')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDb extends GeneratedDatabase {
  _$AppDb(QueryExecutor e) : super(e);
  late final $OldSuperResolutionInfoTable oldSuperResolutionInfo =
      $OldSuperResolutionInfoTable(this);
  late final $SuperResolutionInfoTable superResolutionInfo =
      $SuperResolutionInfoTable(this);
  late final $TagTable tag = $TagTable(this);
  late final $ArchiveDownloadedTable archiveDownloaded =
      $ArchiveDownloadedTable(this);
  late final $ArchiveDownloadedOldTable archiveDownloadedOld =
      $ArchiveDownloadedOldTable(this);
  late final $ArchiveGroupTable archiveGroup = $ArchiveGroupTable(this);
  late final $GalleryDownloadedTable galleryDownloaded =
      $GalleryDownloadedTable(this);
  late final $GalleryDownloadedOldTable galleryDownloadedOld =
      $GalleryDownloadedOldTable(this);
  late final $GalleryGroupTable galleryGroup = $GalleryGroupTable(this);
  late final $ImageTable image = $ImageTable(this);
  late final $GalleryHistoryTable galleryHistory = $GalleryHistoryTable(this);
  late final $GalleryHistoryV2Table galleryHistoryV2 =
      $GalleryHistoryV2Table(this);
  late final $TagCountTable tagCount = $TagCountTable(this);
  late final $DioCacheTable dioCache = $DioCacheTable(this);
  late final $BlockRuleTable blockRule = $BlockRuleTable(this);
  late final Index idxKey =
      Index('idx_key', 'CREATE INDEX idx_key ON tag (_key)');
  late final Index idxTagName =
      Index('idx_tagName', 'CREATE INDEX idx_tagName ON tag (tagName)');
  late final Index aIdxInsertTime = Index('a_idx_insert_time',
      'CREATE INDEX a_idx_insert_time ON archive_downloaded_v2 (insert_time)');
  late final Index aIdxSortOrder = Index('a_idx_sort_order',
      'CREATE INDEX a_idx_sort_order ON archive_downloaded_v2 (sort_order)');
  late final Index aIdxGroupName = Index('a_idx_group_name',
      'CREATE INDEX a_idx_group_name ON archive_downloaded_v2 (group_name)');
  late final Index aIdxTagRefreshTime = Index('a_idx_tag_refresh_time',
      'CREATE INDEX a_idx_tag_refresh_time ON archive_downloaded_v2 (tag_refresh_time)');
  late final Index gIdxInsertTime = Index('g_idx_insert_time',
      'CREATE INDEX g_idx_insert_time ON gallery_downloaded_v2 (insert_time)');
  late final Index gIdxSortOrder = Index('g_idx_sort_order',
      'CREATE INDEX g_idx_sort_order ON gallery_downloaded_v2 (sort_order)');
  late final Index gIdxGroupName = Index('g_idx_group_name',
      'CREATE INDEX g_idx_group_name ON gallery_downloaded_v2 (group_name)');
  late final Index gIdxTagRefreshTime = Index('g_idx_tag_refresh_time',
      'CREATE INDEX g_idx_tag_refresh_time ON gallery_downloaded_v2 (tag_refresh_time)');
  late final Index idxLastReadTime = Index('idx_last_read_time',
      'CREATE INDEX idx_last_read_time ON gallery_history_v2 (lastReadTime)');
  late final Index idxExpireDate = Index('idx_expire_date',
      'CREATE INDEX idx_expire_date ON dio_cache (expireDate)');
  late final Index idxUrl =
      Index('idx_url', 'CREATE INDEX idx_url ON dio_cache (url)');
  late final Index idxGroupId = Index(
      'idx_group_id', 'CREATE INDEX idx_group_id ON block_rule (group_id)');
  late final Index idxTarget =
      Index('idx_target', 'CREATE INDEX idx_target ON block_rule (target)');
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        oldSuperResolutionInfo,
        superResolutionInfo,
        tag,
        archiveDownloaded,
        archiveDownloadedOld,
        archiveGroup,
        galleryDownloaded,
        galleryDownloadedOld,
        galleryGroup,
        image,
        galleryHistory,
        galleryHistoryV2,
        tagCount,
        dioCache,
        blockRule,
        idxKey,
        idxTagName,
        aIdxInsertTime,
        aIdxSortOrder,
        aIdxGroupName,
        aIdxTagRefreshTime,
        gIdxInsertTime,
        gIdxSortOrder,
        gIdxGroupName,
        gIdxTagRefreshTime,
        idxLastReadTime,
        idxExpireDate,
        idxUrl,
        idxGroupId,
        idxTarget
      ];
}
