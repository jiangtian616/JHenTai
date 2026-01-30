import 'package:get/get.dart';
import 'package:jhentai/src/enum/config_enum.dart';
import 'package:jhentai/src/extension/get_logic_extension.dart';
import 'package:jhentai/src/service/jh_service.dart';
import 'package:jhentai/src/service/local_config_service.dart';

ReadProgressService readProgressService = ReadProgressService();

class ReadProgressService extends GetxController with JHLifeCircleBeanErrorCatch implements JHLifeCircleBean {
  static const String readProgressUpdateId = 'readProgress';

  @override
  List<JHLifeCircleBean> get initDependencies => super.initDependencies..addAll([localConfigService]);

  /// Maximum cache size to prevent unbounded growth
  static const int _maxCacheSize = 100;

  /// Cache for read progress: gid -> readIndex
  final Map<String, int> _progressCache = {};

  /// Track access order for LRU eviction
  final List<String> _accessOrder = [];

  @override
  Future<void> doInitBean() async {
    Get.put(this, permanent: true);
  }

  @override
  Future<void> doAfterBeanReady() async {}

  /// Get read progress for a gallery with cache
  Future<int> getReadProgress(int gid) async {
    final key = gid.toString();

    // Return from cache if available
    if (_progressCache.containsKey(key)) {
      // Move to end of access order (most recently used)
      _accessOrder.remove(key);
      _accessOrder.add(key);
      return _progressCache[key]!;
    }

    // Read from storage
    final data = await localConfigService.read(
      configKey: ConfigEnum.readIndexRecord,
      subConfigKey: key,
    );

    final progress = int.tryParse(data ?? '') ?? 0;
    _addToCache(key, progress);
    return progress;
  }

  /// Add entry to cache with LRU eviction
  void _addToCache(String key, int value) {
    // Evict oldest if at capacity
    while (_progressCache.length >= _maxCacheSize && _accessOrder.isNotEmpty) {
      final oldest = _accessOrder.removeAt(0);
      _progressCache.remove(oldest);
    }

    _progressCache[key] = value;
    if (!_accessOrder.contains(key)) {
      _accessOrder.add(key);
    }
  }

  /// Update read progress and notify listeners
  Future<void> updateReadProgress(String recordKey, int index) async {
    _addToCache(recordKey, index);
    await localConfigService.write(
      configKey: ConfigEnum.readIndexRecord,
      subConfigKey: recordKey,
      value: index.toString(),
    );
    updateSafely(['$readProgressUpdateId::$recordKey']);
  }
}
