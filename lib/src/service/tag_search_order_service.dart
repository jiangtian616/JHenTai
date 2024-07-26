import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/database/dao/tag_count_dao.dart';
import 'package:jhentai/src/database/database.dart';
import 'package:jhentai/src/enum/config_enum.dart';
import 'package:jhentai/src/extension/dio_exception_extension.dart';
import 'package:jhentai/src/network/eh_request.dart';
import 'package:jhentai/src/service/storage_service.dart';
import 'package:jhentai/src/service/path_service.dart';
import 'package:jhentai/src/setting/preference_setting.dart';
import 'package:jhentai/src/utils/archive_util.dart';
import 'package:jhentai/src/utils/eh_spider_parser.dart';
import 'package:jhentai/src/widget/loading_state_indicator.dart';
import 'package:path/path.dart';
import 'package:retry/retry.dart';

import '../utils/byte_util.dart';
import 'log.dart';
import '../utils/toast_util.dart';

class TagSearchOrderOptimizationService extends GetxService {
  final StorageService storageService = Get.find();

  final String savePath = join(pathService.getVisibleDir().path, 'tid_count_tag.csv.gz');

  static const String releaseUrl = 'https://github.com/mokurin000/e-hentai-tag-count/releases/latest';

  Rx<LoadingState> loadingState = LoadingState.idle.obs;
  RxnString version = RxnString(null);
  RxString downloadProgress = RxString('0 MB');

  bool get isReady => preferenceSetting.enableTagZHSearchOrderOptimization.isTrue && (loadingState.value == LoadingState.success || version.value != null);

  static void init() {
    Get.put(TagSearchOrderOptimizationService());
    log.debug('init TagSearchOrderOptimizationService success');
  }

  @override
  void onInit() {
    super.onInit();

    loadingState.value = LoadingState.values[storageService.read(ConfigEnum.tagSearchOrderOptimizationServiceLoadingState.key) ?? 0];
    version.value = storageService.read(ConfigEnum.tagTranslationServiceVersion.key);
    if (isReady) {
      refresh();
    }
  }

  Future<void> refresh() async {
    if (preferenceSetting.enableTagZHSearchOrderOptimization.isFalse) {
      return;
    }
    if (loadingState.value == LoadingState.loading) {
      return;
    }

    log.info('Refresh tag order optimization data');

    loadingState.value = LoadingState.loading;
    downloadProgress.value = '0 KB';

    /// get latest tag
    String tag;
    try {
      tag = await retry(
        () => EHRequest.get(
          url: releaseUrl,
          options: Options(followRedirects: false, validateStatus: (status) => status == 302),
          parser: EHSpiderParser.latestReleaseResponse2Tag,
        ),
        maxAttempts: 5,
        onRetry: (error) => log.warning('Get tag order optimization data failed, retry.'),
      );
    } on DioException catch (e) {
      log.error('Get tag order optimization data failed after 5 times', e.errorMsg);
      loadingState.value = LoadingState.error;
      storageService.write(ConfigEnum.tagSearchOrderOptimizationServiceLoadingState.key, LoadingState.error.index);
      return;
    }

    if (tag == version.value) {
      log.info('Tag order optimization data is up to date, tag: $tag');
      loadingState.value = LoadingState.success;
      storageService.write(ConfigEnum.tagSearchOrderOptimizationServiceLoadingState.key, LoadingState.success.index);
      return;
    }

    /// download tag count metadata
    try {
      await retry(
        () => EHRequest.download(
          url: 'https://github.com/mokurin000/e-hentai-tag-count/releases/download/$tag/tid_count_tag.csv.gz',
          path: savePath,
          receiveTimeout: 10 * 60 * 1000,
          onReceiveProgress: (count, total) => downloadProgress.value = byte2String(count.toDouble()),
        ),
        maxAttempts: 5,
        onRetry: (error) => log.warning('Download tag order optimization data failed, retry.'),
      );
    } on DioException catch (e) {
      log.error('Download tag translation data failed after 5 times', e.errorMsg);
      loadingState.value = LoadingState.error;
      storageService.write(ConfigEnum.tagSearchOrderOptimizationServiceLoadingState.key, LoadingState.error.index);
      return;
    }

    log.info('Download tag order optimization data success');

    List<int> bytes = await extractGZipArchive(savePath);
    if (bytes.isEmpty) {
      log.error('Extract tag order optimization data failed');
      toast('internalError'.tr);
      loadingState.value = LoadingState.error;
      storageService.write(ConfigEnum.tagSearchOrderOptimizationServiceLoadingState.key, LoadingState.error.index);
      return;
    }

    List<List<dynamic>> rows;
    try {
      rows = await compute(
        (List<int> bytes) async {
          String csv = utf8.decode(bytes);
          return const CsvToListConverter(eol: '\n', textDelimiter: '\'', allowInvalid: false).convert(csv);
        },
        bytes,
      );
    } on Exception catch (e) {
      log.error('Parse tag order optimization data failed', e);
      toast('internalError'.tr);
      loadingState.value = LoadingState.error;
      storageService.write(ConfigEnum.tagSearchOrderOptimizationServiceLoadingState.key, LoadingState.error.index);
      return;
    }

    if (rows.length < 2) {
      log.error('Parse tag order optimization data failed, rows length: ${rows.length}');
      toast('internalError'.tr);
      loadingState.value = LoadingState.error;
      storageService.write(ConfigEnum.tagSearchOrderOptimizationServiceLoadingState.key, LoadingState.error.index);
      return;
    }

    List<TagCountData> tagCountData =
        rows.where((row) => row[1] >= 5).map((row) => TagCountData(namespaceWithKey: (row[2] as String).replaceAll('"', ''), count: row[1])).toList();
    version.value = null;
    await TagCountDao.replaceTagCount(tagCountData);
    version.value = tag;

    storageService.write(ConfigEnum.tagSearchOrderOptimizationServiceLoadingState.key, LoadingState.success.index);
    storageService.write(ConfigEnum.tagTranslationServiceVersion.key, tag);

    loadingState.value = LoadingState.success;
    File(savePath).delete().ignore();
    log.info('Refresh tag order optimization data success');
  }

  Future<List<TagCountData>> batchSelectTagCount(List<String> namespaceWithKeys) {
    if (namespaceWithKeys.isEmpty) {
      return Future.value([]);
    }
    return TagCountDao.batchSelectTagCount(namespaceWithKeys);
  }
}
