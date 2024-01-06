import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/database/dao/tag_count_dao.dart';
import 'package:jhentai/src/database/database.dart';
import 'package:jhentai/src/network/eh_request.dart';
import 'package:jhentai/src/service/storage_service.dart';
import 'package:jhentai/src/setting/path_setting.dart';
import 'package:jhentai/src/setting/preference_setting.dart';
import 'package:jhentai/src/utils/archive_util.dart';
import 'package:jhentai/src/utils/eh_spider_parser.dart';
import 'package:jhentai/src/widget/loading_state_indicator.dart';
import 'package:path/path.dart';
import 'package:retry/retry.dart';

import '../utils/byte_util.dart';
import '../utils/log.dart';
import '../utils/toast_util.dart';

class TagSearchOrderOptimizationService extends GetxService {
  final StorageService storageService = Get.find();

  final String savePath = join(PathSetting.getVisibleDir().path, 'tid_count_tag.csv.gz');

  static const String releaseUrl = 'https://github.com/poly000/e-hentai-tag-count/releases/latest';

  Rx<LoadingState> loadingState = LoadingState.idle.obs;
  RxnString version = RxnString(null);
  RxString downloadProgress = RxString('0 MB');

  bool get isReady => PreferenceSetting.enableTagZHSearchOrderOptimization.isTrue && (loadingState.value == LoadingState.success || version.value != null);

  static void init() {
    Get.put(TagSearchOrderOptimizationService());
    Log.debug('init TagSearchOrderOptimizationService success');
  }

  @override
  void onInit() {
    super.onInit();

    loadingState.value = LoadingState.values[storageService.read('TagSearchOrderOptimizationServiceLoadingState') ?? 0];
    version.value = storageService.read('TagTranslationServiceVersion');
    if (isReady) {
      refresh();
    }
  }

  Future<void> refresh() async {
    if (PreferenceSetting.enableTagZHSearchOrderOptimization.isFalse) {
      return;
    }
    if (loadingState.value == LoadingState.loading) {
      return;
    }

    Log.info('Refresh tag order optimization data');

    loadingState.value = LoadingState.loading;
    downloadProgress.value = '0 KB';

    /// get latest tag
    String tag;
    try {
      tag = await retry(
        () => EHRequest.request(
          url: releaseUrl,
          options: Options(followRedirects: false, validateStatus: (status) => status == 302),
          parser: EHSpiderParser.latestReleaseResponse2Tag,
        ),
        maxAttempts: 5,
        onRetry: (error) => Log.warning('Get tag order optimization data failed, retry.'),
      );
    } on DioException catch (e) {
      Log.error('Get tag order optimization data failed after 5 times', e.message);
      loadingState.value = LoadingState.error;
      storageService.write('TagSearchOrderOptimizationServiceLoadingState', LoadingState.error.index);
      return;
    }

    if (tag == version.value) {
      Log.info('Tag order optimization data is up to date, tag: $tag');
      loadingState.value = LoadingState.success;
      storageService.write('TagSearchOrderOptimizationServiceLoadingState', LoadingState.success.index);
      return;
    }

    /// download tag count metadata
    try {
      await retry(
        () => EHRequest.download(
          url: 'https://github.com/poly000/e-hentai-tag-count/releases/download/$tag/tid_count_tag.csv.gz',
          path: savePath,
          receiveTimeout: 10 * 60 * 1000,
          onReceiveProgress: (count, total) => downloadProgress.value = byte2String(count.toDouble()),
        ),
        maxAttempts: 5,
        onRetry: (error) => Log.warning('Download tag order optimization data failed, retry.'),
      );
    } on DioException catch (e) {
      Log.error('Download tag translation data failed after 5 times', e.message);
      loadingState.value = LoadingState.error;
      storageService.write('TagSearchOrderOptimizationServiceLoadingState', LoadingState.error.index);
      return;
    }

    Log.info('Download tag order optimization data success');

    List<int> bytes = await extractGZipArchive(savePath);
    if (bytes.isEmpty) {
      Log.error('Extract tag order optimization data failed');
      toast('internalError'.tr);
      loadingState.value = LoadingState.error;
      storageService.write('TagSearchOrderOptimizationServiceLoadingState', LoadingState.error.index);
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
      Log.error('Parse tag order optimization data failed', e);
      toast('internalError'.tr);
      loadingState.value = LoadingState.error;
      storageService.write('TagSearchOrderOptimizationServiceLoadingState', LoadingState.error.index);
      return;
    }

    if (rows.length < 2) {
      Log.error('Parse tag order optimization data failed, rows length: ${rows.length}');
      toast('internalError'.tr);
      loadingState.value = LoadingState.error;
      storageService.write('TagSearchOrderOptimizationServiceLoadingState', LoadingState.error.index);
      return;
    }

    List<TagCountData> tagCountData =
        rows.where((row) => row[1] >= 5).map((row) => TagCountData(namespaceWithKey: (row[2] as String).replaceAll('"', ''), count: row[1])).toList();
    version.value = null;
    await TagCountDao.updateTagCount(tagCountData);
    version.value = tag;

    storageService.write('TagSearchOrderOptimizationServiceLoadingState', LoadingState.success.index);
    storageService.write('TagTranslationServiceVersion', tag);

    loadingState.value = LoadingState.success;
    File(savePath).delete().ignore();
    Log.info('Refresh tag order optimization data success');
  }

  Future<List<TagCountData>> batchSelectTagCount(List<String> namespaceWithKeys) {
    if (namespaceWithKeys.isEmpty) {
      return Future.value([]);
    }
    return TagCountDao.batchSelectTagCount(namespaceWithKeys);
  }
}
