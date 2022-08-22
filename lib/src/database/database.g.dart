// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// **************************************************************************
// MoorGenerator
// **************************************************************************

// ignore_for_file: type=lint
class TagData extends DataClass implements Insertable<TagData> {
  final String namespace;
  final String key;
  final String? translatedNamespace;
  final String? tagName;
  final String? fullTagName;
  final String? intro;
  final String? links;
  TagData(
      {required this.namespace,
      required this.key,
      this.translatedNamespace,
      this.tagName,
      this.fullTagName,
      this.intro,
      this.links});
  factory TagData.fromData(Map<String, dynamic> data, {String? prefix}) {
    final effectivePrefix = prefix ?? '';
    return TagData(
      namespace: const StringType()
          .mapFromDatabaseResponse(data['${effectivePrefix}namespace'])!,
      key: const StringType()
          .mapFromDatabaseResponse(data['${effectivePrefix}_key'])!,
      translatedNamespace: const StringType().mapFromDatabaseResponse(
          data['${effectivePrefix}translatedNamespace']),
      tagName: const StringType()
          .mapFromDatabaseResponse(data['${effectivePrefix}tagName']),
      fullTagName: const StringType()
          .mapFromDatabaseResponse(data['${effectivePrefix}fullTagName']),
      intro: const StringType()
          .mapFromDatabaseResponse(data['${effectivePrefix}intro']),
      links: const StringType()
          .mapFromDatabaseResponse(data['${effectivePrefix}links']),
    );
  }
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['namespace'] = Variable<String>(namespace);
    map['_key'] = Variable<String>(key);
    if (!nullToAbsent || translatedNamespace != null) {
      map['translatedNamespace'] = Variable<String?>(translatedNamespace);
    }
    if (!nullToAbsent || tagName != null) {
      map['tagName'] = Variable<String?>(tagName);
    }
    if (!nullToAbsent || fullTagName != null) {
      map['fullTagName'] = Variable<String?>(fullTagName);
    }
    if (!nullToAbsent || intro != null) {
      map['intro'] = Variable<String?>(intro);
    }
    if (!nullToAbsent || links != null) {
      map['links'] = Variable<String?>(links);
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
          String? translatedNamespace,
          String? tagName,
          String? fullTagName,
          String? intro,
          String? links}) =>
      TagData(
        namespace: namespace ?? this.namespace,
        key: key ?? this.key,
        translatedNamespace: translatedNamespace ?? this.translatedNamespace,
        tagName: tagName ?? this.tagName,
        fullTagName: fullTagName ?? this.fullTagName,
        intro: intro ?? this.intro,
        links: links ?? this.links,
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
  const TagCompanion({
    this.namespace = const Value.absent(),
    this.key = const Value.absent(),
    this.translatedNamespace = const Value.absent(),
    this.tagName = const Value.absent(),
    this.fullTagName = const Value.absent(),
    this.intro = const Value.absent(),
    this.links = const Value.absent(),
  });
  TagCompanion.insert({
    required String namespace,
    required String key,
    this.translatedNamespace = const Value.absent(),
    this.tagName = const Value.absent(),
    this.fullTagName = const Value.absent(),
    this.intro = const Value.absent(),
    this.links = const Value.absent(),
  })  : namespace = Value(namespace),
        key = Value(key);
  static Insertable<TagData> custom({
    Expression<String>? namespace,
    Expression<String>? key,
    Expression<String?>? translatedNamespace,
    Expression<String?>? tagName,
    Expression<String?>? fullTagName,
    Expression<String?>? intro,
    Expression<String?>? links,
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
    });
  }

  TagCompanion copyWith(
      {Value<String>? namespace,
      Value<String>? key,
      Value<String?>? translatedNamespace,
      Value<String?>? tagName,
      Value<String?>? fullTagName,
      Value<String?>? intro,
      Value<String?>? links}) {
    return TagCompanion(
      namespace: namespace ?? this.namespace,
      key: key ?? this.key,
      translatedNamespace: translatedNamespace ?? this.translatedNamespace,
      tagName: tagName ?? this.tagName,
      fullTagName: fullTagName ?? this.fullTagName,
      intro: intro ?? this.intro,
      links: links ?? this.links,
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
      map['translatedNamespace'] = Variable<String?>(translatedNamespace.value);
    }
    if (tagName.present) {
      map['tagName'] = Variable<String?>(tagName.value);
    }
    if (fullTagName.present) {
      map['fullTagName'] = Variable<String?>(fullTagName.value);
    }
    if (intro.present) {
      map['intro'] = Variable<String?>(intro.value);
    }
    if (links.present) {
      map['links'] = Variable<String?>(links.value);
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
          ..write('links: $links')
          ..write(')'))
        .toString();
  }
}

class Tag extends Table with TableInfo<Tag, TagData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Tag(this.attachedDatabase, [this._alias]);
  final VerificationMeta _namespaceMeta = const VerificationMeta('namespace');
  late final GeneratedColumn<String?> namespace = GeneratedColumn<String?>(
      'namespace', aliasedName, false,
      type: const StringType(),
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL');
  final VerificationMeta _keyMeta = const VerificationMeta('key');
  late final GeneratedColumn<String?> key = GeneratedColumn<String?>(
      '_key', aliasedName, false,
      type: const StringType(),
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL');
  final VerificationMeta _translatedNamespaceMeta =
      const VerificationMeta('translatedNamespace');
  late final GeneratedColumn<String?> translatedNamespace =
      GeneratedColumn<String?>('translatedNamespace', aliasedName, true,
          type: const StringType(),
          requiredDuringInsert: false,
          $customConstraints: '');
  final VerificationMeta _tagNameMeta = const VerificationMeta('tagName');
  late final GeneratedColumn<String?> tagName = GeneratedColumn<String?>(
      'tagName', aliasedName, true,
      type: const StringType(),
      requiredDuringInsert: false,
      $customConstraints: '');
  final VerificationMeta _fullTagNameMeta =
      const VerificationMeta('fullTagName');
  late final GeneratedColumn<String?> fullTagName = GeneratedColumn<String?>(
      'fullTagName', aliasedName, true,
      type: const StringType(),
      requiredDuringInsert: false,
      $customConstraints: '');
  final VerificationMeta _introMeta = const VerificationMeta('intro');
  late final GeneratedColumn<String?> intro = GeneratedColumn<String?>(
      'intro', aliasedName, true,
      type: const StringType(),
      requiredDuringInsert: false,
      $customConstraints: '');
  final VerificationMeta _linksMeta = const VerificationMeta('links');
  late final GeneratedColumn<String?> links = GeneratedColumn<String?>(
      'links', aliasedName, true,
      type: const StringType(),
      requiredDuringInsert: false,
      $customConstraints: '');
  @override
  List<GeneratedColumn> get $columns =>
      [namespace, key, translatedNamespace, tagName, fullTagName, intro, links];
  @override
  String get aliasedName => _alias ?? 'tag';
  @override
  String get actualTableName => 'tag';
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
    return TagData.fromData(data,
        prefix: tablePrefix != null ? '$tablePrefix.' : null);
  }

  @override
  Tag createAlias(String alias) {
    return Tag(attachedDatabase, alias);
  }

  @override
  List<String> get customConstraints => const ['primary key (namespace, _key)'];
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
  final double coverHeight;
  final double coverWidth;
  final String? uploader;
  final int size;
  final String publishTime;
  final int archiveStatusIndex;
  final String archivePageUrl;
  final String? downloadPageUrl;
  final String? downloadUrl;
  final bool isOriginal;
  final String? insertTime;
  ArchiveDownloadedData(
      {required this.gid,
      required this.token,
      required this.title,
      required this.category,
      required this.pageCount,
      required this.galleryUrl,
      required this.coverUrl,
      required this.coverHeight,
      required this.coverWidth,
      this.uploader,
      required this.size,
      required this.publishTime,
      required this.archiveStatusIndex,
      required this.archivePageUrl,
      this.downloadPageUrl,
      this.downloadUrl,
      required this.isOriginal,
      this.insertTime});
  factory ArchiveDownloadedData.fromData(Map<String, dynamic> data,
      {String? prefix}) {
    final effectivePrefix = prefix ?? '';
    return ArchiveDownloadedData(
      gid: const IntType()
          .mapFromDatabaseResponse(data['${effectivePrefix}gid'])!,
      token: const StringType()
          .mapFromDatabaseResponse(data['${effectivePrefix}token'])!,
      title: const StringType()
          .mapFromDatabaseResponse(data['${effectivePrefix}title'])!,
      category: const StringType()
          .mapFromDatabaseResponse(data['${effectivePrefix}category'])!,
      pageCount: const IntType()
          .mapFromDatabaseResponse(data['${effectivePrefix}pageCount'])!,
      galleryUrl: const StringType()
          .mapFromDatabaseResponse(data['${effectivePrefix}galleryUrl'])!,
      coverUrl: const StringType()
          .mapFromDatabaseResponse(data['${effectivePrefix}coverUrl'])!,
      coverHeight: const RealType()
          .mapFromDatabaseResponse(data['${effectivePrefix}coverHeight'])!,
      coverWidth: const RealType()
          .mapFromDatabaseResponse(data['${effectivePrefix}coverWidth'])!,
      uploader: const StringType()
          .mapFromDatabaseResponse(data['${effectivePrefix}uploader']),
      size: const IntType()
          .mapFromDatabaseResponse(data['${effectivePrefix}size'])!,
      publishTime: const StringType()
          .mapFromDatabaseResponse(data['${effectivePrefix}publishTime'])!,
      archiveStatusIndex: const IntType().mapFromDatabaseResponse(
          data['${effectivePrefix}archiveStatusIndex'])!,
      archivePageUrl: const StringType()
          .mapFromDatabaseResponse(data['${effectivePrefix}archivePageUrl'])!,
      downloadPageUrl: const StringType()
          .mapFromDatabaseResponse(data['${effectivePrefix}downloadPageUrl']),
      downloadUrl: const StringType()
          .mapFromDatabaseResponse(data['${effectivePrefix}downloadUrl']),
      isOriginal: const BoolType()
          .mapFromDatabaseResponse(data['${effectivePrefix}isOriginal'])!,
      insertTime: const StringType()
          .mapFromDatabaseResponse(data['${effectivePrefix}insertTime']),
    );
  }
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
    map['coverHeight'] = Variable<double>(coverHeight);
    map['coverWidth'] = Variable<double>(coverWidth);
    if (!nullToAbsent || uploader != null) {
      map['uploader'] = Variable<String?>(uploader);
    }
    map['size'] = Variable<int>(size);
    map['publishTime'] = Variable<String>(publishTime);
    map['archiveStatusIndex'] = Variable<int>(archiveStatusIndex);
    map['archivePageUrl'] = Variable<String>(archivePageUrl);
    if (!nullToAbsent || downloadPageUrl != null) {
      map['downloadPageUrl'] = Variable<String?>(downloadPageUrl);
    }
    if (!nullToAbsent || downloadUrl != null) {
      map['downloadUrl'] = Variable<String?>(downloadUrl);
    }
    map['isOriginal'] = Variable<bool>(isOriginal);
    if (!nullToAbsent || insertTime != null) {
      map['insertTime'] = Variable<String?>(insertTime);
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
      coverHeight: Value(coverHeight),
      coverWidth: Value(coverWidth),
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
      coverHeight: serializer.fromJson<double>(json['coverHeight']),
      coverWidth: serializer.fromJson<double>(json['coverWidth']),
      uploader: serializer.fromJson<String?>(json['uploader']),
      size: serializer.fromJson<int>(json['size']),
      publishTime: serializer.fromJson<String>(json['publishTime']),
      archiveStatusIndex: serializer.fromJson<int>(json['archiveStatusIndex']),
      archivePageUrl: serializer.fromJson<String>(json['archivePageUrl']),
      downloadPageUrl: serializer.fromJson<String?>(json['downloadPageUrl']),
      downloadUrl: serializer.fromJson<String?>(json['downloadUrl']),
      isOriginal: serializer.fromJson<bool>(json['isOriginal']),
      insertTime: serializer.fromJson<String?>(json['insertTime']),
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
      'coverHeight': serializer.toJson<double>(coverHeight),
      'coverWidth': serializer.toJson<double>(coverWidth),
      'uploader': serializer.toJson<String?>(uploader),
      'size': serializer.toJson<int>(size),
      'publishTime': serializer.toJson<String>(publishTime),
      'archiveStatusIndex': serializer.toJson<int>(archiveStatusIndex),
      'archivePageUrl': serializer.toJson<String>(archivePageUrl),
      'downloadPageUrl': serializer.toJson<String?>(downloadPageUrl),
      'downloadUrl': serializer.toJson<String?>(downloadUrl),
      'isOriginal': serializer.toJson<bool>(isOriginal),
      'insertTime': serializer.toJson<String?>(insertTime),
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
          double? coverHeight,
          double? coverWidth,
          String? uploader,
          int? size,
          String? publishTime,
          int? archiveStatusIndex,
          String? archivePageUrl,
          String? downloadPageUrl,
          String? downloadUrl,
          bool? isOriginal,
          String? insertTime}) =>
      ArchiveDownloadedData(
        gid: gid ?? this.gid,
        token: token ?? this.token,
        title: title ?? this.title,
        category: category ?? this.category,
        pageCount: pageCount ?? this.pageCount,
        galleryUrl: galleryUrl ?? this.galleryUrl,
        coverUrl: coverUrl ?? this.coverUrl,
        coverHeight: coverHeight ?? this.coverHeight,
        coverWidth: coverWidth ?? this.coverWidth,
        uploader: uploader ?? this.uploader,
        size: size ?? this.size,
        publishTime: publishTime ?? this.publishTime,
        archiveStatusIndex: archiveStatusIndex ?? this.archiveStatusIndex,
        archivePageUrl: archivePageUrl ?? this.archivePageUrl,
        downloadPageUrl: downloadPageUrl ?? this.downloadPageUrl,
        downloadUrl: downloadUrl ?? this.downloadUrl,
        isOriginal: isOriginal ?? this.isOriginal,
        insertTime: insertTime ?? this.insertTime,
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
          ..write('coverHeight: $coverHeight, ')
          ..write('coverWidth: $coverWidth, ')
          ..write('uploader: $uploader, ')
          ..write('size: $size, ')
          ..write('publishTime: $publishTime, ')
          ..write('archiveStatusIndex: $archiveStatusIndex, ')
          ..write('archivePageUrl: $archivePageUrl, ')
          ..write('downloadPageUrl: $downloadPageUrl, ')
          ..write('downloadUrl: $downloadUrl, ')
          ..write('isOriginal: $isOriginal, ')
          ..write('insertTime: $insertTime')
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
      coverHeight,
      coverWidth,
      uploader,
      size,
      publishTime,
      archiveStatusIndex,
      archivePageUrl,
      downloadPageUrl,
      downloadUrl,
      isOriginal,
      insertTime);
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
          other.coverHeight == this.coverHeight &&
          other.coverWidth == this.coverWidth &&
          other.uploader == this.uploader &&
          other.size == this.size &&
          other.publishTime == this.publishTime &&
          other.archiveStatusIndex == this.archiveStatusIndex &&
          other.archivePageUrl == this.archivePageUrl &&
          other.downloadPageUrl == this.downloadPageUrl &&
          other.downloadUrl == this.downloadUrl &&
          other.isOriginal == this.isOriginal &&
          other.insertTime == this.insertTime);
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
  final Value<double> coverHeight;
  final Value<double> coverWidth;
  final Value<String?> uploader;
  final Value<int> size;
  final Value<String> publishTime;
  final Value<int> archiveStatusIndex;
  final Value<String> archivePageUrl;
  final Value<String?> downloadPageUrl;
  final Value<String?> downloadUrl;
  final Value<bool> isOriginal;
  final Value<String?> insertTime;
  const ArchiveDownloadedCompanion({
    this.gid = const Value.absent(),
    this.token = const Value.absent(),
    this.title = const Value.absent(),
    this.category = const Value.absent(),
    this.pageCount = const Value.absent(),
    this.galleryUrl = const Value.absent(),
    this.coverUrl = const Value.absent(),
    this.coverHeight = const Value.absent(),
    this.coverWidth = const Value.absent(),
    this.uploader = const Value.absent(),
    this.size = const Value.absent(),
    this.publishTime = const Value.absent(),
    this.archiveStatusIndex = const Value.absent(),
    this.archivePageUrl = const Value.absent(),
    this.downloadPageUrl = const Value.absent(),
    this.downloadUrl = const Value.absent(),
    this.isOriginal = const Value.absent(),
    this.insertTime = const Value.absent(),
  });
  ArchiveDownloadedCompanion.insert({
    required int gid,
    required String token,
    required String title,
    required String category,
    required int pageCount,
    required String galleryUrl,
    required String coverUrl,
    required double coverHeight,
    required double coverWidth,
    this.uploader = const Value.absent(),
    required int size,
    required String publishTime,
    required int archiveStatusIndex,
    required String archivePageUrl,
    this.downloadPageUrl = const Value.absent(),
    this.downloadUrl = const Value.absent(),
    required bool isOriginal,
    this.insertTime = const Value.absent(),
  })  : gid = Value(gid),
        token = Value(token),
        title = Value(title),
        category = Value(category),
        pageCount = Value(pageCount),
        galleryUrl = Value(galleryUrl),
        coverUrl = Value(coverUrl),
        coverHeight = Value(coverHeight),
        coverWidth = Value(coverWidth),
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
    Expression<double>? coverHeight,
    Expression<double>? coverWidth,
    Expression<String?>? uploader,
    Expression<int>? size,
    Expression<String>? publishTime,
    Expression<int>? archiveStatusIndex,
    Expression<String>? archivePageUrl,
    Expression<String?>? downloadPageUrl,
    Expression<String?>? downloadUrl,
    Expression<bool>? isOriginal,
    Expression<String?>? insertTime,
  }) {
    return RawValuesInsertable({
      if (gid != null) 'gid': gid,
      if (token != null) 'token': token,
      if (title != null) 'title': title,
      if (category != null) 'category': category,
      if (pageCount != null) 'pageCount': pageCount,
      if (galleryUrl != null) 'galleryUrl': galleryUrl,
      if (coverUrl != null) 'coverUrl': coverUrl,
      if (coverHeight != null) 'coverHeight': coverHeight,
      if (coverWidth != null) 'coverWidth': coverWidth,
      if (uploader != null) 'uploader': uploader,
      if (size != null) 'size': size,
      if (publishTime != null) 'publishTime': publishTime,
      if (archiveStatusIndex != null) 'archiveStatusIndex': archiveStatusIndex,
      if (archivePageUrl != null) 'archivePageUrl': archivePageUrl,
      if (downloadPageUrl != null) 'downloadPageUrl': downloadPageUrl,
      if (downloadUrl != null) 'downloadUrl': downloadUrl,
      if (isOriginal != null) 'isOriginal': isOriginal,
      if (insertTime != null) 'insertTime': insertTime,
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
      Value<double>? coverHeight,
      Value<double>? coverWidth,
      Value<String?>? uploader,
      Value<int>? size,
      Value<String>? publishTime,
      Value<int>? archiveStatusIndex,
      Value<String>? archivePageUrl,
      Value<String?>? downloadPageUrl,
      Value<String?>? downloadUrl,
      Value<bool>? isOriginal,
      Value<String?>? insertTime}) {
    return ArchiveDownloadedCompanion(
      gid: gid ?? this.gid,
      token: token ?? this.token,
      title: title ?? this.title,
      category: category ?? this.category,
      pageCount: pageCount ?? this.pageCount,
      galleryUrl: galleryUrl ?? this.galleryUrl,
      coverUrl: coverUrl ?? this.coverUrl,
      coverHeight: coverHeight ?? this.coverHeight,
      coverWidth: coverWidth ?? this.coverWidth,
      uploader: uploader ?? this.uploader,
      size: size ?? this.size,
      publishTime: publishTime ?? this.publishTime,
      archiveStatusIndex: archiveStatusIndex ?? this.archiveStatusIndex,
      archivePageUrl: archivePageUrl ?? this.archivePageUrl,
      downloadPageUrl: downloadPageUrl ?? this.downloadPageUrl,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      isOriginal: isOriginal ?? this.isOriginal,
      insertTime: insertTime ?? this.insertTime,
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
    if (coverHeight.present) {
      map['coverHeight'] = Variable<double>(coverHeight.value);
    }
    if (coverWidth.present) {
      map['coverWidth'] = Variable<double>(coverWidth.value);
    }
    if (uploader.present) {
      map['uploader'] = Variable<String?>(uploader.value);
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
      map['downloadPageUrl'] = Variable<String?>(downloadPageUrl.value);
    }
    if (downloadUrl.present) {
      map['downloadUrl'] = Variable<String?>(downloadUrl.value);
    }
    if (isOriginal.present) {
      map['isOriginal'] = Variable<bool>(isOriginal.value);
    }
    if (insertTime.present) {
      map['insertTime'] = Variable<String?>(insertTime.value);
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
          ..write('coverHeight: $coverHeight, ')
          ..write('coverWidth: $coverWidth, ')
          ..write('uploader: $uploader, ')
          ..write('size: $size, ')
          ..write('publishTime: $publishTime, ')
          ..write('archiveStatusIndex: $archiveStatusIndex, ')
          ..write('archivePageUrl: $archivePageUrl, ')
          ..write('downloadPageUrl: $downloadPageUrl, ')
          ..write('downloadUrl: $downloadUrl, ')
          ..write('isOriginal: $isOriginal, ')
          ..write('insertTime: $insertTime')
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
  final VerificationMeta _gidMeta = const VerificationMeta('gid');
  late final GeneratedColumn<int?> gid = GeneratedColumn<int?>(
      'gid', aliasedName, false,
      type: const IntType(),
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL');
  final VerificationMeta _tokenMeta = const VerificationMeta('token');
  late final GeneratedColumn<String?> token = GeneratedColumn<String?>(
      'token', aliasedName, false,
      type: const StringType(),
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL');
  final VerificationMeta _titleMeta = const VerificationMeta('title');
  late final GeneratedColumn<String?> title = GeneratedColumn<String?>(
      'title', aliasedName, false,
      type: const StringType(),
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL');
  final VerificationMeta _categoryMeta = const VerificationMeta('category');
  late final GeneratedColumn<String?> category = GeneratedColumn<String?>(
      'category', aliasedName, false,
      type: const StringType(),
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL');
  final VerificationMeta _pageCountMeta = const VerificationMeta('pageCount');
  late final GeneratedColumn<int?> pageCount = GeneratedColumn<int?>(
      'pageCount', aliasedName, false,
      type: const IntType(),
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL');
  final VerificationMeta _galleryUrlMeta = const VerificationMeta('galleryUrl');
  late final GeneratedColumn<String?> galleryUrl = GeneratedColumn<String?>(
      'galleryUrl', aliasedName, false,
      type: const StringType(),
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL');
  final VerificationMeta _coverUrlMeta = const VerificationMeta('coverUrl');
  late final GeneratedColumn<String?> coverUrl = GeneratedColumn<String?>(
      'coverUrl', aliasedName, false,
      type: const StringType(),
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL');
  final VerificationMeta _coverHeightMeta =
      const VerificationMeta('coverHeight');
  late final GeneratedColumn<double?> coverHeight = GeneratedColumn<double?>(
      'coverHeight', aliasedName, false,
      type: const RealType(),
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL');
  final VerificationMeta _coverWidthMeta = const VerificationMeta('coverWidth');
  late final GeneratedColumn<double?> coverWidth = GeneratedColumn<double?>(
      'coverWidth', aliasedName, false,
      type: const RealType(),
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL');
  final VerificationMeta _uploaderMeta = const VerificationMeta('uploader');
  late final GeneratedColumn<String?> uploader = GeneratedColumn<String?>(
      'uploader', aliasedName, true,
      type: const StringType(),
      requiredDuringInsert: false,
      $customConstraints: '');
  final VerificationMeta _sizeMeta = const VerificationMeta('size');
  late final GeneratedColumn<int?> size = GeneratedColumn<int?>(
      'size', aliasedName, false,
      type: const IntType(),
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL');
  final VerificationMeta _publishTimeMeta =
      const VerificationMeta('publishTime');
  late final GeneratedColumn<String?> publishTime = GeneratedColumn<String?>(
      'publishTime', aliasedName, false,
      type: const StringType(),
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL');
  final VerificationMeta _archiveStatusIndexMeta =
      const VerificationMeta('archiveStatusIndex');
  late final GeneratedColumn<int?> archiveStatusIndex = GeneratedColumn<int?>(
      'archiveStatusIndex', aliasedName, false,
      type: const IntType(),
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL');
  final VerificationMeta _archivePageUrlMeta =
      const VerificationMeta('archivePageUrl');
  late final GeneratedColumn<String?> archivePageUrl = GeneratedColumn<String?>(
      'archivePageUrl', aliasedName, false,
      type: const StringType(),
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL');
  final VerificationMeta _downloadPageUrlMeta =
      const VerificationMeta('downloadPageUrl');
  late final GeneratedColumn<String?> downloadPageUrl =
      GeneratedColumn<String?>('downloadPageUrl', aliasedName, true,
          type: const StringType(),
          requiredDuringInsert: false,
          $customConstraints: 'NULL');
  final VerificationMeta _downloadUrlMeta =
      const VerificationMeta('downloadUrl');
  late final GeneratedColumn<String?> downloadUrl = GeneratedColumn<String?>(
      'downloadUrl', aliasedName, true,
      type: const StringType(),
      requiredDuringInsert: false,
      $customConstraints: 'NULL');
  final VerificationMeta _isOriginalMeta = const VerificationMeta('isOriginal');
  late final GeneratedColumn<bool?> isOriginal = GeneratedColumn<bool?>(
      'isOriginal', aliasedName, false,
      type: const BoolType(),
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL');
  final VerificationMeta _insertTimeMeta = const VerificationMeta('insertTime');
  late final GeneratedColumn<String?> insertTime = GeneratedColumn<String?>(
      'insertTime', aliasedName, true,
      type: const StringType(),
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
        coverHeight,
        coverWidth,
        uploader,
        size,
        publishTime,
        archiveStatusIndex,
        archivePageUrl,
        downloadPageUrl,
        downloadUrl,
        isOriginal,
        insertTime
      ];
  @override
  String get aliasedName => _alias ?? 'archive_downloaded';
  @override
  String get actualTableName => 'archive_downloaded';
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
    if (data.containsKey('coverHeight')) {
      context.handle(
          _coverHeightMeta,
          coverHeight.isAcceptableOrUnknown(
              data['coverHeight']!, _coverHeightMeta));
    } else if (isInserting) {
      context.missing(_coverHeightMeta);
    }
    if (data.containsKey('coverWidth')) {
      context.handle(
          _coverWidthMeta,
          coverWidth.isAcceptableOrUnknown(
              data['coverWidth']!, _coverWidthMeta));
    } else if (isInserting) {
      context.missing(_coverWidthMeta);
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {gid, isOriginal};
  @override
  ArchiveDownloadedData map(Map<String, dynamic> data, {String? tablePrefix}) {
    return ArchiveDownloadedData.fromData(data,
        prefix: tablePrefix != null ? '$tablePrefix.' : null);
  }

  @override
  ArchiveDownloaded createAlias(String alias) {
    return ArchiveDownloaded(attachedDatabase, alias);
  }

  @override
  List<String> get customConstraints => const ['PRIMARY KEY (gid, isOriginal)'];
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
  GalleryDownloadedData(
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
      required this.downloadOriginalImage});
  factory GalleryDownloadedData.fromData(Map<String, dynamic> data,
      {String? prefix}) {
    final effectivePrefix = prefix ?? '';
    return GalleryDownloadedData(
      gid: const IntType()
          .mapFromDatabaseResponse(data['${effectivePrefix}gid'])!,
      token: const StringType()
          .mapFromDatabaseResponse(data['${effectivePrefix}token'])!,
      title: const StringType()
          .mapFromDatabaseResponse(data['${effectivePrefix}title'])!,
      category: const StringType()
          .mapFromDatabaseResponse(data['${effectivePrefix}category'])!,
      pageCount: const IntType()
          .mapFromDatabaseResponse(data['${effectivePrefix}pageCount'])!,
      galleryUrl: const StringType()
          .mapFromDatabaseResponse(data['${effectivePrefix}galleryUrl'])!,
      oldVersionGalleryUrl: const StringType().mapFromDatabaseResponse(
          data['${effectivePrefix}oldVersionGalleryUrl']),
      uploader: const StringType()
          .mapFromDatabaseResponse(data['${effectivePrefix}uploader']),
      publishTime: const StringType()
          .mapFromDatabaseResponse(data['${effectivePrefix}publishTime'])!,
      downloadStatusIndex: const IntType().mapFromDatabaseResponse(
          data['${effectivePrefix}downloadStatusIndex'])!,
      insertTime: const StringType()
          .mapFromDatabaseResponse(data['${effectivePrefix}insertTime']),
      downloadOriginalImage: const BoolType().mapFromDatabaseResponse(
          data['${effectivePrefix}downloadOriginalImage'])!,
    );
  }
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
      map['oldVersionGalleryUrl'] = Variable<String?>(oldVersionGalleryUrl);
    }
    if (!nullToAbsent || uploader != null) {
      map['uploader'] = Variable<String?>(uploader);
    }
    map['publishTime'] = Variable<String>(publishTime);
    map['downloadStatusIndex'] = Variable<int>(downloadStatusIndex);
    if (!nullToAbsent || insertTime != null) {
      map['insertTime'] = Variable<String?>(insertTime);
    }
    map['downloadOriginalImage'] = Variable<bool>(downloadOriginalImage);
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
    };
  }

  GalleryDownloadedData copyWith(
          {int? gid,
          String? token,
          String? title,
          String? category,
          int? pageCount,
          String? galleryUrl,
          String? oldVersionGalleryUrl,
          String? uploader,
          String? publishTime,
          int? downloadStatusIndex,
          String? insertTime,
          bool? downloadOriginalImage}) =>
      GalleryDownloadedData(
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
          ..write('downloadOriginalImage: $downloadOriginalImage')
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
      downloadOriginalImage);
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
          other.downloadOriginalImage == this.downloadOriginalImage);
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
    Expression<String?>? oldVersionGalleryUrl,
    Expression<String?>? uploader,
    Expression<String>? publishTime,
    Expression<int>? downloadStatusIndex,
    Expression<String?>? insertTime,
    Expression<bool>? downloadOriginalImage,
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
      Value<bool>? downloadOriginalImage}) {
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
          Variable<String?>(oldVersionGalleryUrl.value);
    }
    if (uploader.present) {
      map['uploader'] = Variable<String?>(uploader.value);
    }
    if (publishTime.present) {
      map['publishTime'] = Variable<String>(publishTime.value);
    }
    if (downloadStatusIndex.present) {
      map['downloadStatusIndex'] = Variable<int>(downloadStatusIndex.value);
    }
    if (insertTime.present) {
      map['insertTime'] = Variable<String?>(insertTime.value);
    }
    if (downloadOriginalImage.present) {
      map['downloadOriginalImage'] =
          Variable<bool>(downloadOriginalImage.value);
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
          ..write('downloadOriginalImage: $downloadOriginalImage')
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
  final VerificationMeta _gidMeta = const VerificationMeta('gid');
  late final GeneratedColumn<int?> gid = GeneratedColumn<int?>(
      'gid', aliasedName, false,
      type: const IntType(),
      requiredDuringInsert: false,
      $customConstraints: 'NOT NULL PRIMARY KEY');
  final VerificationMeta _tokenMeta = const VerificationMeta('token');
  late final GeneratedColumn<String?> token = GeneratedColumn<String?>(
      'token', aliasedName, false,
      type: const StringType(),
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL');
  final VerificationMeta _titleMeta = const VerificationMeta('title');
  late final GeneratedColumn<String?> title = GeneratedColumn<String?>(
      'title', aliasedName, false,
      type: const StringType(),
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL');
  final VerificationMeta _categoryMeta = const VerificationMeta('category');
  late final GeneratedColumn<String?> category = GeneratedColumn<String?>(
      'category', aliasedName, false,
      type: const StringType(),
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL');
  final VerificationMeta _pageCountMeta = const VerificationMeta('pageCount');
  late final GeneratedColumn<int?> pageCount = GeneratedColumn<int?>(
      'pageCount', aliasedName, false,
      type: const IntType(),
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL');
  final VerificationMeta _galleryUrlMeta = const VerificationMeta('galleryUrl');
  late final GeneratedColumn<String?> galleryUrl = GeneratedColumn<String?>(
      'galleryUrl', aliasedName, false,
      type: const StringType(),
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL');
  final VerificationMeta _oldVersionGalleryUrlMeta =
      const VerificationMeta('oldVersionGalleryUrl');
  late final GeneratedColumn<String?> oldVersionGalleryUrl =
      GeneratedColumn<String?>('oldVersionGalleryUrl', aliasedName, true,
          type: const StringType(),
          requiredDuringInsert: false,
          $customConstraints: '');
  final VerificationMeta _uploaderMeta = const VerificationMeta('uploader');
  late final GeneratedColumn<String?> uploader = GeneratedColumn<String?>(
      'uploader', aliasedName, true,
      type: const StringType(),
      requiredDuringInsert: false,
      $customConstraints: '');
  final VerificationMeta _publishTimeMeta =
      const VerificationMeta('publishTime');
  late final GeneratedColumn<String?> publishTime = GeneratedColumn<String?>(
      'publishTime', aliasedName, false,
      type: const StringType(),
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL');
  final VerificationMeta _downloadStatusIndexMeta =
      const VerificationMeta('downloadStatusIndex');
  late final GeneratedColumn<int?> downloadStatusIndex = GeneratedColumn<int?>(
      'downloadStatusIndex', aliasedName, false,
      type: const IntType(),
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL');
  final VerificationMeta _insertTimeMeta = const VerificationMeta('insertTime');
  late final GeneratedColumn<String?> insertTime = GeneratedColumn<String?>(
      'insertTime', aliasedName, true,
      type: const StringType(),
      requiredDuringInsert: false,
      $customConstraints: '');
  final VerificationMeta _downloadOriginalImageMeta =
      const VerificationMeta('downloadOriginalImage');
  late final GeneratedColumn<bool?> downloadOriginalImage =
      GeneratedColumn<bool?>('downloadOriginalImage', aliasedName, false,
          type: const BoolType(),
          requiredDuringInsert: false,
          $customConstraints: 'NOT NULL DEFAULT FALSE',
          defaultValue: const CustomExpression<bool>('FALSE'));
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
        downloadOriginalImage
      ];
  @override
  String get aliasedName => _alias ?? 'gallery_downloaded';
  @override
  String get actualTableName => 'gallery_downloaded';
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {gid};
  @override
  GalleryDownloadedData map(Map<String, dynamic> data, {String? tablePrefix}) {
    return GalleryDownloadedData.fromData(data,
        prefix: tablePrefix != null ? '$tablePrefix.' : null);
  }

  @override
  GalleryDownloaded createAlias(String alias) {
    return GalleryDownloaded(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class ImageData extends DataClass implements Insertable<ImageData> {
  final String url;
  final int serialNo;
  final int gid;
  final double height;
  final double width;
  final String path;
  final String imageHash;
  final int downloadStatusIndex;
  ImageData(
      {required this.url,
      required this.serialNo,
      required this.gid,
      required this.height,
      required this.width,
      required this.path,
      required this.imageHash,
      required this.downloadStatusIndex});
  factory ImageData.fromData(Map<String, dynamic> data, {String? prefix}) {
    final effectivePrefix = prefix ?? '';
    return ImageData(
      url: const StringType()
          .mapFromDatabaseResponse(data['${effectivePrefix}url'])!,
      serialNo: const IntType()
          .mapFromDatabaseResponse(data['${effectivePrefix}serialNo'])!,
      gid: const IntType()
          .mapFromDatabaseResponse(data['${effectivePrefix}gid'])!,
      height: const RealType()
          .mapFromDatabaseResponse(data['${effectivePrefix}height'])!,
      width: const RealType()
          .mapFromDatabaseResponse(data['${effectivePrefix}width'])!,
      path: const StringType()
          .mapFromDatabaseResponse(data['${effectivePrefix}path'])!,
      imageHash: const StringType()
          .mapFromDatabaseResponse(data['${effectivePrefix}imageHash'])!,
      downloadStatusIndex: const IntType().mapFromDatabaseResponse(
          data['${effectivePrefix}downloadStatusIndex'])!,
    );
  }
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['url'] = Variable<String>(url);
    map['serialNo'] = Variable<int>(serialNo);
    map['gid'] = Variable<int>(gid);
    map['height'] = Variable<double>(height);
    map['width'] = Variable<double>(width);
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
      height: Value(height),
      width: Value(width),
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
      height: serializer.fromJson<double>(json['height']),
      width: serializer.fromJson<double>(json['width']),
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
      'height': serializer.toJson<double>(height),
      'width': serializer.toJson<double>(width),
      'path': serializer.toJson<String>(path),
      'imageHash': serializer.toJson<String>(imageHash),
      'downloadStatusIndex': serializer.toJson<int>(downloadStatusIndex),
    };
  }

  ImageData copyWith(
          {String? url,
          int? serialNo,
          int? gid,
          double? height,
          double? width,
          String? path,
          String? imageHash,
          int? downloadStatusIndex}) =>
      ImageData(
        url: url ?? this.url,
        serialNo: serialNo ?? this.serialNo,
        gid: gid ?? this.gid,
        height: height ?? this.height,
        width: width ?? this.width,
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
          ..write('height: $height, ')
          ..write('width: $width, ')
          ..write('path: $path, ')
          ..write('imageHash: $imageHash, ')
          ..write('downloadStatusIndex: $downloadStatusIndex')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      url, serialNo, gid, height, width, path, imageHash, downloadStatusIndex);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ImageData &&
          other.url == this.url &&
          other.serialNo == this.serialNo &&
          other.gid == this.gid &&
          other.height == this.height &&
          other.width == this.width &&
          other.path == this.path &&
          other.imageHash == this.imageHash &&
          other.downloadStatusIndex == this.downloadStatusIndex);
}

class ImageCompanion extends UpdateCompanion<ImageData> {
  final Value<String> url;
  final Value<int> serialNo;
  final Value<int> gid;
  final Value<double> height;
  final Value<double> width;
  final Value<String> path;
  final Value<String> imageHash;
  final Value<int> downloadStatusIndex;
  const ImageCompanion({
    this.url = const Value.absent(),
    this.serialNo = const Value.absent(),
    this.gid = const Value.absent(),
    this.height = const Value.absent(),
    this.width = const Value.absent(),
    this.path = const Value.absent(),
    this.imageHash = const Value.absent(),
    this.downloadStatusIndex = const Value.absent(),
  });
  ImageCompanion.insert({
    required String url,
    required int serialNo,
    required int gid,
    required double height,
    required double width,
    required String path,
    required String imageHash,
    required int downloadStatusIndex,
  })  : url = Value(url),
        serialNo = Value(serialNo),
        gid = Value(gid),
        height = Value(height),
        width = Value(width),
        path = Value(path),
        imageHash = Value(imageHash),
        downloadStatusIndex = Value(downloadStatusIndex);
  static Insertable<ImageData> custom({
    Expression<String>? url,
    Expression<int>? serialNo,
    Expression<int>? gid,
    Expression<double>? height,
    Expression<double>? width,
    Expression<String>? path,
    Expression<String>? imageHash,
    Expression<int>? downloadStatusIndex,
  }) {
    return RawValuesInsertable({
      if (url != null) 'url': url,
      if (serialNo != null) 'serialNo': serialNo,
      if (gid != null) 'gid': gid,
      if (height != null) 'height': height,
      if (width != null) 'width': width,
      if (path != null) 'path': path,
      if (imageHash != null) 'imageHash': imageHash,
      if (downloadStatusIndex != null)
        'downloadStatusIndex': downloadStatusIndex,
    });
  }

  ImageCompanion copyWith(
      {Value<String>? url,
      Value<int>? serialNo,
      Value<int>? gid,
      Value<double>? height,
      Value<double>? width,
      Value<String>? path,
      Value<String>? imageHash,
      Value<int>? downloadStatusIndex}) {
    return ImageCompanion(
      url: url ?? this.url,
      serialNo: serialNo ?? this.serialNo,
      gid: gid ?? this.gid,
      height: height ?? this.height,
      width: width ?? this.width,
      path: path ?? this.path,
      imageHash: imageHash ?? this.imageHash,
      downloadStatusIndex: downloadStatusIndex ?? this.downloadStatusIndex,
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
    if (height.present) {
      map['height'] = Variable<double>(height.value);
    }
    if (width.present) {
      map['width'] = Variable<double>(width.value);
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
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ImageCompanion(')
          ..write('url: $url, ')
          ..write('serialNo: $serialNo, ')
          ..write('gid: $gid, ')
          ..write('height: $height, ')
          ..write('width: $width, ')
          ..write('path: $path, ')
          ..write('imageHash: $imageHash, ')
          ..write('downloadStatusIndex: $downloadStatusIndex')
          ..write(')'))
        .toString();
  }
}

class Image extends Table with TableInfo<Image, ImageData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Image(this.attachedDatabase, [this._alias]);
  final VerificationMeta _urlMeta = const VerificationMeta('url');
  late final GeneratedColumn<String?> url = GeneratedColumn<String?>(
      'url', aliasedName, false,
      type: const StringType(),
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL');
  final VerificationMeta _serialNoMeta = const VerificationMeta('serialNo');
  late final GeneratedColumn<int?> serialNo = GeneratedColumn<int?>(
      'serialNo', aliasedName, false,
      type: const IntType(),
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL');
  final VerificationMeta _gidMeta = const VerificationMeta('gid');
  late final GeneratedColumn<int?> gid = GeneratedColumn<int?>(
      'gid', aliasedName, false,
      type: const IntType(),
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL REFERENCES gallery_downloaded (gid)');
  final VerificationMeta _heightMeta = const VerificationMeta('height');
  late final GeneratedColumn<double?> height = GeneratedColumn<double?>(
      'height', aliasedName, false,
      type: const RealType(),
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL');
  final VerificationMeta _widthMeta = const VerificationMeta('width');
  late final GeneratedColumn<double?> width = GeneratedColumn<double?>(
      'width', aliasedName, false,
      type: const RealType(),
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL');
  final VerificationMeta _pathMeta = const VerificationMeta('path');
  late final GeneratedColumn<String?> path = GeneratedColumn<String?>(
      'path', aliasedName, false,
      type: const StringType(),
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL');
  final VerificationMeta _imageHashMeta = const VerificationMeta('imageHash');
  late final GeneratedColumn<String?> imageHash = GeneratedColumn<String?>(
      'imageHash', aliasedName, false,
      type: const StringType(),
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL');
  final VerificationMeta _downloadStatusIndexMeta =
      const VerificationMeta('downloadStatusIndex');
  late final GeneratedColumn<int?> downloadStatusIndex = GeneratedColumn<int?>(
      'downloadStatusIndex', aliasedName, false,
      type: const IntType(),
      requiredDuringInsert: true,
      $customConstraints: 'NOT NULL');
  @override
  List<GeneratedColumn> get $columns =>
      [url, serialNo, gid, height, width, path, imageHash, downloadStatusIndex];
  @override
  String get aliasedName => _alias ?? 'image';
  @override
  String get actualTableName => 'image';
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
    if (data.containsKey('height')) {
      context.handle(_heightMeta,
          height.isAcceptableOrUnknown(data['height']!, _heightMeta));
    } else if (isInserting) {
      context.missing(_heightMeta);
    }
    if (data.containsKey('width')) {
      context.handle(
          _widthMeta, width.isAcceptableOrUnknown(data['width']!, _widthMeta));
    } else if (isInserting) {
      context.missing(_widthMeta);
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
    return ImageData.fromData(data,
        prefix: tablePrefix != null ? '$tablePrefix.' : null);
  }

  @override
  Image createAlias(String alias) {
    return Image(attachedDatabase, alias);
  }

  @override
  List<String> get customConstraints => const ['PRIMARY KEY (gid, serialNo)'];
  @override
  bool get dontWriteConstraints => true;
}

abstract class _$AppDb extends GeneratedDatabase {
  _$AppDb(QueryExecutor e) : super(SqlTypeSystem.defaultInstance, e);
  late final Tag tag = Tag(this);
  late final ArchiveDownloaded archiveDownloaded = ArchiveDownloaded(this);
  late final GalleryDownloaded galleryDownloaded = GalleryDownloaded(this);
  late final Image image = Image(this);
  Selectable<TagData> selectTagByNamespaceAndKey(String namespace, String key) {
    return customSelect(
        'select *\r\nfrom tag\r\nwhere namespace = :namespace\r\n  and _key = :key',
        variables: [
          Variable<String>(namespace),
          Variable<String>(key)
        ],
        readsFrom: {
          tag,
        }).map(tag.mapFromRow);
  }

  Selectable<TagData> selectTagsByKey(String key) {
    return customSelect('select *\r\nfrom tag\r\nwhere _key = :key',
        variables: [
          Variable<String>(key)
        ],
        readsFrom: {
          tag,
        }).map(tag.mapFromRow);
  }

  Selectable<TagData> selectAllTags() {
    return customSelect('select *\r\nfrom tag', variables: [], readsFrom: {
      tag,
    }).map(tag.mapFromRow);
  }

  Selectable<TagData> searchTags(String pattern) {
    return customSelect(
        'select *\r\nfrom tag\r\nwhere _key LIKE :pattern\r\n   OR tagName LIKE :pattern\r\nLIMIT 35',
        variables: [
          Variable<String>(pattern)
        ],
        readsFrom: {
          tag,
        }).map(tag.mapFromRow);
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
      'insert into tag\r\nvalues (:namespace, :key, :translatedNamespace, :tagName, :fullTagName, :intro, :links)',
      variables: [
        Variable<String>(namespace),
        Variable<String>(key),
        Variable<String?>(translatedNamespace),
        Variable<String?>(tagName),
        Variable<String?>(fullTagName),
        Variable<String?>(intro),
        Variable<String?>(links)
      ],
      updates: {tag},
    );
  }

  Future<int> deleteAllTags() {
    return customUpdate(
      'delete\r\nfrom tag',
      variables: [],
      updates: {tag},
      updateKind: UpdateKind.delete,
    );
  }

  Selectable<ArchiveDownloadedData> selectArchives() {
    return customSelect(
        'SELECT *\r\nFROM archive_downloaded\r\nORDER BY insertTime DESC',
        variables: [],
        readsFrom: {
          archiveDownloaded,
        }).map(archiveDownloaded.mapFromRow);
  }

  Future<int> insertArchive(
      int gid,
      String token,
      String title,
      String category,
      int pageCount,
      String galleryUrl,
      String coverUrl,
      double coverHeight,
      double coverWidth,
      String? uploader,
      int size,
      String publishTime,
      int archiveStatusIndex,
      String archivePageUrl,
      String? downloadPageUrl,
      String? downloadUrl,
      bool isOriginal,
      String? insertTime) {
    return customInsert(
      'insert into archive_downloaded\r\nvalues (:gid, :token, :title, :category, :pageCount, :galleryUrl, :coverUrl, :coverHeight, :coverWidth, :uploader, :size,\r\n        :publishTime, :archiveStatusIndex, :archivePageUrl, :downloadPageUrl, :downloadUrl, :isOriginal, :insertTime)',
      variables: [
        Variable<int>(gid),
        Variable<String>(token),
        Variable<String>(title),
        Variable<String>(category),
        Variable<int>(pageCount),
        Variable<String>(galleryUrl),
        Variable<String>(coverUrl),
        Variable<double>(coverHeight),
        Variable<double>(coverWidth),
        Variable<String?>(uploader),
        Variable<int>(size),
        Variable<String>(publishTime),
        Variable<int>(archiveStatusIndex),
        Variable<String>(archivePageUrl),
        Variable<String?>(downloadPageUrl),
        Variable<String?>(downloadUrl),
        Variable<bool>(isOriginal),
        Variable<String?>(insertTime)
      ],
      updates: {archiveDownloaded},
    );
  }

  Future<int> deleteArchive(int gid, bool isOriginal) {
    return customUpdate(
      'delete\r\nfrom archive_downloaded\r\nwhere gid = :gid\r\n  AND isOriginal = :isOriginal',
      variables: [Variable<int>(gid), Variable<bool>(isOriginal)],
      updates: {archiveDownloaded},
      updateKind: UpdateKind.delete,
    );
  }

  Future<int> updateArchive(int archiveStatusIndex, String? downloadPageUrl,
      String? downloadUrl, int gid, bool isOriginal) {
    return customUpdate(
      'update archive_downloaded\r\nset archiveStatusIndex = :archiveStatusIndex,\r\n    downloadPageUrl    = :downloadPageUrl,\r\n    downloadUrl        = :downloadUrl\r\nwhere gid = :gid\r\n  AND isOriginal = :isOriginal',
      variables: [
        Variable<int>(archiveStatusIndex),
        Variable<String?>(downloadPageUrl),
        Variable<String?>(downloadUrl),
        Variable<int>(gid),
        Variable<bool>(isOriginal)
      ],
      updates: {archiveDownloaded},
      updateKind: UpdateKind.update,
    );
  }

  Selectable<SelectGallerysWithImagesResult> selectGallerysWithImages() {
    return customSelect(
        'SELECT g.gid,\r\n       g.token,\r\n       g.title,\r\n       g.category,\r\n       g.pageCount,\r\n       g.galleryUrl,\r\n       g.oldVersionGalleryUrl,\r\n       g.uploader,\r\n       g.publishTime,\r\n       g.downloadStatusIndex as galleryDownloadStatusIndex,\r\n       g.insertTime,\r\n       g.downloadOriginalImage,\r\n       i.url,\r\n       i.serialNo,\r\n       i.height,\r\n       i.width,\r\n       i.path,\r\n       i.imageHash,\r\n       i.downloadStatusIndex as imageDownloadStatusIndex\r\nFROM gallery_downloaded g\r\n         left join image i on g.gid = i.gid\r\nORDER BY insertTime DESC, serialNo',
        variables: [],
        readsFrom: {
          galleryDownloaded,
          image,
        }).map((QueryRow row) {
      return SelectGallerysWithImagesResult(
        gid: row.read<int>('gid'),
        token: row.read<String>('token'),
        title: row.read<String>('title'),
        category: row.read<String>('category'),
        pageCount: row.read<int>('pageCount'),
        galleryUrl: row.read<String>('galleryUrl'),
        oldVersionGalleryUrl: row.read<String?>('oldVersionGalleryUrl'),
        uploader: row.read<String?>('uploader'),
        publishTime: row.read<String>('publishTime'),
        galleryDownloadStatusIndex: row.read<int>('galleryDownloadStatusIndex'),
        insertTime: row.read<String?>('insertTime'),
        downloadOriginalImage: row.read<bool>('downloadOriginalImage'),
        url: row.read<String?>('url'),
        serialNo: row.read<int?>('serialNo'),
        height: row.read<double?>('height'),
        width: row.read<double?>('width'),
        path: row.read<String?>('path'),
        imageHash: row.read<String?>('imageHash'),
        imageDownloadStatusIndex: row.read<int?>('imageDownloadStatusIndex'),
      );
    });
  }

  Selectable<GalleryDownloadedData> selectGallerys() {
    return customSelect(
        'SELECT *\r\nFROM gallery_downloaded\r\nORDER BY insertTime DESC',
        variables: [],
        readsFrom: {
          galleryDownloaded,
        }).map(galleryDownloaded.mapFromRow);
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
      bool downloadOriginalImage) {
    return customInsert(
      'insert into gallery_downloaded\r\nvalues (:gid, :token, :title, :category, :pageCount, :galleryUrl, :oldVersionGalleryUrl, :uploader, :publishTime,\r\n        :downloadStatusIndex, :insertTime, :downloadOriginalImage)',
      variables: [
        Variable<int>(gid),
        Variable<String>(token),
        Variable<String>(title),
        Variable<String>(category),
        Variable<int>(pageCount),
        Variable<String>(galleryUrl),
        Variable<String?>(oldVersionGalleryUrl),
        Variable<String?>(uploader),
        Variable<String>(publishTime),
        Variable<int>(downloadStatusIndex),
        Variable<String?>(insertTime),
        Variable<bool>(downloadOriginalImage)
      ],
      updates: {galleryDownloaded},
    );
  }

  Future<int> deleteGallery(int gid) {
    return customUpdate(
      'delete\r\nfrom gallery_downloaded\r\nwhere gid = :gid',
      variables: [Variable<int>(gid)],
      updates: {galleryDownloaded},
      updateKind: UpdateKind.delete,
    );
  }

  Future<int> updateGallery(int downloadStatusIndex, int gid) {
    return customUpdate(
      'update gallery_downloaded\r\nset downloadStatusIndex = :downloadStatusIndex\r\nwhere gid = :gid',
      variables: [Variable<int>(downloadStatusIndex), Variable<int>(gid)],
      updates: {galleryDownloaded},
      updateKind: UpdateKind.update,
    );
  }

  Selectable<GalleryDownloadedData> selectImagesByGalleryId(int gid) {
    return customSelect(
        'SELECT *\r\nFROM gallery_downloaded\r\nwhere gid = :gid',
        variables: [
          Variable<int>(gid)
        ],
        readsFrom: {
          galleryDownloaded,
        }).map(galleryDownloaded.mapFromRow);
  }

  Future<int> insertImage(String url, int serialNo, int gid, double height,
      double width, String path, String imageHash, int downloadStatusIndex) {
    return customInsert(
      'insert into image\r\nvalues (:url, :serialNo, :gid, :height, :width, :path, :imageHash, :downloadStatusIndex)',
      variables: [
        Variable<String>(url),
        Variable<int>(serialNo),
        Variable<int>(gid),
        Variable<double>(height),
        Variable<double>(width),
        Variable<String>(path),
        Variable<String>(imageHash),
        Variable<int>(downloadStatusIndex)
      ],
      updates: {image},
    );
  }

  Future<int> updateImageStatus(int downloadStatusIndex, int gid, String url) {
    return customUpdate(
      'update image\r\nset downloadStatusIndex = :downloadStatusIndex\r\nwhere gid = :gid\r\n  AND url = :url',
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
      'update image\r\nset path = :path\r\nwhere gid = :gid\r\n  AND url = :url',
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
      'update image\r\nset url = :newUrl\r\nwhere gid = :gid\r\n  AND serialNo = :serialNo',
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
      'delete\r\nfrom image\r\nwhere gid = :gid\r\n  AND url = :url',
      variables: [Variable<int>(gid), Variable<String>(url)],
      updates: {image},
      updateKind: UpdateKind.delete,
    );
  }

  Future<int> deleteImagesWithGid(int gid) {
    return customUpdate(
      'delete\r\nfrom image\r\nwhere gid = :gid',
      variables: [Variable<int>(gid)],
      updates: {image},
      updateKind: UpdateKind.delete,
    );
  }

  @override
  Iterable<TableInfo> get allTables => allSchemaEntities.whereType<TableInfo>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities =>
      [tag, archiveDownloaded, galleryDownloaded, image];
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
  final String? url;
  final int? serialNo;
  final double? height;
  final double? width;
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
    this.url,
    this.serialNo,
    this.height,
    this.width,
    this.path,
    this.imageHash,
    this.imageDownloadStatusIndex,
  });
}
