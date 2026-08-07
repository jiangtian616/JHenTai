import 'dart:async';
import 'dart:io';

import 'package:extended_image/extended_image.dart'
    show ExtendedImageCacheEventType, extendedImageCacheObserver;
import 'package:get/get.dart';
import 'package:jhentai/src/database/dao/dio_cache_dao.dart';
import 'package:jhentai/src/database/dao/smart_cache_stat_dao.dart';
import 'package:jhentai/src/database/database.dart';
import 'package:jhentai/src/service/path_service.dart';
import 'package:jhentai/src/setting/network_setting.dart';
import 'package:path/path.dart';

import 'jh_service.dart';
import 'log.dart';

SmartCacheService smartCacheService = SmartCacheService();

/// Tracks smart-cache usage (images + pages) and enforces the optional space
/// limit using the configured eviction policy.
class SmartCacheService
    with JHLifeCircleBeanErrorCatch
    implements JHLifeCircleBean {
  Timer? _enforceTimer;

  @override
  List<JHLifeCircleBean> get initDependencies =>
      super.initDependencies..add(networkSetting);

  @override
  Future<void> doInitBean() async {
    extendedImageCacheObserver =
        (String key, ExtendedImageCacheEventType event) {
      switch (event) {
        case ExtendedImageCacheEventType.hit:
          unawaited(SmartCacheStatDao.recordHit(key, kind: 'image'));
          break;
        case ExtendedImageCacheEventType.written:
          unawaited(_onImageWritten(key));
          break;
        case ExtendedImageCacheEventType.deleted:
          unawaited(SmartCacheStatDao.deleteByKey(key));
          break;
        case ExtendedImageCacheEventType.cleared:
          unawaited(SmartCacheStatDao.deleteByKind('image'));
          break;
      }
    };

    ever(networkSetting.smartCacheMaxSizeMB, (_) {
      _scheduleEnforceSpaceLimit();
    });

    Timer.periodic(
      const Duration(minutes: 5),
      (_) => unawaited(enforceSpaceLimit()),
    );
    Timer(const Duration(seconds: 30), () {
      unawaited(enforceSpaceLimit());
    });
  }

  @override
  Future<void> doAfterBeanReady() async {}

  Future<void> _onImageWritten(String key) async {
    final File file = File(join(
      pathService.tempDir.path,
      PathService.smartCacheFolderName,
      key,
    ));
    final int size = file.existsSync() ? file.lengthSync() : 0;
    await SmartCacheStatDao.recordWritten(
      key,
      kind: 'image',
      url: key,
      sizeBytes: size,
    );
    _scheduleEnforceSpaceLimit();
  }

  void _scheduleEnforceSpaceLimit() {
    _enforceTimer?.cancel();
    _enforceTimer = Timer(const Duration(seconds: 10), () {
      unawaited(enforceSpaceLimit());
    });
  }

  Future<void> enforceSpaceLimit() async {
    final int maxSizeMB = networkSetting.smartCacheMaxSizeMB.value;
    if (maxSizeMB <= 0) {
      return;
    }

    final int maxBytes = maxSizeMB * 1024 * 1024;
    final List<_CacheEntry> entries = await _collectEntries();
    int totalBytes = entries.fold<int>(
        0, (sum, entry) => sum + entry.sizeBytes);
    if (totalBytes <= maxBytes) {
      return;
    }

    entries.sort(networkSetting.smartCacheEvictPolicy.value ==
            SmartCacheEvictPolicy.addedDate
        ? _compareByAddedDate
        : _compareByUsageFrequency);

    final int targetBytes = maxBytes * 9 ~/ 10;
    int evicted = 0;
    for (final _CacheEntry entry in entries) {
      if (totalBytes <= targetBytes) {
        break;
      }
      await _deleteEntry(entry);
      totalBytes -= entry.sizeBytes;
      evicted++;
    }

    if (evicted > 0) {
      log.info('Smart cache space limit enforced, evicted: $evicted');
    }
  }

  Future<List<_CacheEntry>> _collectEntries() async {
    final Map<String, SmartCacheStatData> stats = {
      for (final SmartCacheStatData stat
          in await SmartCacheStatDao.selectAll())
        stat.cacheKey: stat,
    };

    final List<_CacheEntry> entries = [];
    final Directory imageDir = Directory(join(
      pathService.tempDir.path,
      PathService.smartCacheFolderName,
    ));
    if (imageDir.existsSync()) {
      await for (final FileSystemEntity entity in imageDir.list()) {
        if (entity is! File) {
          continue;
        }
        final String key = basename(entity.path);
        final int size = entity.lengthSync();
        final SmartCacheStatData? stat = stats[key];
        final FileStat fileStat = entity.statSync();
        final DateTime fallbackTime = fileStat.modified;
        entries.add(_CacheEntry(
          key: key,
          kind: 'image',
          sizeBytes: size,
          addedAt: stat?.addedAt ?? fallbackTime,
          lastAccessAt: stat?.lastAccessAt ?? fallbackTime,
          accessCount: stat?.accessCount ?? 0,
        ));
      }
    }

    final List<DioCachePageInfo> pages = await DioCacheDao.selectAllWithSize();
    for (final DioCachePageInfo page in pages) {
      final SmartCacheStatData? stat = stats[page.cacheKey];
      final DateTime fallbackTime = page.expireDate
          .subtract(networkSetting.smartCacheRetention.value);
      entries.add(_CacheEntry(
        key: page.cacheKey,
        kind: 'page',
        sizeBytes: page.sizeBytes,
        addedAt: stat?.addedAt ?? fallbackTime,
        lastAccessAt: stat?.lastAccessAt ?? fallbackTime,
        accessCount: stat?.accessCount ?? 0,
      ));
    }

    return entries;
  }

  Future<void> _deleteEntry(_CacheEntry entry) async {
    if (entry.kind == 'image') {
      final File file = File(join(
        pathService.tempDir.path,
        PathService.smartCacheFolderName,
        entry.key,
      ));
      if (file.existsSync()) {
        file.deleteSync();
      }
    } else {
      await DioCacheDao.deleteByCacheKey(entry.key);
    }
    await SmartCacheStatDao.deleteByKey(entry.key);
  }

  int _compareByAddedDate(_CacheEntry a, _CacheEntry b) {
    int result = a.addedAt.compareTo(b.addedAt);
    if (result != 0) {
      return result;
    }
    result = a.accessCount.compareTo(b.accessCount);
    if (result != 0) {
      return result;
    }
    return a.key.compareTo(b.key);
  }

  int _compareByUsageFrequency(_CacheEntry a, _CacheEntry b) {
    int result = a.accessCount.compareTo(b.accessCount);
    if (result != 0) {
      return result;
    }
    result = a.lastAccessAt.compareTo(b.lastAccessAt);
    if (result != 0) {
      return result;
    }
    return a.key.compareTo(b.key);
  }
}

class _CacheEntry {
  final String key;
  final String kind;
  final int sizeBytes;
  final DateTime addedAt;
  final DateTime lastAccessAt;
  final int accessCount;

  _CacheEntry({
    required this.key,
    required this.kind,
    required this.sizeBytes,
    required this.addedAt,
    required this.lastAccessAt,
    required this.accessCount,
  });
}
