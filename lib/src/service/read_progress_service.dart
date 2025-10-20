import 'package:get/get.dart';
import 'package:jhentai/src/enum/config_enum.dart';
import 'package:jhentai/src/service/jh_service.dart';
import 'package:jhentai/src/service/local_config_service.dart';

ReadProgressService readProgressService = ReadProgressService();

class ReadProgressService with JHLifeCircleBeanErrorCatch implements JHLifeCircleBean {
  static const String readProgressUpdateId = 'readProgress';

  /// Cache for read progress: gid -> readIndex
  final Map<int, int> _progressCache = {};

  @override
  Future<void> doInitBean() async {}

  @override
  Future<void> doAfterBeanReady() async {}

  /// Get read progress for a gallery with cache
  Future<int> getReadProgress(int gid) async {
    // Return from cache if available
    if (_progressCache.containsKey(gid)) {
      return _progressCache[gid]!;
    }

    // Read from storage
    final data = await localConfigService.read(
      configKey: ConfigEnum.readIndexRecord,
      subConfigKey: gid.toString(),
    );

    final progress = int.tryParse(data ?? '') ?? 0;
    _progressCache[gid] = progress;
    return progress;
  }

  /// Update read progress and notify listeners
  void updateReadProgress(int gid, int index) {
    _progressCache[gid] = index;
    Get.find<ReadProgressController>().update(['$readProgressUpdateId::$gid']);
  }

  /// Clear a specific gallery's cache
  void clearProgress(int gid) {
    _progressCache.remove(gid);
  }

  /// Clear all cache
  void clearAllCache() {
    _progressCache.clear();
  }

  /// Preload read progress for multiple galleries
  Future<void> preloadProgress(List<int> gids) async {
    final missingGids = gids.where((gid) => !_progressCache.containsKey(gid)).toList();
    if (missingGids.isEmpty) {
      return;
    }

    // Batch read from storage
    for (final gid in missingGids) {
      final data = await localConfigService.read(
        configKey: ConfigEnum.readIndexRecord,
        subConfigKey: gid.toString(),
      );
      _progressCache[gid] = int.tryParse(data ?? '') ?? 0;
    }
  }
}

/// GetX Controller for UI updates
/// This controller should be registered separately in GetX
class ReadProgressController extends GetxController {
  static ReadProgressController get instance {
    if (!Get.isRegistered<ReadProgressController>()) {
      Get.put(ReadProgressController(), permanent: true);
    }
    return Get.find<ReadProgressController>();
  }
}

