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

  /// Cache for read progress: gid -> readIndex
  final Map<String, int> _progressCache = {};
  final Set<String> _emptyProgressKeys = {};

  @override
  Future<void> doInitBean() async {
    Get.put(this, permanent: true);
  }

  @override
  Future<void> doAfterBeanReady() async {}

  /// Get read progress for a gallery with cache
  Future<int> getReadProgress(int gid) async {
    return await getReadProgressByKey(gid.toString()) ?? 0;
  }

  Future<int?> getReadProgressByKey(String recordKey) async {
    // Return from cache if available
    if (_progressCache.containsKey(recordKey)) {
      return _progressCache[recordKey]!;
    }
    if (_emptyProgressKeys.contains(recordKey)) {
      return null;
    }

    // Read from storage
    final data = await localConfigService.read(
      configKey: ConfigEnum.readIndexRecord,
      subConfigKey: recordKey,
    );

    final progress = int.tryParse(data ?? '');
    if (progress == null) {
      _emptyProgressKeys.add(recordKey);
      return null;
    }
    _emptyProgressKeys.remove(recordKey);
    _progressCache[recordKey] = progress;
    return progress;
  }

  /// Delete read progress for a gallery and notify listeners
  Future<void> deleteReadProgress(String recordKey) async {
    _progressCache.remove(recordKey);
    await localConfigService.delete(
      configKey: ConfigEnum.readIndexRecord,
      subConfigKey: recordKey,
    );
    updateSafely(['$readProgressUpdateId::$recordKey']);
  }

  /// Update read progress and notify listeners
  Future<void> updateReadProgress(String recordKey, int index) async {
    _progressCache[recordKey] = index;
    _emptyProgressKeys.remove(recordKey);
    await localConfigService.write(
      configKey: ConfigEnum.readIndexRecord,
      subConfigKey: recordKey,
      value: index.toString(),
    );
    updateSafely(['$readProgressUpdateId::$recordKey']);
  }

  Future<void> clearAllReadProgress() async {
    final records = await localConfigService.readWithAllSubKeys(configKey: ConfigEnum.readIndexRecord);
    final recordKeys = {
      ..._progressCache.keys,
      ...records.map((record) => record.subConfigKey),
    };

    _progressCache.clear();
    _emptyProgressKeys.clear();
    await localConfigService.deleteAll(configKey: ConfigEnum.readIndexRecord);

    if (recordKeys.isNotEmpty) {
      updateSafely(recordKeys.map((key) => '$readProgressUpdateId::$key').toList());
    }
    updateSafely();
  }
}
