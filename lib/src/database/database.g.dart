// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class DioCache extends Table with TableInfo<DioCache, DioCacheData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  DioCache(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _cacheKeyMeta =
      const VerificationMeta('cacheKey');
  late final GeneratedColumn<String> cacheKey = GeneratedColumn<String>(
      'cacheKey', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL PRIMARY KEY');
  static const VerificationMeta _urlMeta = const VerificationMeta('url');
  late final GeneratedColumn<String> url = GeneratedColumn<String>(
      'url', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL');
  static const VerificationMeta _expireDateMeta =
      const VerificationMeta('expireDate');
  late final GeneratedColumn<DateTime> expireDate = GeneratedColumn<DateTime>(
      'expireDate', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL');
  static const VerificationMeta _contentMeta =
      const VerificationMeta('content');
  late final GeneratedColumn<Uint8List> content = GeneratedColumn<Uint8List>(
      'content', aliasedName, false,
      type: DriftSqlType.blob,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL');
  static const VerificationMeta _headersMeta =
      const VerificationMeta('headers');
  late final GeneratedColumn<Uint8List> headers = GeneratedColumn<Uint8List>(
      'headers', aliasedName, false,
      type: DriftSqlType.blob,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL');
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
  DioCache createAlias(String alias) {
    return DioCache(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
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

class TagCount extends Table with TableInfo<TagCount, TagCountData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  TagCount(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _namespaceWithKeyMeta =
      const VerificationMeta('namespaceWithKey');
  late final GeneratedColumn<String> namespaceWithKey = GeneratedColumn<String>(
      'namespaceWithKey', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL');
  static const VerificationMeta _countMeta = const VerificationMeta('count');
  late final GeneratedColumn<int> count = GeneratedColumn<int>(
      'count', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL');
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
  TagCount createAlias(String alias) {
    return TagCount(attachedDatabase, alias);
  }

  @override
  List<String> get customConstraints => const ['PRIMARY KEY(namespaceWithKey)'];
  @override
  bool get dontWriteConstraints => true;
}

class TagCountData extends DataClass implements Insertable<TagCountData> {
  final String namespaceWithKey;

  /// raw namespace&tagName
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

class SuperResolutionInfo extends Table
    with TableInfo<SuperResolutionInfo, SuperResolutionInfoData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  SuperResolutionInfo(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _gidMeta = const VerificationMeta('gid');
  late final GeneratedColumn<int> gid = GeneratedColumn<int>(
      'gid', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      $customConstraints: 'NOT NULL PRIMARY KEY');
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  late final GeneratedColumn<int> type = GeneratedColumn<int>(
      'type', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL');
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  late final GeneratedColumn<int> status = GeneratedColumn<int>(
      'status', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL');
  static const VerificationMeta _imageStatusesMeta =
      const VerificationMeta('imageStatuses');
  late final GeneratedColumn<String> imageStatuses = GeneratedColumn<String>(
      'imageStatuses', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL');
  @override
  List<GeneratedColumn> get $columns => [gid, type, status, imageStatuses];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'super_resolution_info';
  @override
  VerificationContext validateIntegrity(
      Insertable<SuperResolutionInfoData> instance,
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
          .read(DriftSqlType.string, data['${effectivePrefix}imageStatuses'])!,
    );
  }

  @override
  SuperResolutionInfo createAlias(String alias) {
    return SuperResolutionInfo(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
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
    map['imageStatuses'] = Variable<String>(imageStatuses);
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
  const SuperResolutionInfoCompanion({
    this.gid = const Value.absent(),
    this.type = const Value.absent(),
    this.status = const Value.absent(),
    this.imageStatuses = const Value.absent(),
  });
  SuperResolutionInfoCompanion.insert({
    this.gid = const Value.absent(),
    required int type,
    required int status,
    required String imageStatuses,
  })  : type = Value(type),
        status = Value(status),
        imageStatuses = Value(imageStatuses);
  static Insertable<SuperResolutionInfoData> custom({
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

  SuperResolutionInfoCompanion copyWith(
      {Value<int>? gid,
      Value<int>? type,
      Value<int>? status,
      Value<String>? imageStatuses}) {
    return SuperResolutionInfoCompanion(
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
    return (StringBuffer('SuperResolutionInfoCompanion(')
          ..write('gid: $gid, ')
          ..write('type: $type, ')
          ..write('status: $status, ')
          ..write('imageStatuses: $imageStatuses')
          ..write(')'))
        .toString();
  }
}

class TagBrowseProgressTable extends Table
    with TableInfo<TagBrowseProgressTable, TagBrowseProgress> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  TagBrowseProgressTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keywordMeta =
      const VerificationMeta('keyword');
  late final GeneratedColumn<String> keyword = GeneratedColumn<String>(
      'keyword', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL PRIMARY KEY');
  static const VerificationMeta _gidMeta = const VerificationMeta('gid');
  late final GeneratedColumn<int> gid = GeneratedColumn<int>(
      'gid', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL');
  @override
  List<GeneratedColumn> get $columns => [keyword, gid];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tag_browse_progress';
  @override
  VerificationContext validateIntegrity(Insertable<TagBrowseProgress> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('keyword')) {
      context.handle(_keywordMeta,
          keyword.isAcceptableOrUnknown(data['keyword']!, _keywordMeta));
    } else if (isInserting) {
      context.missing(_keywordMeta);
    }
    if (data.containsKey('gid')) {
      context.handle(
          _gidMeta, gid.isAcceptableOrUnknown(data['gid']!, _gidMeta));
    } else if (isInserting) {
      context.missing(_gidMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {keyword};
  @override
  TagBrowseProgress map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TagBrowseProgress(
      keyword: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}keyword'])!,
      gid: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}gid'])!,
    );
  }

  @override
  TagBrowseProgressTable createAlias(String alias) {
    return TagBrowseProgressTable(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class TagBrowseProgress extends DataClass
    implements Insertable<TagBrowseProgress> {
  final String keyword;
  final int gid;
  const TagBrowseProgress({required this.keyword, required this.gid});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['keyword'] = Variable<String>(keyword);
    map['gid'] = Variable<int>(gid);
    return map;
  }

  TagBrowseProgressCompanion toCompanion(bool nullToAbsent) {
    return TagBrowseProgressCompanion(
      keyword: Value(keyword),
      gid: Value(gid),
    );
  }

  factory TagBrowseProgress.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TagBrowseProgress(
      keyword: serializer.fromJson<String>(json['keyword']),
      gid: serializer.fromJson<int>(json['gid']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'keyword': serializer.toJson<String>(keyword),
      'gid': serializer.toJson<int>(gid),
    };
  }

  TagBrowseProgress copyWith({String? keyword, int? gid}) => TagBrowseProgress(
        keyword: keyword ?? this.keyword,
        gid: gid ?? this.gid,
      );
  @override
  String toString() {
    return (StringBuffer('TagBrowseProgress(')
          ..write('keyword: $keyword, ')
          ..write('gid: $gid')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(keyword, gid);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TagBrowseProgress &&
          other.keyword == this.keyword &&
          other.gid == this.gid);
}

class TagBrowseProgressCompanion extends UpdateCompanion<TagBrowseProgress> {
  final Value<String> keyword;
  final Value<int> gid;
  final Value<int> rowid;
  const TagBrowseProgressCompanion({
    this.keyword = const Value.absent(),
    this.gid = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TagBrowseProgressCompanion.insert({
    required String keyword,
    required int gid,
    this.rowid = const Value.absent(),
  })  : keyword = Value(keyword),
        gid = Value(gid);
  static Insertable<TagBrowseProgress> custom({
    Expression<String>? keyword,
    Expression<int>? gid,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (keyword != null) 'keyword': keyword,
      if (gid != null) 'gid': gid,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TagBrowseProgressCompanion copyWith(
      {Value<String>? keyword, Value<int>? gid, Value<int>? rowid}) {
    return TagBrowseProgressCompanion(
      keyword: keyword ?? this.keyword,
      gid: gid ?? this.gid,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (keyword.present) {
      map['keyword'] = Variable<String>(keyword.value);
    }
    if (gid.present) {
      map['gid'] = Variable<int>(gid.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TagBrowseProgressCompanion(')
          ..write('keyword: $keyword, ')
          ..write('gid: $gid, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class GalleryHistory extends Table
    with TableInfo<GalleryHistory, GalleryHistoryData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  GalleryHistory(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _gidMeta = const VerificationMeta('gid');
  late final GeneratedColumn<int> gid = GeneratedColumn<int>(
      'gid', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      $customConstraints: 'NOT NULL PRIMARY KEY');
  static const VerificationMeta _jsonBodyMeta =
      const VerificationMeta('jsonBody');
  late final GeneratedColumn<String> jsonBody = GeneratedColumn<String>(
      'jsonBody', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL');
  static const VerificationMeta _lastReadTimeMeta =
      const VerificationMeta('lastReadTime');
  late final GeneratedColumn<String> lastReadTime = GeneratedColumn<String>(
      'lastReadTime', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL');
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
  GalleryHistory createAlias(String alias) {
    return GalleryHistory(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
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

class Tag extends Table with TableInfo<Tag, TagData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Tag(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _namespaceMeta =
      const VerificationMeta('namespace');
  late final GeneratedColumn<String> namespace = GeneratedColumn<String>(
      'namespace', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL');
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
      '_key', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL');
  static const VerificationMeta _translatedNamespaceMeta =
      const VerificationMeta('translatedNamespace');
  late final GeneratedColumn<String> translatedNamespace =
      GeneratedColumn<String>('translatedNamespace', aliasedName, true,
          type: DriftSqlType.string,
          requiredDuringInsert: false,
          $customConstraints: '');
  static const VerificationMeta _tagNameMeta =
      const VerificationMeta('tagName');
  late final GeneratedColumn<String> tagName = GeneratedColumn<String>(
      'tagName', aliasedName, true,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      $customConstraints: '');
  static const VerificationMeta _fullTagNameMeta =
      const VerificationMeta('fullTagName');
  late final GeneratedColumn<String> fullTagName = GeneratedColumn<String>(
      'fullTagName', aliasedName, true,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      $customConstraints: '');
  static const VerificationMeta _introMeta = const VerificationMeta('intro');
  late final GeneratedColumn<String> intro = GeneratedColumn<String>(
      'intro', aliasedName, true,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      $customConstraints: '');
  static const VerificationMeta _linksMeta = const VerificationMeta('links');
  late final GeneratedColumn<String> links = GeneratedColumn<String>(
      'links', aliasedName, true,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      $customConstraints: '');
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
  Tag createAlias(String alias) {
    return Tag(attachedDatabase, alias);
  }

  @override
  List<String> get customConstraints => const ['PRIMARY KEY(namespace, _key)'];
  @override
  bool get dontWriteConstraints => true;
}

class TagData extends DataClass implements Insertable<TagData> {
  final String namespace;

  /// raw namespace of the tag
  final String key;

  /// raw tagName of the tag
  final String? translatedNamespace;

  /// translated namespace of the tag
  final String? tagName;

  /// translated tagName of the tag
  final String? fullTagName;

  /// full translated tagName of the tag(in html form)
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

class ArchiveDownloaded extends Table
    with TableInfo<ArchiveDownloaded, ArchiveDownloadedData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  ArchiveDownloaded(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _gidMeta = const VerificationMeta('gid');
  late final GeneratedColumn<int> gid = GeneratedColumn<int>(
      'gid', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL');
  static const VerificationMeta _tokenMeta = const VerificationMeta('token');
  late final GeneratedColumn<String> token = GeneratedColumn<String>(
      'token', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL');
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL');
  static const VerificationMeta _categoryMeta =
      const VerificationMeta('category');
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
      'category', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL');
  static const VerificationMeta _pageCountMeta =
      const VerificationMeta('pageCount');
  late final GeneratedColumn<int> pageCount = GeneratedColumn<int>(
      'pageCount', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL');
  static const VerificationMeta _galleryUrlMeta =
      const VerificationMeta('galleryUrl');
  late final GeneratedColumn<String> galleryUrl = GeneratedColumn<String>(
      'galleryUrl', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL');
  static const VerificationMeta _coverUrlMeta =
      const VerificationMeta('coverUrl');
  late final GeneratedColumn<String> coverUrl = GeneratedColumn<String>(
      'coverUrl', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL');
  static const VerificationMeta _uploaderMeta =
      const VerificationMeta('uploader');
  late final GeneratedColumn<String> uploader = GeneratedColumn<String>(
      'uploader', aliasedName, true,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      $customConstraints: '');
  static const VerificationMeta _sizeMeta = const VerificationMeta('size');
  late final GeneratedColumn<int> size = GeneratedColumn<int>(
      'size', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL');
  static const VerificationMeta _publishTimeMeta =
      const VerificationMeta('publishTime');
  late final GeneratedColumn<String> publishTime = GeneratedColumn<String>(
      'publishTime', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL');
  static const VerificationMeta _archiveStatusIndexMeta =
      const VerificationMeta('archiveStatusIndex');
  late final GeneratedColumn<int> archiveStatusIndex = GeneratedColumn<int>(
      'archiveStatusIndex', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL');
  static const VerificationMeta _archivePageUrlMeta =
      const VerificationMeta('archivePageUrl');
  late final GeneratedColumn<String> archivePageUrl = GeneratedColumn<String>(
      'archivePageUrl', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL');
  static const VerificationMeta _downloadPageUrlMeta =
      const VerificationMeta('downloadPageUrl');
  late final GeneratedColumn<String> downloadPageUrl = GeneratedColumn<String>(
      'downloadPageUrl', aliasedName, true,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      $customConstraints: '');
  static const VerificationMeta _downloadUrlMeta =
      const VerificationMeta('downloadUrl');
  late final GeneratedColumn<String> downloadUrl = GeneratedColumn<String>(
      'downloadUrl', aliasedName, true,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      $customConstraints: '');
  static const VerificationMeta _isOriginalMeta =
      const VerificationMeta('isOriginal');
  late final GeneratedColumn<bool> isOriginal = GeneratedColumn<bool>(
      'isOriginal', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL');
  static const VerificationMeta _insertTimeMeta =
      const VerificationMeta('insertTime');
  late final GeneratedColumn<String> insertTime = GeneratedColumn<String>(
      'insertTime', aliasedName, true,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      $customConstraints: '');
  static const VerificationMeta _sortOrderMeta =
      const VerificationMeta('sortOrder');
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
      'sortOrder', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      $customConstraints: 'NOT NULL DEFAULT 0',
      defaultValue: const CustomExpression('0'));
  static const VerificationMeta _groupNameMeta =
      const VerificationMeta('groupName');
  late final GeneratedColumn<String> groupName = GeneratedColumn<String>(
      'groupName', aliasedName, true,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      $customConstraints: '');
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
      Insertable<ArchiveDownloadedData> instance,
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
  ArchiveDownloaded createAlias(String alias) {
    return ArchiveDownloaded(attachedDatabase, alias);
  }

  @override
  List<String> get customConstraints => const ['PRIMARY KEY(gid, isOriginal)'];
  @override
  bool get dontWriteConstraints => true;
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
  final int archiveStatusIndex;
  final String archivePageUrl;
  final String? downloadPageUrl;
  final String? downloadUrl;
  final bool isOriginal;
  final String? insertTime;
  final int sortOrder;
  final String? groupName;
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
          int? archiveStatusIndex,
          String? archivePageUrl,
          Value<String?> downloadPageUrl = const Value.absent(),
          Value<String?> downloadUrl = const Value.absent(),
          bool? isOriginal,
          Value<String?> insertTime = const Value.absent(),
          int? sortOrder,
          Value<String?> groupName = const Value.absent()}) =>
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
          other.archiveStatusIndex == this.archiveStatusIndex &&
          other.archivePageUrl == this.archivePageUrl &&
          other.downloadPageUrl == this.downloadPageUrl &&
          other.downloadUrl == this.downloadUrl &&
          other.isOriginal == this.isOriginal &&
          other.insertTime == this.insertTime &&
          other.sortOrder == this.sortOrder &&
          other.groupName == this.groupName);
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
  final Value<int> archiveStatusIndex;
  final Value<String> archivePageUrl;
  final Value<String?> downloadPageUrl;
  final Value<String?> downloadUrl;
  final Value<bool> isOriginal;
  final Value<String?> insertTime;
  final Value<int> sortOrder;
  final Value<String?> groupName;
  final Value<int> rowid;
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
  ArchiveDownloadedCompanion.insert({
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
      Value<int>? archiveStatusIndex,
      Value<String>? archivePageUrl,
      Value<String?>? downloadPageUrl,
      Value<String?>? downloadUrl,
      Value<bool>? isOriginal,
      Value<String?>? insertTime,
      Value<int>? sortOrder,
      Value<String?>? groupName,
      Value<int>? rowid}) {
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

class ArchiveGroup extends Table
    with TableInfo<ArchiveGroup, ArchiveGroupData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  ArchiveGroup(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _groupNameMeta =
      const VerificationMeta('groupName');
  late final GeneratedColumn<String> groupName = GeneratedColumn<String>(
      'groupName', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL PRIMARY KEY');
  static const VerificationMeta _sortOrderMeta =
      const VerificationMeta('sortOrder');
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
      'sortOrder', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      $customConstraints: 'NOT NULL DEFAULT 0',
      defaultValue: const CustomExpression('0'));
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
  ArchiveGroup createAlias(String alias) {
    return ArchiveGroup(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
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

class GalleryDownloaded extends Table
    with TableInfo<GalleryDownloaded, GalleryDownloadedData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  GalleryDownloaded(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _gidMeta = const VerificationMeta('gid');
  late final GeneratedColumn<int> gid = GeneratedColumn<int>(
      'gid', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      $customConstraints: 'NOT NULL PRIMARY KEY');
  static const VerificationMeta _tokenMeta = const VerificationMeta('token');
  late final GeneratedColumn<String> token = GeneratedColumn<String>(
      'token', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL');
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL');
  static const VerificationMeta _categoryMeta =
      const VerificationMeta('category');
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
      'category', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL');
  static const VerificationMeta _pageCountMeta =
      const VerificationMeta('pageCount');
  late final GeneratedColumn<int> pageCount = GeneratedColumn<int>(
      'pageCount', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL');
  static const VerificationMeta _galleryUrlMeta =
      const VerificationMeta('galleryUrl');
  late final GeneratedColumn<String> galleryUrl = GeneratedColumn<String>(
      'galleryUrl', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL');
  static const VerificationMeta _oldVersionGalleryUrlMeta =
      const VerificationMeta('oldVersionGalleryUrl');
  late final GeneratedColumn<String> oldVersionGalleryUrl =
      GeneratedColumn<String>('oldVersionGalleryUrl', aliasedName, true,
          type: DriftSqlType.string,
          requiredDuringInsert: false,
          $customConstraints: '');
  static const VerificationMeta _uploaderMeta =
      const VerificationMeta('uploader');
  late final GeneratedColumn<String> uploader = GeneratedColumn<String>(
      'uploader', aliasedName, true,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      $customConstraints: '');
  static const VerificationMeta _publishTimeMeta =
      const VerificationMeta('publishTime');
  late final GeneratedColumn<String> publishTime = GeneratedColumn<String>(
      'publishTime', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL');
  static const VerificationMeta _downloadStatusIndexMeta =
      const VerificationMeta('downloadStatusIndex');
  late final GeneratedColumn<int> downloadStatusIndex = GeneratedColumn<int>(
      'downloadStatusIndex', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL');
  static const VerificationMeta _insertTimeMeta =
      const VerificationMeta('insertTime');
  late final GeneratedColumn<String> insertTime = GeneratedColumn<String>(
      'insertTime', aliasedName, true,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      $customConstraints: '');
  static const VerificationMeta _downloadOriginalImageMeta =
      const VerificationMeta('downloadOriginalImage');
  late final GeneratedColumn<bool> downloadOriginalImage =
      GeneratedColumn<bool>('downloadOriginalImage', aliasedName, false,
          type: DriftSqlType.bool,
          requiredDuringInsert: false,
          $customConstraints: 'NOT NULL DEFAULT FALSE',
          defaultValue: const CustomExpression('FALSE'));
  static const VerificationMeta _priorityMeta =
      const VerificationMeta('priority');
  late final GeneratedColumn<int> priority = GeneratedColumn<int>(
      'priority', aliasedName, true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      $customConstraints: '');
  static const VerificationMeta _sortOrderMeta =
      const VerificationMeta('sortOrder');
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
      'sortOrder', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      $customConstraints: 'NOT NULL DEFAULT 0',
      defaultValue: const CustomExpression('0'));
  static const VerificationMeta _groupNameMeta =
      const VerificationMeta('groupName');
  late final GeneratedColumn<String> groupName = GeneratedColumn<String>(
      'groupName', aliasedName, true,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      $customConstraints: '');
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
  GalleryDownloaded createAlias(String alias) {
    return GalleryDownloaded(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
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
  final String? insertTime;
  final bool downloadOriginalImage;
  final int? priority;
  final int sortOrder;
  final String? groupName;
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
          Value<String?> insertTime = const Value.absent(),
          bool? downloadOriginalImage,
          Value<int?> priority = const Value.absent(),
          int? sortOrder,
          Value<String?> groupName = const Value.absent()}) =>
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
        insertTime: insertTime.present ? insertTime.value : this.insertTime,
        downloadOriginalImage:
            downloadOriginalImage ?? this.downloadOriginalImage,
        priority: priority.present ? priority.value : this.priority,
        sortOrder: sortOrder ?? this.sortOrder,
        groupName: groupName.present ? groupName.value : this.groupName,
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
          other.groupName == this.groupName);
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
  final Value<String?> insertTime;
  final Value<bool> downloadOriginalImage;
  final Value<int?> priority;
  final Value<int> sortOrder;
  final Value<String?> groupName;
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
      Value<String?>? insertTime,
      Value<bool>? downloadOriginalImage,
      Value<int?>? priority,
      Value<int>? sortOrder,
      Value<String?>? groupName}) {
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
          ..write('groupName: $groupName')
          ..write(')'))
        .toString();
  }
}

class Image extends Table with TableInfo<Image, ImageData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Image(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _urlMeta = const VerificationMeta('url');
  late final GeneratedColumn<String> url = GeneratedColumn<String>(
      'url', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL');
  static const VerificationMeta _serialNoMeta =
      const VerificationMeta('serialNo');
  late final GeneratedColumn<int> serialNo = GeneratedColumn<int>(
      'serialNo', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL');
  static const VerificationMeta _gidMeta = const VerificationMeta('gid');
  late final GeneratedColumn<int> gid = GeneratedColumn<int>(
      'gid', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL REFERENCES gallery_downloaded(gid)');
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
      'path', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL');
  static const VerificationMeta _imageHashMeta =
      const VerificationMeta('imageHash');
  late final GeneratedColumn<String> imageHash = GeneratedColumn<String>(
      'imageHash', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL');
  static const VerificationMeta _downloadStatusIndexMeta =
      const VerificationMeta('downloadStatusIndex');
  late final GeneratedColumn<int> downloadStatusIndex = GeneratedColumn<int>(
      'downloadStatusIndex', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL');
  @override
  List<GeneratedColumn> get $columns =>
      [url, serialNo, gid, path, imageHash, downloadStatusIndex];
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
    if (data.containsKey('gid')) {
      context.handle(
          _gidMeta, gid.isAcceptableOrUnknown(data['gid']!, _gidMeta));
    } else if (isInserting) {
      context.missing(_gidMeta);
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
      url: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}url'])!,
      serialNo: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}serialNo'])!,
      gid: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}gid'])!,
      path: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}path'])!,
      imageHash: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}imageHash'])!,
      downloadStatusIndex: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}downloadStatusIndex'])!,
    );
  }

  @override
  Image createAlias(String alias) {
    return Image(attachedDatabase, alias);
  }

  @override
  List<String> get customConstraints => const ['PRIMARY KEY(gid, serialNo)'];
  @override
  bool get dontWriteConstraints => true;
}

class ImageData extends DataClass implements Insertable<ImageData> {
  final String url;
  final int serialNo;
  final int gid;
  final String path;
  final String imageHash;
  final int downloadStatusIndex;
  const ImageData(
      {required this.url,
      required this.serialNo,
      required this.gid,
      required this.path,
      required this.imageHash,
      required this.downloadStatusIndex});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['url'] = Variable<String>(url);
    map['serialNo'] = Variable<int>(serialNo);
    map['gid'] = Variable<int>(gid);
    map['path'] = Variable<String>(path);
    map['imageHash'] = Variable<String>(imageHash);
    map['downloadStatusIndex'] = Variable<int>(downloadStatusIndex);
    return map;
  }

  ImageCompanion toCompanion(bool nullToAbsent) {
    return ImageCompanion(
      url: Value(url),
      serialNo: Value(serialNo),
      gid: Value(gid),
      path: Value(path),
      imageHash: Value(imageHash),
      downloadStatusIndex: Value(downloadStatusIndex),
    );
  }

  factory ImageData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ImageData(
      url: serializer.fromJson<String>(json['url']),
      serialNo: serializer.fromJson<int>(json['serialNo']),
      gid: serializer.fromJson<int>(json['gid']),
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
      'url': serializer.toJson<String>(url),
      'serialNo': serializer.toJson<int>(serialNo),
      'gid': serializer.toJson<int>(gid),
      'path': serializer.toJson<String>(path),
      'imageHash': serializer.toJson<String>(imageHash),
      'downloadStatusIndex': serializer.toJson<int>(downloadStatusIndex),
    };
  }

  ImageData copyWith(
          {String? url,
          int? serialNo,
          int? gid,
          String? path,
          String? imageHash,
          int? downloadStatusIndex}) =>
      ImageData(
        url: url ?? this.url,
        serialNo: serialNo ?? this.serialNo,
        gid: gid ?? this.gid,
        path: path ?? this.path,
        imageHash: imageHash ?? this.imageHash,
        downloadStatusIndex: downloadStatusIndex ?? this.downloadStatusIndex,
      );
  @override
  String toString() {
    return (StringBuffer('ImageData(')
          ..write('url: $url, ')
          ..write('serialNo: $serialNo, ')
          ..write('gid: $gid, ')
          ..write('path: $path, ')
          ..write('imageHash: $imageHash, ')
          ..write('downloadStatusIndex: $downloadStatusIndex')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(url, serialNo, gid, path, imageHash, downloadStatusIndex);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ImageData &&
          other.url == this.url &&
          other.serialNo == this.serialNo &&
          other.gid == this.gid &&
          other.path == this.path &&
          other.imageHash == this.imageHash &&
          other.downloadStatusIndex == this.downloadStatusIndex);
}

class ImageCompanion extends UpdateCompanion<ImageData> {
  final Value<String> url;
  final Value<int> serialNo;
  final Value<int> gid;
  final Value<String> path;
  final Value<String> imageHash;
  final Value<int> downloadStatusIndex;
  final Value<int> rowid;
  const ImageCompanion({
    this.url = const Value.absent(),
    this.serialNo = const Value.absent(),
    this.gid = const Value.absent(),
    this.path = const Value.absent(),
    this.imageHash = const Value.absent(),
    this.downloadStatusIndex = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ImageCompanion.insert({
    required String url,
    required int serialNo,
    required int gid,
    required String path,
    required String imageHash,
    required int downloadStatusIndex,
    this.rowid = const Value.absent(),
  })  : url = Value(url),
        serialNo = Value(serialNo),
        gid = Value(gid),
        path = Value(path),
        imageHash = Value(imageHash),
        downloadStatusIndex = Value(downloadStatusIndex);
  static Insertable<ImageData> custom({
    Expression<String>? url,
    Expression<int>? serialNo,
    Expression<int>? gid,
    Expression<String>? path,
    Expression<String>? imageHash,
    Expression<int>? downloadStatusIndex,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (url != null) 'url': url,
      if (serialNo != null) 'serialNo': serialNo,
      if (gid != null) 'gid': gid,
      if (path != null) 'path': path,
      if (imageHash != null) 'imageHash': imageHash,
      if (downloadStatusIndex != null)
        'downloadStatusIndex': downloadStatusIndex,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ImageCompanion copyWith(
      {Value<String>? url,
      Value<int>? serialNo,
      Value<int>? gid,
      Value<String>? path,
      Value<String>? imageHash,
      Value<int>? downloadStatusIndex,
      Value<int>? rowid}) {
    return ImageCompanion(
      url: url ?? this.url,
      serialNo: serialNo ?? this.serialNo,
      gid: gid ?? this.gid,
      path: path ?? this.path,
      imageHash: imageHash ?? this.imageHash,
      downloadStatusIndex: downloadStatusIndex ?? this.downloadStatusIndex,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (url.present) {
      map['url'] = Variable<String>(url.value);
    }
    if (serialNo.present) {
      map['serialNo'] = Variable<int>(serialNo.value);
    }
    if (gid.present) {
      map['gid'] = Variable<int>(gid.value);
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
          ..write('url: $url, ')
          ..write('serialNo: $serialNo, ')
          ..write('gid: $gid, ')
          ..write('path: $path, ')
          ..write('imageHash: $imageHash, ')
          ..write('downloadStatusIndex: $downloadStatusIndex, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class GalleryGroup extends Table
    with TableInfo<GalleryGroup, GalleryGroupData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  GalleryGroup(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _groupNameMeta =
      const VerificationMeta('groupName');
  late final GeneratedColumn<String> groupName = GeneratedColumn<String>(
      'groupName', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL PRIMARY KEY');
  static const VerificationMeta _sortOrderMeta =
      const VerificationMeta('sortOrder');
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
      'sortOrder', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      $customConstraints: 'NOT NULL DEFAULT 0',
      defaultValue: const CustomExpression('0'));
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
  GalleryGroup createAlias(String alias) {
    return GalleryGroup(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
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

abstract class _$AppDb extends GeneratedDatabase {
  _$AppDb(QueryExecutor e) : super(e);
  late final DioCache dioCache = DioCache(this);
  late final Index idxExpireDate = Index('idx_expire_date',
      'CREATE INDEX IF NOT EXISTS idx_expire_date ON dio_cache (expireDate)');
  late final Index idxUrl =
      Index('idx_url', 'CREATE INDEX IF NOT EXISTS idx_url ON dio_cache (url)');
  late final TagCount tagCount = TagCount(this);
  late final SuperResolutionInfo superResolutionInfo =
      SuperResolutionInfo(this);
  late final TagBrowseProgressTable tagBrowseProgress =
      TagBrowseProgressTable(this);
  late final GalleryHistory galleryHistory = GalleryHistory(this);
  late final Tag tag = Tag(this);
  late final ArchiveDownloaded archiveDownloaded = ArchiveDownloaded(this);
  late final ArchiveGroup archiveGroup = ArchiveGroup(this);
  late final GalleryDownloaded galleryDownloaded = GalleryDownloaded(this);
  late final Image image = Image(this);
  late final GalleryGroup galleryGroup = GalleryGroup(this);
  Selectable<DioCacheData> selectByCacheKey(String cacheKey) {
    return customSelect('SELECT * FROM dio_cache WHERE cacheKey = ?1',
        variables: [
          Variable<String>(cacheKey)
        ],
        readsFrom: {
          dioCache,
        }).asyncMap(dioCache.mapFromRow);
  }

  Future<int> insertCache(String cacheKey, String url, DateTime date,
      Uint8List content, Uint8List header) {
    return customInsert(
      'INSERT INTO dio_cache VALUES (?1, ?2, ?3, ?4, ?5)',
      variables: [
        Variable<String>(cacheKey),
        Variable<String>(url),
        Variable<DateTime>(date),
        Variable<Uint8List>(content),
        Variable<Uint8List>(header)
      ],
      updates: {dioCache},
    );
  }

  Future<int> insertOrUpdateCache(String cacheKey, String url,
      DateTime expireDate, Uint8List content, Uint8List headers) {
    return customInsert(
      'INSERT OR REPLACE INTO dio_cache VALUES (?1, ?2, ?3, ?4, ?5)',
      variables: [
        Variable<String>(cacheKey),
        Variable<String>(url),
        Variable<DateTime>(expireDate),
        Variable<Uint8List>(content),
        Variable<Uint8List>(headers)
      ],
      updates: {dioCache},
    );
  }

  Future<int> deleteByCacheKey(String cacheKey) {
    return customUpdate(
      'DELETE FROM dio_cache WHERE cacheKey = ?1',
      variables: [Variable<String>(cacheKey)],
      updates: {dioCache},
      updateKind: UpdateKind.delete,
    );
  }

  Future<int> deleteCacheByDate(DateTime date) {
    return customUpdate(
      'DELETE FROM dio_cache WHERE expireDate < ?1',
      variables: [Variable<DateTime>(date)],
      updates: {dioCache},
      updateKind: UpdateKind.delete,
    );
  }

  Future<int> deleteCacheLikeUrl(String url) {
    return customUpdate(
      'DELETE FROM dio_cache WHERE url LIKE ?1',
      variables: [Variable<String>(url)],
      updates: {dioCache},
      updateKind: UpdateKind.delete,
    );
  }

  Future<int> deleteAllCache() {
    return customUpdate(
      'DELETE FROM dio_cache',
      variables: [],
      updates: {dioCache},
      updateKind: UpdateKind.delete,
    );
  }

  Selectable<SuperResolutionInfoData> selectAllSuperResolutionInfo() {
    return customSelect('SELECT * FROM super_resolution_info',
        variables: [],
        readsFrom: {
          superResolutionInfo,
        }).asyncMap(superResolutionInfo.mapFromRow);
  }

  Future<int> insertSuperResolutionInfo(
      int gid, int type, int status, String imageStatuses) {
    return customInsert(
      'INSERT INTO super_resolution_info VALUES (?1, ?2, ?3, ?4)',
      variables: [
        Variable<int>(gid),
        Variable<int>(type),
        Variable<int>(status),
        Variable<String>(imageStatuses)
      ],
      updates: {superResolutionInfo},
    );
  }

  Future<int> updateSuperResolutionInfoStatus(
      int status, String imageStatuses, int gid) {
    return customUpdate(
      'UPDATE super_resolution_info SET status = ?1, imageStatuses = ?2 WHERE gid = ?3',
      variables: [
        Variable<int>(status),
        Variable<String>(imageStatuses),
        Variable<int>(gid)
      ],
      updates: {superResolutionInfo},
      updateKind: UpdateKind.update,
    );
  }

  Future<int> deleteSuperResolutionInfo(int gid) {
    return customUpdate(
      'DELETE FROM super_resolution_info WHERE gid = ?1',
      variables: [Variable<int>(gid)],
      updates: {superResolutionInfo},
      updateKind: UpdateKind.delete,
    );
  }

  Selectable<TagBrowseProgress> selectTagBrowseProgress(String keyword) {
    return customSelect('SELECT * FROM tag_browse_progress WHERE keyword = ?1',
        variables: [
          Variable<String>(keyword)
        ],
        readsFrom: {
          tagBrowseProgress,
        }).asyncMap(tagBrowseProgress.mapFromRow);
  }

  Future<int> updateTagBrowseProgress(String keyword, int gid) {
    return customInsert(
      'INSERT OR IGNORE INTO tag_browse_progress (keyword, gid) VALUES (?1, ?2) ON CONFLICT (keyword) DO UPDATE SET gid = ?2 AND gid > ?2 WHERE keyword = ?1',
      variables: [Variable<String>(keyword), Variable<int>(gid)],
      updates: {tagBrowseProgress},
    );
  }

  Selectable<GalleryHistoryData> selectHistorys() {
    return customSelect(
        'SELECT * FROM gallery_history ORDER BY lastReadTime DESC',
        variables: [],
        readsFrom: {
          galleryHistory,
        }).asyncMap(galleryHistory.mapFromRow);
  }

  Future<int> insertHistory(int gid, String jsonBody, String lastReadTime) {
    return customInsert(
      'INSERT INTO gallery_history VALUES (?1, ?2, ?3)',
      variables: [
        Variable<int>(gid),
        Variable<String>(jsonBody),
        Variable<String>(lastReadTime)
      ],
      updates: {galleryHistory},
    );
  }

  Future<int> updateHistoryLastReadTime(String lastReadTime, int gid) {
    return customUpdate(
      'UPDATE gallery_history SET lastReadTime = ?1 WHERE gid = ?2',
      variables: [Variable<String>(lastReadTime), Variable<int>(gid)],
      updates: {galleryHistory},
      updateKind: UpdateKind.update,
    );
  }

  Future<int> deleteHistory(int gid) {
    return customUpdate(
      'DELETE FROM gallery_history WHERE gid = ?1',
      variables: [Variable<int>(gid)],
      updates: {galleryHistory},
      updateKind: UpdateKind.delete,
    );
  }

  Future<int> deleteAllHistorys() {
    return customUpdate(
      'DELETE FROM gallery_history',
      variables: [],
      updates: {galleryHistory},
      updateKind: UpdateKind.delete,
    );
  }

  Selectable<TagData> selectTagByNamespaceAndKey(String namespace, String key) {
    return customSelect('SELECT * FROM tag WHERE namespace = ?1 AND _key = ?2',
        variables: [
          Variable<String>(namespace),
          Variable<String>(key)
        ],
        readsFrom: {
          tag,
        }).asyncMap(tag.mapFromRow);
  }

  Selectable<TagData> selectTagsByKey(String key) {
    return customSelect('SELECT * FROM tag WHERE _key = ?1', variables: [
      Variable<String>(key)
    ], readsFrom: {
      tag,
    }).asyncMap(tag.mapFromRow);
  }

  Selectable<TagData> selectAllTags() {
    return customSelect('SELECT * FROM tag', variables: [], readsFrom: {
      tag,
    }).asyncMap(tag.mapFromRow);
  }

  Selectable<TagData> searchTags(String pattern) {
    return customSelect(
        'SELECT * FROM tag WHERE _key LIKE ?1 OR tagName LIKE ?1 LIMIT 35',
        variables: [
          Variable<String>(pattern)
        ],
        readsFrom: {
          tag,
        }).asyncMap(tag.mapFromRow);
  }

  Future<int> insertTag(
      String namespace,
      String key,
      String? translatedNamespace,
      String? tagName,
      String? fullTagName,
      String? intro,
      String? links) {
    return customInsert(
      'INSERT INTO tag VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)',
      variables: [
        Variable<String>(namespace),
        Variable<String>(key),
        Variable<String>(translatedNamespace),
        Variable<String>(tagName),
        Variable<String>(fullTagName),
        Variable<String>(intro),
        Variable<String>(links)
      ],
      updates: {tag},
    );
  }

  Future<int> deleteAllTags() {
    return customUpdate(
      'DELETE FROM tag',
      variables: [],
      updates: {tag},
      updateKind: UpdateKind.delete,
    );
  }

  Selectable<ArchiveDownloadedData> selectArchives() {
    return customSelect(
        'SELECT * FROM archive_downloaded ORDER BY insertTime DESC',
        variables: [],
        readsFrom: {
          archiveDownloaded,
        }).asyncMap(archiveDownloaded.mapFromRow);
  }

  Future<int> insertArchive(
      int gid,
      String token,
      String title,
      String category,
      int pageCount,
      String galleryUrl,
      String coverUrl,
      String? uploader,
      int size,
      String publishTime,
      int archiveStatusIndex,
      String archivePageUrl,
      String? downloadPageUrl,
      String? downloadUrl,
      bool isOriginal,
      String? insertTime,
      String? groupName) {
    return customInsert(
      'INSERT INTO archive_downloaded (gid, token, title, category, pageCount, galleryUrl, coverUrl, uploader, size, publishTime, archiveStatusIndex, archivePageUrl, downloadPageUrl, downloadUrl, isOriginal, insertTime, groupName) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12, ?13, ?14, ?15, ?16, ?17)',
      variables: [
        Variable<int>(gid),
        Variable<String>(token),
        Variable<String>(title),
        Variable<String>(category),
        Variable<int>(pageCount),
        Variable<String>(galleryUrl),
        Variable<String>(coverUrl),
        Variable<String>(uploader),
        Variable<int>(size),
        Variable<String>(publishTime),
        Variable<int>(archiveStatusIndex),
        Variable<String>(archivePageUrl),
        Variable<String>(downloadPageUrl),
        Variable<String>(downloadUrl),
        Variable<bool>(isOriginal),
        Variable<String>(insertTime),
        Variable<String>(groupName)
      ],
      updates: {archiveDownloaded},
    );
  }

  Future<int> deleteArchive(int gid, bool isOriginal) {
    return customUpdate(
      'DELETE FROM archive_downloaded WHERE gid = ?1 AND isOriginal = ?2',
      variables: [Variable<int>(gid), Variable<bool>(isOriginal)],
      updates: {archiveDownloaded},
      updateKind: UpdateKind.delete,
    );
  }

  Future<int> updateArchive(
      int archiveStatusIndex,
      String? downloadPageUrl,
      String? downloadUrl,
      int sortOrder,
      String? groupName,
      int gid,
      bool isOriginal) {
    return customUpdate(
      'UPDATE archive_downloaded SET archiveStatusIndex = ?1, downloadPageUrl = ?2, downloadUrl = ?3, sortOrder = ?4, groupName = ?5 WHERE gid = ?6 AND isOriginal = ?7',
      variables: [
        Variable<int>(archiveStatusIndex),
        Variable<String>(downloadPageUrl),
        Variable<String>(downloadUrl),
        Variable<int>(sortOrder),
        Variable<String>(groupName),
        Variable<int>(gid),
        Variable<bool>(isOriginal)
      ],
      updates: {archiveDownloaded},
      updateKind: UpdateKind.update,
    );
  }

  Selectable<ArchiveGroupData> selectArchiveGroups() {
    return customSelect('SELECT * FROM archive_group ORDER BY sortOrder',
        variables: [],
        readsFrom: {
          archiveGroup,
        }).asyncMap(archiveGroup.mapFromRow);
  }

  Future<int> renameArchiveGroup(String newGroupName, String oldGroupName) {
    return customUpdate(
      'UPDATE archive_group SET groupName = ?1 WHERE groupName = ?2',
      variables: [
        Variable<String>(newGroupName),
        Variable<String>(oldGroupName)
      ],
      updates: {archiveGroup},
      updateKind: UpdateKind.update,
    );
  }

  Future<int> updateArchiveGroupOrder(int sortOrder, String groupName) {
    return customUpdate(
      'UPDATE archive_group SET sortOrder = ?1 WHERE groupName = ?2',
      variables: [Variable<int>(sortOrder), Variable<String>(groupName)],
      updates: {archiveGroup},
      updateKind: UpdateKind.update,
    );
  }

  Future<int> reGroupArchive(String? newGroupName, String? oldGroupName) {
    return customUpdate(
      'UPDATE archive_downloaded SET groupName = ?1 WHERE groupName = ?2',
      variables: [
        Variable<String>(newGroupName),
        Variable<String>(oldGroupName)
      ],
      updates: {archiveDownloaded},
      updateKind: UpdateKind.update,
    );
  }

  Future<int> deleteArchiveGroup(String groupName) {
    return customUpdate(
      'DELETE FROM archive_group WHERE groupName = ?1',
      variables: [Variable<String>(groupName)],
      updates: {archiveGroup},
      updateKind: UpdateKind.delete,
    );
  }

  Selectable<SelectGallerysWithImagesResult> selectGallerysWithImages() {
    return customSelect(
        'SELECT g.gid, g.token, g.title, g.category, g.pageCount, g.galleryUrl, g.oldVersionGalleryUrl, g.uploader, g.publishTime, g.downloadStatusIndex AS galleryDownloadStatusIndex, g.insertTime, g.downloadOriginalImage, g.priority, g.sortOrder, g.groupName, i.url, i.serialNo, i.path, i.imageHash, i.downloadStatusIndex AS imageDownloadStatusIndex FROM gallery_downloaded AS g LEFT JOIN image AS i ON g.gid = i.gid ORDER BY insertTime DESC, serialNo',
        variables: [],
        readsFrom: {
          galleryDownloaded,
          image,
        }).map((QueryRow row) => SelectGallerysWithImagesResult(
          gid: row.read<int>('gid'),
          token: row.read<String>('token'),
          title: row.read<String>('title'),
          category: row.read<String>('category'),
          pageCount: row.read<int>('pageCount'),
          galleryUrl: row.read<String>('galleryUrl'),
          oldVersionGalleryUrl:
              row.readNullable<String>('oldVersionGalleryUrl'),
          uploader: row.readNullable<String>('uploader'),
          publishTime: row.read<String>('publishTime'),
          galleryDownloadStatusIndex:
              row.read<int>('galleryDownloadStatusIndex'),
          insertTime: row.readNullable<String>('insertTime'),
          downloadOriginalImage: row.read<bool>('downloadOriginalImage'),
          priority: row.readNullable<int>('priority'),
          sortOrder: row.read<int>('sortOrder'),
          groupName: row.readNullable<String>('groupName'),
          url: row.readNullable<String>('url'),
          serialNo: row.readNullable<int>('serialNo'),
          path: row.readNullable<String>('path'),
          imageHash: row.readNullable<String>('imageHash'),
          imageDownloadStatusIndex:
              row.readNullable<int>('imageDownloadStatusIndex'),
        ));
  }

  Selectable<GalleryDownloadedData> selectGallerys() {
    return customSelect(
        'SELECT * FROM gallery_downloaded ORDER BY insertTime DESC',
        variables: [],
        readsFrom: {
          galleryDownloaded,
        }).asyncMap(galleryDownloaded.mapFromRow);
  }

  Future<int> insertGallery(
      int gid,
      String token,
      String title,
      String category,
      int pageCount,
      String galleryUrl,
      String? oldVersionGalleryUrl,
      String? uploader,
      String publishTime,
      int downloadStatusIndex,
      String? insertTime,
      bool downloadOriginalImage,
      int? priority,
      String? groupName) {
    return customInsert(
      'INSERT INTO gallery_downloaded (gid, token, title, category, pageCount, galleryUrl, oldVersionGalleryUrl, uploader, publishTime, downloadStatusIndex, insertTime, downloadOriginalImage, priority, groupName) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12, ?13, ?14)',
      variables: [
        Variable<int>(gid),
        Variable<String>(token),
        Variable<String>(title),
        Variable<String>(category),
        Variable<int>(pageCount),
        Variable<String>(galleryUrl),
        Variable<String>(oldVersionGalleryUrl),
        Variable<String>(uploader),
        Variable<String>(publishTime),
        Variable<int>(downloadStatusIndex),
        Variable<String>(insertTime),
        Variable<bool>(downloadOriginalImage),
        Variable<int>(priority),
        Variable<String>(groupName)
      ],
      updates: {galleryDownloaded},
    );
  }

  Future<int> deleteGallery(int gid) {
    return customUpdate(
      'DELETE FROM gallery_downloaded WHERE gid = ?1',
      variables: [Variable<int>(gid)],
      updates: {galleryDownloaded},
      updateKind: UpdateKind.delete,
    );
  }

  Future<int> updateGallery(int downloadStatusIndex, int gid) {
    return customUpdate(
      'UPDATE gallery_downloaded SET downloadStatusIndex = ?1 WHERE gid = ?2',
      variables: [Variable<int>(downloadStatusIndex), Variable<int>(gid)],
      updates: {galleryDownloaded},
      updateKind: UpdateKind.update,
    );
  }

  Future<int> updateGalleryPriority(int? priority, int gid) {
    return customUpdate(
      'UPDATE gallery_downloaded SET priority = ?1 WHERE gid = ?2',
      variables: [Variable<int>(priority), Variable<int>(gid)],
      updates: {galleryDownloaded},
      updateKind: UpdateKind.update,
    );
  }

  Future<int> updateGalleryOrder(int sortOrder, int gid) {
    return customUpdate(
      'UPDATE gallery_downloaded SET sortOrder = ?1 WHERE gid = ?2',
      variables: [Variable<int>(sortOrder), Variable<int>(gid)],
      updates: {galleryDownloaded},
      updateKind: UpdateKind.update,
    );
  }

  Future<int> updateGalleryGroup(String? groupName, int gid) {
    return customUpdate(
      'UPDATE gallery_downloaded SET groupName = ?1 WHERE gid = ?2',
      variables: [Variable<String>(groupName), Variable<int>(gid)],
      updates: {galleryDownloaded},
      updateKind: UpdateKind.update,
    );
  }

  Selectable<GalleryDownloadedData> selectImagesByGalleryId(int gid) {
    return customSelect('SELECT * FROM gallery_downloaded WHERE gid = ?1',
        variables: [
          Variable<int>(gid)
        ],
        readsFrom: {
          galleryDownloaded,
        }).asyncMap(galleryDownloaded.mapFromRow);
  }

  Future<int> insertImage(String url, int serialNo, int gid, String path,
      String imageHash, int downloadStatusIndex) {
    return customInsert(
      'INSERT INTO image VALUES (?1, ?2, ?3, ?4, ?5, ?6)',
      variables: [
        Variable<String>(url),
        Variable<int>(serialNo),
        Variable<int>(gid),
        Variable<String>(path),
        Variable<String>(imageHash),
        Variable<int>(downloadStatusIndex)
      ],
      updates: {image},
    );
  }

  Future<int> updateImageStatus(int downloadStatusIndex, int gid, String url) {
    return customUpdate(
      'UPDATE image SET downloadStatusIndex = ?1 WHERE gid = ?2 AND url = ?3',
      variables: [
        Variable<int>(downloadStatusIndex),
        Variable<int>(gid),
        Variable<String>(url)
      ],
      updates: {image},
      updateKind: UpdateKind.update,
    );
  }

  Future<int> updateImagePath(String path, int gid, String url) {
    return customUpdate(
      'UPDATE image SET path = ?1 WHERE gid = ?2 AND url = ?3',
      variables: [
        Variable<String>(path),
        Variable<int>(gid),
        Variable<String>(url)
      ],
      updates: {image},
      updateKind: UpdateKind.update,
    );
  }

  Future<int> updateImageUrl(String newUrl, int gid, int serialNo) {
    return customUpdate(
      'UPDATE image SET url = ?1 WHERE gid = ?2 AND serialNo = ?3',
      variables: [
        Variable<String>(newUrl),
        Variable<int>(gid),
        Variable<int>(serialNo)
      ],
      updates: {image},
      updateKind: UpdateKind.update,
    );
  }

  Future<int> deleteImage(int gid, String url) {
    return customUpdate(
      'DELETE FROM image WHERE gid = ?1 AND url = ?2',
      variables: [Variable<int>(gid), Variable<String>(url)],
      updates: {image},
      updateKind: UpdateKind.delete,
    );
  }

  Future<int> deleteImagesWithGid(int gid) {
    return customUpdate(
      'DELETE FROM image WHERE gid = ?1',
      variables: [Variable<int>(gid)],
      updates: {image},
      updateKind: UpdateKind.delete,
    );
  }

  Selectable<GalleryGroupData> selectGalleryGroups() {
    return customSelect('SELECT * FROM gallery_group ORDER BY sortOrder',
        variables: [],
        readsFrom: {
          galleryGroup,
        }).asyncMap(galleryGroup.mapFromRow);
  }

  Future<int> renameGalleryGroup(String newGroupName, String oldGroupName) {
    return customUpdate(
      'UPDATE gallery_group SET groupName = ?1 WHERE groupName = ?2',
      variables: [
        Variable<String>(newGroupName),
        Variable<String>(oldGroupName)
      ],
      updates: {galleryGroup},
      updateKind: UpdateKind.update,
    );
  }

  Future<int> updateGalleryGroupOrder(int sortOrder, String groupName) {
    return customUpdate(
      'UPDATE gallery_group SET sortOrder = ?1 WHERE groupName = ?2',
      variables: [Variable<int>(sortOrder), Variable<String>(groupName)],
      updates: {galleryGroup},
      updateKind: UpdateKind.update,
    );
  }

  Future<int> reGroupGallery(String? newGroupName, String? oldGroupName) {
    return customUpdate(
      'UPDATE gallery_downloaded SET groupName = ?1 WHERE groupName = ?2',
      variables: [
        Variable<String>(newGroupName),
        Variable<String>(oldGroupName)
      ],
      updates: {galleryDownloaded},
      updateKind: UpdateKind.update,
    );
  }

  Future<int> deleteGalleryGroup(String groupName) {
    return customUpdate(
      'DELETE FROM gallery_group WHERE groupName = ?1',
      variables: [Variable<String>(groupName)],
      updates: {galleryGroup},
      updateKind: UpdateKind.delete,
    );
  }

  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        dioCache,
        idxExpireDate,
        idxUrl,
        tagCount,
        superResolutionInfo,
        tagBrowseProgress,
        galleryHistory,
        tag,
        archiveDownloaded,
        archiveGroup,
        galleryDownloaded,
        image,
        galleryGroup
      ];
}

class SelectGallerysWithImagesResult {
  final int gid;
  final String token;
  final String title;
  final String category;
  final int pageCount;
  final String galleryUrl;
  final String? oldVersionGalleryUrl;
  final String? uploader;
  final String publishTime;
  final int galleryDownloadStatusIndex;
  final String? insertTime;
  final bool downloadOriginalImage;
  final int? priority;
  final int sortOrder;
  final String? groupName;
  final String? url;
  final int? serialNo;
  final String? path;
  final String? imageHash;
  final int? imageDownloadStatusIndex;
  SelectGallerysWithImagesResult({
    required this.gid,
    required this.token,
    required this.title,
    required this.category,
    required this.pageCount,
    required this.galleryUrl,
    this.oldVersionGalleryUrl,
    this.uploader,
    required this.publishTime,
    required this.galleryDownloadStatusIndex,
    this.insertTime,
    required this.downloadOriginalImage,
    this.priority,
    required this.sortOrder,
    this.groupName,
    this.url,
    this.serialNo,
    this.path,
    this.imageHash,
    this.imageDownloadStatusIndex,
  });
}
