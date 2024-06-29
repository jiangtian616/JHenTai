import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_instance/get_instance.dart';
import 'package:get/get_rx/get_rx.dart';
import 'package:get/get_state_manager/src/simple/get_controllers.dart';
import 'package:get/get_utils/get_utils.dart';
import 'package:intl/intl.dart';
import 'package:j_downloader/j_downloader.dart';
import 'package:jhentai/src/database/dao/archive_group_dao.dart';
import 'package:jhentai/src/database/database.dart';
import 'package:jhentai/src/exception/eh_site_exception.dart';
import 'package:jhentai/src/network/eh_request.dart';
import 'package:jhentai/src/service/super_resolution_service.dart';
import 'package:jhentai/src/setting/download_setting.dart';
import 'package:jhentai/src/setting/network_setting.dart';
import 'package:jhentai/src/setting/path_setting.dart';
import 'package:jhentai/src/utils/speed_computer.dart';
import 'package:jhentai/src/utils/eh_spider_parser.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart';
import 'package:retry/retry.dart';

import '../database/dao/archive_dao.dart';
import '../exception/cancel_exception.dart';
import '../model/gallery_image.dart';
import '../pages/download/grid/mixin/grid_download_page_service_mixin.dart';
import '../utils/archive_util.dart';
import '../utils/file_util.dart';
import '../utils/log.dart';
import '../utils/snack_util.dart';
import 'gallery_download_service.dart';

class ArchiveDownloadService extends GetxController with GridBasePageServiceMixin {
  static const String archiveStatusId = 'archiveStatusId';
  static const String archiveSpeedComputerId = 'archiveSpeedComputerId';

  static const int _retryTimes = 3;
  static const String metadataFileName = 'ametadata';
  static const int _maxTitleLength = 80;
  static const int _maxIsolateCountsTotal = 10;

  final Completer<bool> _completer = Completer();

  Future<bool> get completed => _completer.future;

  List<String> allGroups = [];
  List<ArchiveDownloadedData> archives = <ArchiveDownloadedData>[];
  Map<int, ArchiveDownloadInfo> archiveDownloadInfos = {};

  List<ArchiveDownloadedData> archivesWithGroup(String group) => archives.where((g) => archiveDownloadInfos[g.gid]!.group == group).toList();

  late Worker isolateCountListener;
  late Worker proxyConfigListener;

  static void init() {
    Get.put(ArchiveDownloadService(), permanent: true);
  }

  @override
  Future<void> onInit() async {
    super.onInit();

    await _instantiateFromDB();

    Log.debug('init ArchiveDownloadService success. Tasks count: ${archives.length}');

    for (ArchiveDownloadedData archive in archives) {
      if (archive.archiveStatusCode >= ArchiveStatus.unlocking.code && archive.archiveStatusCode <= ArchiveStatus.unpacking.code) {
        downloadArchive(archive, resume: true);
      }
    }

    _completer.complete(true);

    isolateCountListener = ever(DownloadSetting.archiveDownloadIsolateCount, (_) => _onIsolateCountChange());
    proxyConfigListener = everAll([NetworkSetting.proxyAddress, NetworkSetting.proxyUsername, NetworkSetting.proxyPassword], (_) => _onProxyConfigChange());

    if (DownloadSetting.restoreTasksAutomatically.isTrue) {
      await restoreTasks();
    }
  }

  @override
  void onClose() {
    super.dispose();

    isolateCountListener.dispose();
    proxyConfigListener.dispose();
  }

  bool containArchive(int gid) {
    return archiveDownloadInfos.containsKey(gid);
  }

  Future<void> downloadArchive(ArchiveDownloadedData archive, {bool resume = false}) async {
    await _ensureDownloadDirExists();

    if (!resume) {
      if (archiveDownloadInfos.containsKey(archive.gid)) {
        return;
      }
      if (!await _initArchiveInfo(archive)) {
        return;
      }
    }

    Log.info('Begin to handle archive: ${archive.title}, original: ${archive.isOriginal}');

    /// step 1: request to unlock archive: if we have unlocked before or unlock has completed,
    /// we can get [downloadPageUrl] immediately, otherwise we must wait for a second
    await _unlock(archive);

    /// step 2: circularly check if unlock has completed so that we can get [downloadPageUrl]
    await _getDownloadPageUrl(archive);

    /// step 3: parse download url
    await _getDownloadUrl(archive);

    /// step 4: do download
    await _doDownloadArchiveViaMultiIsolate(archive);

    /// step 5: unpacking files
    await _unpackingArchive(archive);
  }

  Future<void> deleteArchive(int gid) async {
    ArchiveDownloadedData? archive = archives.firstWhereOrNull((archive) => archive.gid == gid);
    if (archive != null) {
      Log.info('Delete archive: ${archive.title}, original: ${archive.isOriginal}');

      await pauseDownloadArchive(gid);

      await Get.find<SuperResolutionService>().deleteSuperResolve(gid, SuperResolutionType.archive);

      await _deleteArchiveInfoInDatabase(gid);

      await _deleteArchiveInDisk(archive);

      _deleteArchiveInMemory(gid);

      update(['$archiveStatusId::${archive.gid}']);
    }
  }

  Future<void> pauseAllDownloadArchive() async {
    await Future.wait(archives.map((a) => a.gid).map(pauseDownloadArchive).toList());
  }

  Future<void> pauseDownloadArchive(int gid, {bool needReUnlock = false}) async {
    ArchiveDownloadedData? archive = archives.firstWhereOrNull((archive) => archive.gid == gid);
    if (archive != null) {
      ArchiveDownloadInfo archiveDownloadInfo = archiveDownloadInfos[gid]!;
      if (archiveDownloadInfo.archiveStatus.code <= ArchiveStatus.paused.code || archiveDownloadInfo.archiveStatus.code >= ArchiveStatus.downloaded.code) {
        return;
      }

      Log.info('Pause archive: ${archive.title}, original: ${archive.isOriginal}');

      archiveDownloadInfo.cancelToken.cancel();
      archiveDownloadInfo.cancelToken = CancelToken();
      await archiveDownloadInfo.downloadTask?.pause();
      archiveDownloadInfo.downloadCompleter?.completeError(CancelException());
      archiveDownloadInfo.speedComputer.pause();

      await _updateArchiveStatus(gid, needReUnlock ? ArchiveStatus.needReUnlock : ArchiveStatus.paused);

      _tryWakeWaitingTasks();
    }
  }

  Future<void> resumeAllDownloadArchive() async {
    await Future.wait(archives.map((a) => a.gid).map(resumeDownloadArchive).toList());
  }

  Future<void> resumeDownloadArchive(int gid) async {
    ArchiveDownloadedData? archive = archives.firstWhereOrNull((archive) => archive.gid == gid);
    if (archive != null) {
      ArchiveDownloadInfo archiveDownloadInfo = archiveDownloadInfos[archive.gid]!;
      if (archiveDownloadInfo.archiveStatus != ArchiveStatus.paused) {
        return;
      }

      Log.info('Resume archive: ${archive.title}, original: ${archive.isOriginal}');

      await _updateArchiveStatus(gid, ArchiveStatus.unlocking);

      downloadArchive(archive, resume: true);
    }
  }

  /// cancel archive to deal with 410
  Future<void> cancelArchive(int gid) async {
    ArchiveDownloadedData? archive = archives.firstWhereOrNull((a) => a.gid == gid);
    if (archive != null) {
      ArchiveDownloadInfo archiveDownloadInfo = archiveDownloadInfos[archive.gid]!;
      if (archiveDownloadInfo.archiveStatus.code >= ArchiveStatus.downloaded.code) {
        return;
      }

      Log.download('Cancel archive: ${archive.title}, original: ${archive.isOriginal}');

      archiveDownloadInfo.archiveStatus = ArchiveStatus.unlocking;
      archiveDownloadInfo.downloadPageUrl = null;
      archiveDownloadInfo.downloadUrl = null;
      archiveDownloadInfo.downloadTask = null;
      archiveDownloadInfo.cancelToken.cancel();
      archiveDownloadInfo.cancelToken = CancelToken();
      await archiveDownloadInfo.downloadTask?.pause();
      archiveDownloadInfo.downloadCompleter?.completeError(CancelException());

      await _updateArchiveInDatabase(archive.gid);
      update(['$archiveStatusId::${archive.gid}']);

      try {
        await retry(
          () => EHRequest.requestCancelArchive(
            url: archive.archivePageUrl.replaceFirst('--', '-'),
            cancelToken: archiveDownloadInfo.cancelToken,
          ),
          retryIf: (e) => e is DioException && e.type != DioExceptionType.cancel,
          onRetry: (e) => Log.download('Cancel archive: ${archive.title} failed, retry. Reason: ${(e as DioException).message}'),
          maxAttempts: _retryTimes,
        );
      } on DioException catch (e) {
        if (e.type == DioExceptionType.cancel) {
          return;
        }

        Log.download('Cancel archive error, reason: ${e.toString()}');
        return pauseDownloadArchive(archive.gid);
      }
    }
  }

  Future<void> migrate2Gallery(int gid) async {
    ArchiveDownloadedData? archive = archives.firstWhereOrNull((archive) => archive.gid == gid);
    if (archive == null) {
      Log.error('Archive not found: $gid');
      return;
    }

    ArchiveDownloadInfo archiveDownloadInfo = archiveDownloadInfos[archive.gid]!;
    if (archiveDownloadInfo.archiveStatus != ArchiveStatus.completed) {
      Log.error('Archive not completed: $gid');
      return;
    }

    GalleryDownloadedData galleryDownloadedData = GalleryDownloadedData(
      gid: archive.gid,
      token: archive.token,
      title: archive.title,
      category: archive.category,
      pageCount: archive.pageCount,
      galleryUrl: archive.galleryUrl,
      uploader: archive.uploader,
      publishTime: archive.publishTime,
      downloadStatusIndex: DownloadStatus.downloaded.index,
      downloadOriginalImage: archive.isOriginal,
      sortOrder: 0,
      groupName: archiveDownloadInfo.group,
      insertTime: DateTime.now().toString(),
      priority: GalleryDownloadService.defaultDownloadGalleryPriority,
      tags: archive.tags,
      tagRefreshTime: archive.tagRefreshTime,
    );
    List<GalleryImage> images = await getUnpackedImages(gid);

    if (images.length != archive.pageCount) {
      Log.error('Unpacked images count not equal to page count: ${images.length} != ${archive.pageCount}');
      return;
    }

    return Get.find<GalleryDownloadService>().importGallery(galleryDownloadedData, images);
  }

  Future<bool> updateArchiveGroup(int gid, String group) async {
    ArchiveDownloadInfo? archiveDownloadInfo = archiveDownloadInfos[gid];
    if (archiveDownloadInfo == null) {
      return false;
    }

    archiveDownloadInfo.group = group;

    if (!allGroups.contains(group)) {
      if (!await _addGroup(group)) {
        return false;
      }
    }

    _sortArchives();

    return _updateArchiveInDatabase(gid);
  }

  Future<void> renameGroup(String oldGroup, String newGroup) async {
    List<ArchiveDownloadedData> archiveDownloadedDatas = archives.where((a) => archiveDownloadInfos[a.gid]!.group == oldGroup).toList();

    await appDb.transaction(() async {
      if (!allGroups.contains(newGroup)) {
        int index = allGroups.indexOf(oldGroup);
        allGroups[index] = newGroup;
        await ArchiveGroupDao.insertArchiveGroup(ArchiveGroupData(groupName: newGroup, sortOrder: index));
      }

      for (ArchiveDownloadedData a in archiveDownloadedDatas) {
        archiveDownloadInfos[a.gid]!.group = newGroup;
        await _updateArchiveInDatabase(a.gid);
      }

      await deleteGroup(oldGroup);
    });

    _sortArchives();
  }

  Future<bool> deleteGroup(String group) async {
    allGroups.remove(group);

    try {
      return (await ArchiveGroupDao.deleteArchiveGroup(group) > 0);
    } on SqliteException catch (e) {
      Log.info(e);
      return false;
    }
  }

  Future<void> updateGroupOrder(int beforeIndex, int afterIndex) async {
    if (afterIndex == allGroups.length - 1) {
      allGroups.add(allGroups.removeAt(beforeIndex));
    } else {
      allGroups.insert(afterIndex, allGroups.removeAt(beforeIndex));
    }

    Log.info('Update group order: $allGroups');

    await appDb.transaction(() async {
      for (int i = 0; i < allGroups.length; i++) {
        await ArchiveGroupDao.updateArchiveGroupOrder(allGroups[i], i);
      }
    });
  }

  Future<void> batchUpdateArchiveInDatabase(List<ArchiveDownloadedData> archives) async {
    await appDb.transaction(() async {
      for (ArchiveDownloadedData archive in archives) {
        await _updateArchiveInDatabase(archive.gid);
      }
    });

    _sortArchives();
  }

  /// Use meta in each archive folder to restore download tasks, then sync to database.
  /// this is used after re-install app, or share download folder to another user.
  Future<int> restoreTasks() async {
    await completed;

    Directory downloadDir = Directory(DownloadSetting.downloadPath.value);
    if (!await downloadDir.exists()) {
      return 0;
    }

    int restoredCount = 0;
    await for (FileSystemEntity galleryDir in downloadDir.list()) {
      File metadataFile = File(join(galleryDir.path, metadataFileName));

      /// metadata file does not exist
      if (!await metadataFile.exists()) {
        continue;
      }

      Map metadata = jsonDecode(metadataFile.readAsStringSync());

      /// compatible with new field
      metadata.putIfAbsent('sortOrder', () => 0);
      metadata.putIfAbsent('archiveStatusCode', () => ArchiveStatus.completed.code);
      if (metadata['groupName'] == null) {
        metadata['groupName'] = 'default'.tr;
      }
      if (metadata['tags'] == null) {
        metadata['tags'] = '';
      }
      if (metadata['tagRefreshTime'] == null) {
        metadata['tagRefreshTime'] = DateTime.now().toString();
      }

      ArchiveDownloadedData archive = ArchiveDownloadedData.fromJson(metadata as Map<String, dynamic>);

      /// skip if exists
      if (archiveDownloadInfos.containsKey(archive.gid)) {
        continue;
      }

      archive = archive.copyWith(archiveStatusCode: ArchiveStatus.completed.code);

      if (!await _saveArchiveAndGroupInDatabase(archive)) {
        Log.error('Restore archive failed: $archive');
        await deleteArchive(archive.gid);
        continue;
      }

      _initArchiveInMemory(archive, sort: false);

      restoredCount++;
    }

    if (restoredCount > 0) {
      _sortArchives();
    }

    return restoredCount;
  }

  Future<List<GalleryImage>> getUnpackedImages(int gid, {bool computeHash = false}) async {
    ArchiveDownloadedData archive = archives.firstWhere((a) => a.gid == gid);
    Directory directory = Directory(computeArchiveUnpackingPath(archive.title, archive.gid));

    return directory.list().toList().then((files) {
      List<File> imageFiles = files.whereType<File>().where((file) => FileUtil.isImageExtension(file.path)).toList();
      imageFiles.sort(FileUtil.naturalCompareFile);
      return imageFiles;
    }).then((imageFiles) {
      return imageFiles
          .map(
            (file) => GalleryImage(
              url: '',
              path: relative(file.path, from: PathSetting.getVisibleDir().path),
              downloadStatus: DownloadStatus.downloaded,
            ),
          )
          .toList();
    }).then((images) {
      if (!computeHash) {
        return images;
      }

      List<Future> futures = [];
      for (GalleryImage image in images) {
        futures.add(FileUtil.computeSha1Hash(File(join(PathSetting.getVisibleDir().path, image.path))).then((value) => image.imageHash = value));
      }
      return Future.wait(futures).then((_) => images);
    });
  }

  String _computeArchiveTitle(String rawTitle) {
    String title = rawTitle.replaceAll(RegExp(r'[/|?,:*"<>\\.]'), ' ').trim();

    if (title.length > _maxTitleLength) {
      title = title.substring(0, _maxTitleLength).trim();
    }

    return title;
  }

  String computePackingFileDownloadPath(ArchiveDownloadedData archive) {
    String title = _computeArchiveTitle(archive.title);

    return join(DownloadSetting.downloadPath.value, 'ArchiveV2 - ${archive.gid} - $title.zip');
  }

  String computeArchiveUnpackingPath(String rawTitle, int gid) {
    String title = _computeArchiveTitle(rawTitle);

    return join(DownloadSetting.downloadPath.value, 'Archive - $gid - $title');
  }

  void _sortArchives() {
    archives.sort((a, b) {
      ArchiveDownloadInfo aInfo = archiveDownloadInfos[a.gid]!;
      ArchiveDownloadInfo bInfo = archiveDownloadInfos[b.gid]!;

      if (!(aInfo.group == 'default'.tr && bInfo.group == 'default'.tr)) {
        if (aInfo.group == 'default'.tr) {
          return 1;
        }
        if (bInfo.group == 'default'.tr) {
          return -1;
        }
      }

      int gResult = aInfo.group.compareTo(bInfo.group);
      if (gResult != 0) {
        return gResult;
      }

      int aOrder = aInfo.sortOrder;
      int bOrder = bInfo.sortOrder;
      if (aOrder - bOrder != 0) {
        return aOrder - bOrder;
      }

      DateTime aTime = DateFormat('yyyy-MM-dd HH:mm:ss').parse(a.insertTime);
      DateTime bTime = DateFormat('yyyy-MM-dd HH:mm:ss').parse(b.insertTime);

      return bTime.difference(aTime).inMilliseconds;
    });
  }

  JDownloadTask _generateDownloadTask(String url, ArchiveDownloadedData archive) {
    return JDownloadTask.newTask(
      url: url,
      savePath: computePackingFileDownloadPath(archive),
      isolateCount: DownloadSetting.archiveDownloadIsolateCount.value,
      deleteWhenUrlMismatch: false,
      proxyConfig: EHRequest.currentProxyConfig(),
      onLog: (OutputEvent event) {},
      onProgress: (current, total) {
        ArchiveDownloadInfo archiveDownloadInfo = archiveDownloadInfos[archive.gid]!;
        archiveDownloadInfo.speedComputer.downloadedBytes = current;
        if (total != archiveDownloadInfo.size) {
          archiveDownloadInfo.size = total;
          _updateArchiveInDatabase(archive.gid);
        }
      },
      onDone: () async {
        archiveDownloadInfos[archive.gid]!.downloadCompleter?.complete();
      },
      onError: (JDownloadException e) async {
        archiveDownloadInfos[archive.gid]!.downloadCompleter?.completeError(e);
      },
    );
  }

  Future<void> _check410Reason(String url, ArchiveDownloadedData archive) async {
    try {
      await EHRequest.get(
        url: url,
        cancelToken: archiveDownloadInfos[archive.gid]?.cancelToken,
      );
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        return;
      }

      if (e.response?.statusCode != 410) {
        Log.download('Check archive  ${archive.title} 410 reason failed, pause task.');
        return pauseDownloadArchive(archive.gid);
      }

      if (e.response!.data is String && e.response!.data.contains('You have clocked too many downloaded bytes on this gallery')) {
        Log.download('${'410Hints'.tr} Archive: ${archive.title}');
        snack('archiveError'.tr, '${'410Hints'.tr} : ${archive.title}', longDuration: true);
        return pauseDownloadArchive(archive.gid, needReUnlock: true);
      } else if (e.response!.data is String && e.response!.data.contains('IP quota exhausted')) {
        Log.download('IP quota exhausted! Archive: ${archive.title}');
        snack('archiveError'.tr, 'IP quota exhausted!', longDuration: true);
        return pauseDownloadArchive(archive.gid, needReUnlock: true);
      } else if (e.response!.data is String && e.response!.data.contains('Expired or invalid session')) {
        Log.download('Expired or invalid session! Archive: ${archive.title}');
        snack('archiveError'.tr, 'Expired or invalid session!', longDuration: true);
        return pauseDownloadArchive(archive.gid);
      } else {
        Log.download('Download archive 410, try re-parse. Archive: ${archive.title}');

        archiveDownloadInfos[archive.gid]!.downloadUrl = null;
        await _updateArchiveStatus(archive.gid, ArchiveStatus.parsedDownloadPageUrl);

        await _getDownloadUrl(archive);
        return _doDownloadArchiveViaMultiIsolate(archive);
      }
    }

    return _doDownloadArchiveViaMultiIsolate(archive);
  }

  Future<void> _tryWakeWaitingTasks() async {
    int currentActiveIsolateCount = archiveDownloadInfos.values
        .where((a) => a.archiveStatus == ArchiveStatus.downloading)
        .fold(0, (previousValue, a) => previousValue + a.downloadTask!.activeIsolateCount);
    if (currentActiveIsolateCount >= _maxIsolateCountsTotal) {
      return;
    }

    List<int> gids = archiveDownloadInfos.entries.where((e) => e.value.archiveStatus == ArchiveStatus.waitingIsolate).map((e) => e.key).toList();
    List<ArchiveDownloadedData> waitingArchives = archives.where((a) => gids.contains(a.gid)).toList();
    waitingArchives.sort((a, b) => a.insertTime.compareTo(b.insertTime));

    for (ArchiveDownloadedData a in waitingArchives) {
      ArchiveDownloadInfo archiveDownloadInfo = archiveDownloadInfos[a.gid]!;
      if (currentActiveIsolateCount + archiveDownloadInfo.downloadTask!.isolateCount <= _maxIsolateCountsTotal) {
        Log.download('Archive ${a.title} gain isolates.');
        await _updateArchiveStatus(a.gid, ArchiveStatus.downloading);
        downloadArchive(a, resume: true);
        return;
      }
    }
  }

  void _onIsolateCountChange() {
    for (ArchiveDownloadInfo archiveDownloadInfo in archiveDownloadInfos.values) {
      if (archiveDownloadInfo.archiveStatus.code <= ArchiveStatus.unpacking.code && archiveDownloadInfo.downloadTask != null) {
        archiveDownloadInfo.downloadTask!.changeIsolateCount(DownloadSetting.archiveDownloadIsolateCount.value);
      }
    }
  }

  void _onProxyConfigChange() {
    for (ArchiveDownloadInfo archiveDownloadInfo in archiveDownloadInfos.values) {
      if (archiveDownloadInfo.archiveStatus.code <= ArchiveStatus.downloading.code && archiveDownloadInfo.downloadTask != null) {
        archiveDownloadInfo.downloadTask!.setProxy(EHRequest.currentProxyConfig());
      }
    }
  }

  bool _isTaskInStatus(int gid, List<ArchiveStatus> statuses) {
    return archiveDownloadInfos.containsKey(gid) && statuses.contains(archiveDownloadInfos[gid]!.archiveStatus);
  }

  Future<void> _updateArchiveStatus(int gid, ArchiveStatus archiveStatus) async {
    ArchiveDownloadInfo archiveDownloadInfo = archiveDownloadInfos[gid]!;

    if (archiveDownloadInfo.archiveStatus != archiveStatus) {
      archiveDownloadInfo.archiveStatus = archiveStatus;
      await _updateArchiveInDatabase(gid);
      update(['$archiveStatusId::$gid']);
    }
  }

  // TASKS

  Future<void> _unlock(ArchiveDownloadedData archive) async {
    ArchiveDownloadInfo archiveDownloadInfo = archiveDownloadInfos[archive.gid]!;

    if (!_isTaskInStatus(archive.gid, [ArchiveStatus.unlocking])) {
      return;
    }
    if (archiveDownloadInfo.downloadPageUrl != null) {
      archiveDownloadInfo.archiveStatus = ArchiveStatus.unlocked;
      return;
    }

    Log.download('Begin to unlock archive: ${archive.title}, original: ${archive.isOriginal}');

    await _updateArchiveStatus(archive.gid, ArchiveStatus.unlocking);

    String? downloadPageUrl;
    try {
      downloadPageUrl = await retry(
        () => EHRequest.requestUnlockArchive(
          url: archive.archivePageUrl.replaceFirst('--', '-'),
          isOriginal: archive.isOriginal,
          cancelToken: archiveDownloadInfo.cancelToken,
          parser: EHSpiderParser.unlockArchivePage2DownloadArchivePageUrl,
        ),
        retryIf: (e) => e is DioException && e.type != DioExceptionType.cancel,
        onRetry: (e) => Log.download('Request unlock archive: ${archive.title} failed, retry. Reason: ${(e as DioException).message}'),
        maxAttempts: _retryTimes,
      );
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        return;
      }
      return await _unlock(archive);
    } on EHSiteException catch (e) {
      Log.download('Unlock archive error, reason: ${e.message}');
      snack('archiveError'.tr, e.message, longDuration: true);

      if (e.shouldPauseAllDownloadTasks) {
        return pauseAllDownloadArchive();
      } else {
        return pauseDownloadArchive(archive.gid);
      }
    }

    if (downloadPageUrl != null) {
      Log.download('Get archive download page url success: ${archive.title}');
      archiveDownloadInfo.downloadPageUrl = downloadPageUrl;
    }

    await _updateArchiveStatus(archive.gid, ArchiveStatus.unlocked);
  }

  Future<void> _getDownloadPageUrl(ArchiveDownloadedData archive) async {
    ArchiveDownloadInfo archiveDownloadInfo = archiveDownloadInfos[archive.gid]!;
    if (!_isTaskInStatus(archive.gid, [ArchiveStatus.unlocked, ArchiveStatus.parsingDownloadPageUrl])) {
      return;
    }
    if (archiveDownloadInfo.downloadPageUrl != null) {
      archiveDownloadInfo.archiveStatus = ArchiveStatus.parsedDownloadPageUrl;
      return;
    }

    Log.download('Begin to circularly fetch archive download page url: ${archive.title}, original: ${archive.isOriginal}');

    await _updateArchiveStatus(archive.gid, ArchiveStatus.parsingDownloadPageUrl);

    String? downloadPageUrl;
    try {
      downloadPageUrl = await retry(
        () => EHRequest.requestUnlockArchive(
          url: archive.archivePageUrl.replaceFirst('--', '-'),
          isOriginal: archive.isOriginal,
          cancelToken: archiveDownloadInfo.cancelToken,
          parser: EHSpiderParser.unlockArchivePage2DownloadArchivePageUrl,
        ),
        retryIf: (e) => e is DioException && e.type != DioExceptionType.cancel,
        onRetry: (e) => Log.download('Request unlock archive: ${archive.title} failed, retry. Reason: ${(e as DioException).message}'),
        maxAttempts: _retryTimes,
      );
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        return;
      }
      return await _unlock(archive);
    } on EHSiteException catch (e) {
      Log.download('Parsing archive download page url failed, reason: ${e.message}');
      snack('archiveError'.tr, e.message, longDuration: true);

      if (e.shouldPauseAllDownloadTasks) {
        return pauseAllDownloadArchive();
      } else {
        return pauseDownloadArchive(archive.gid);
      }
    }

    if (downloadPageUrl == null) {
      /// wait for server operation
      await Future.delayed(const Duration(milliseconds: 1000));
      return _getDownloadPageUrl(archive);
    } else {
      Log.download('Get archive download page url success: ${archive.title}');
      archiveDownloadInfo.downloadPageUrl = downloadPageUrl;
      await _updateArchiveStatus(archive.gid, ArchiveStatus.parsedDownloadPageUrl);
    }
  }

  Future<void> _getDownloadUrl(ArchiveDownloadedData archive) async {
    ArchiveDownloadInfo archiveDownloadInfo = archiveDownloadInfos[archive.gid]!;
    if (!_isTaskInStatus(archive.gid, [ArchiveStatus.parsedDownloadPageUrl, ArchiveStatus.parsingDownloadUrl])) {
      return;
    }
    if (archiveDownloadInfo.downloadUrl != null) {
      archiveDownloadInfo.archiveStatus = ArchiveStatus.parsedDownloadUrl;
      return;
    }

    Log.download('Begin to parse fetch archive download url: ${archive.title}, original: ${archive.isOriginal}');

    await _updateArchiveStatus(archive.gid, ArchiveStatus.parsingDownloadUrl);

    String downloadPath;
    try {
      downloadPath = await retry(
        () => EHRequest.get(
          url: archiveDownloadInfo.downloadPageUrl!,
          cancelToken: archiveDownloadInfo.cancelToken,
          parser: EHSpiderParser.downloadArchivePage2DownloadUrl,
        ),
        retryIf: (e) => e is DioException && e.type != DioExceptionType.cancel,
        onRetry: (e) => Log.download('Parse archive download url: ${archive.title} failed, retry. Reason: ${(e as DioException).message}'),
        maxAttempts: _retryTimes,
      );
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        return;
      }

      return await _getDownloadUrl(archive);
    } on EHSiteException catch (e) {
      Log.download('Download error, reason: ${e.message}');
      snack('archiveError'.tr, e.message, longDuration: true);

      if (e.shouldPauseAllDownloadTasks) {
        return pauseAllDownloadArchive();
      } else {
        return pauseDownloadArchive(archive.gid);
      }
    }

    /// sometimes the download url is invalid(the same as [downloadPageUrl]), retry
    if (!downloadPath.endsWith('start=1')) {
      Log.warning('Failed to parse download url, retry: $downloadPath');
      Log.uploadError(
        Exception('Failed to parse download url!'),
        extraInfos: {
          'downloadPath': downloadPath,
          'archive': archiveDownloadInfo.toString(),
        },
      );
      return _getDownloadUrl(archive);
    }

    archiveDownloadInfo.downloadUrl = 'https://' + Uri.parse(archiveDownloadInfo.downloadPageUrl!).host + downloadPath;
    Log.trace('Parse archive download url success: ${archive.title}, original: ${archive.isOriginal}, url: ${archiveDownloadInfo.downloadUrl}');
    return _updateArchiveStatus(archive.gid, ArchiveStatus.parsedDownloadUrl);
  }

  Future<void> _doDownloadArchiveViaMultiIsolate(ArchiveDownloadedData archive) async {
    ArchiveDownloadInfo archiveDownloadInfo = archiveDownloadInfos[archive.gid]!;
    if (!_isTaskInStatus(archive.gid, [ArchiveStatus.parsedDownloadUrl, ArchiveStatus.downloading])) {
      return;
    }

    Log.download('Begin to download archive: ${archive.title}, original: ${archive.isOriginal}');

    await _updateArchiveStatus(archive.gid, ArchiveStatus.downloading);

    JDownloadTask task = archiveDownloadInfo.downloadTask ??= _generateDownloadTask(archiveDownloadInfo.downloadUrl!, archive);
    archiveDownloadInfo.speedComputer
      ..resetDownloadedBytes(task.currentBytes)
      ..start();
    Log.download('${archive.title} downloaded bytes: ${task.currentBytes}');

    if (task.status != TaskStatus.completed) {
      if (DownloadSetting.manageArchiveDownloadConcurrency.isTrue) {
        int currentActiveIsolateCount = archiveDownloadInfos.entries
            .where((e) => e.value.archiveStatus == ArchiveStatus.downloading)
            .where((e) => e.key != archive.gid)
            .map((e) => e.value)
            .fold(
              0,
              (previousValue, a) =>
                  previousValue + (a.downloadTask!.activeIsolateCount > 0 ? a.downloadTask!.activeIsolateCount : a.downloadTask!.isolateCount),
            );
        if (currentActiveIsolateCount + task.isolateCount > _maxIsolateCountsTotal) {
          Log.download('Archive ${archive.title} is waiting isolates...');
          return _updateArchiveStatus(archive.gid, ArchiveStatus.waitingIsolate);
        }
      }

      try {
        await task.start();

        archiveDownloadInfo.downloadCompleter = Completer();
        await archiveDownloadInfo.downloadCompleter!.future;
      } on CancelException catch (_) {
        archiveDownloadInfo.downloadCompleter = null;
        return;
      } on JDownloadException catch (e) {
        archiveDownloadInfo.downloadCompleter = null;

        if (e.type == JDownloadExceptionType.fetchContentLengthFailed || e.type == JDownloadExceptionType.downloadFailed) {
          DioException dioException = e.error;
          Response? response = dioException.response;

          /// download too many bytes will cause 410
          if (response?.statusCode == 410) {
            return await _check410Reason(archiveDownloadInfos[archive.gid]!.downloadUrl!, archive);
          }

          /// too many download thread will cause 410
          else if (response?.statusCode == 429) {
            Log.download('${'429Hints'.tr} Archive: ${archive.title}');
            snack('archiveError'.tr, '429Hints'.tr, longDuration: true);
            return await pauseDownloadArchive(archive.gid);
          } else {
            Log.download('Download archive failed: ${archive.title}, original: ${archive.isOriginal}, reason: $e');
            snack('archiveError'.tr, e.error.toString(), longDuration: true);
            return pauseDownloadArchive(archive.gid);
          }
        } else {
          Log.download('Download archive failed: ${archive.title}, original: ${archive.isOriginal}, reason: $e');
          snack('archiveError'.tr, e.error.toString(), longDuration: true);
          return pauseDownloadArchive(archive.gid);
        }
      } on Exception catch (e) {
        Log.download('Failed to download archive ${archive.title}, reason: $e');
        snack('archiveError'.tr, e.toString(), longDuration: true);
        archiveDownloadInfo.downloadCompleter = null;
        return pauseDownloadArchive(archive.gid);
      }
    }

    Log.download('Download archive success: ${archive.title}, original: ${archive.isOriginal}');

    archiveDownloadInfo.speedComputer.dispose();
    return _updateArchiveStatus(archive.gid, ArchiveStatus.downloaded);
  }

  Future<void> _unpackingArchive(ArchiveDownloadedData archive) async {
    ArchiveDownloadInfo archiveDownloadInfo = archiveDownloadInfos[archive.gid]!;
    if (!_isTaskInStatus(archive.gid, [ArchiveStatus.downloaded, ArchiveStatus.unpacking])) {
      return;
    }

    Log.info('Unpacking archive: ${archive.title}, original: ${archive.isOriginal}');

    bool success = await extractZipArchive(
      computePackingFileDownloadPath(archive),
      computeArchiveUnpackingPath(archive.title, archive.gid),
    );

    if (!success) {
      Log.error('Unpacking archive error!');
      Log.uploadError(Exception('Unpacking error!'), extraInfos: {'archive': archive});
      snack('unpackingArchiveError'.tr, '${'failedToDealWith'.tr}:${archive.title}', longDuration: true);

      archiveDownloadInfo.archiveStatus = ArchiveStatus.downloading;
      await archiveDownloadInfo.downloadTask!.dispose();
      archiveDownloadInfo.downloadTask = null;
      await _deletePackingFileInDisk(archive);
      return pauseDownloadArchive(archive.gid);
    }

    if (DownloadSetting.deleteArchiveFileAfterDownload.isTrue) {
      _deletePackingFileInDisk(archive);
    }

    await _saveArchiveInfoInDisk(archive);

    await _updateArchiveStatus(archive.gid, ArchiveStatus.completed);

    _tryWakeWaitingTasks();
  }

  // ALL

  Future<void> _instantiateFromDB() async {
    allGroups = (await ArchiveGroupDao.selectArchiveGroups()).map((e) => e.groupName).toList();
    Log.debug('init Archive groups: $allGroups');

    List<ArchiveDownloadedData> archives = await ArchiveDao.selectArchives();

    for (ArchiveDownloadedData archive in archives) {
      _initArchiveInMemory(archive, sort: false);
    }
    _sortArchives();
  }

  Future<bool> _initArchiveInfo(ArchiveDownloadedData archive) async {
    if (!await _saveArchiveAndGroupInDatabase(archive)) {
      return false;
    }
    _initArchiveInMemory(archive);
    return true;
  }

  Future<bool> _addGroup(String group) async {
    if (!allGroups.contains(group)) {
      allGroups.add(group);
    }

    return (await ArchiveGroupDao.insertArchiveGroup(ArchiveGroupData(groupName: group, sortOrder: 0)) > 0);
  }

  // DB

  Future<bool> _saveArchiveAndGroupInDatabase(ArchiveDownloadedData archive) async {
    return appDb.transaction(() async {
      await ArchiveGroupDao.insertArchiveGroup(ArchiveGroupData(groupName: archive.groupName, sortOrder: 0));

      return await ArchiveDao.insertArchive(
            ArchiveDownloadedCompanion.insert(
              gid: Value(archive.gid),
              token: archive.token,
              title: archive.title,
              category: archive.category,
              pageCount: archive.pageCount,
              galleryUrl: archive.galleryUrl,
              coverUrl: archive.coverUrl,
              uploader: Value(archive.uploader),
              size: archive.size,
              publishTime: archive.publishTime,
              archiveStatusCode: archive.archiveStatusCode,
              archivePageUrl: archive.archivePageUrl,
              downloadPageUrl: const Value(null),
              downloadUrl: const Value(null),
              sortOrder: Value(archive.sortOrder),
              groupName: archive.groupName,
              isOriginal: archive.isOriginal,
              insertTime: archive.insertTime,
              tags: Value(archive.tags),
              tagRefreshTime: Value(archive.tagRefreshTime),
            ),
          ) >
          0;
    });
  }

  Future<bool> _updateArchiveInDatabase(int gid) async {
    ArchiveDownloadInfo archiveDownloadInfo = archiveDownloadInfos[gid]!;

    return await ArchiveDao.updateArchive(
          ArchiveDownloadedCompanion(
            gid: Value(gid),
            archiveStatusCode: Value(archiveDownloadInfo.archiveStatus.code),
            downloadPageUrl: archiveDownloadInfo.downloadPageUrl == null ? const Value.absent() : Value(archiveDownloadInfo.downloadPageUrl),
            downloadUrl: archiveDownloadInfo.downloadUrl == null ? const Value.absent() : Value(archiveDownloadInfo.downloadUrl),
            size: Value(archiveDownloadInfo.size),
            sortOrder: Value(archiveDownloadInfo.sortOrder),
            groupName: Value(archiveDownloadInfo.group),
          ),
        ) >
        0;
  }

  Future<bool> _deleteArchiveInfoInDatabase(int gid) async {
    return await ArchiveDao.deleteArchive(gid) > 0;
  }

  // MEMORY

  void _initArchiveInMemory(ArchiveDownloadedData archive, {bool sort = true}) {
    if (!allGroups.contains(archive.groupName)) {
      allGroups.add(archive.groupName);
    }
    archives.add(archive);

    archiveDownloadInfos[archive.gid] = ArchiveDownloadInfo(
      size: archive.size,
      downloadPageUrl: archive.downloadPageUrl,
      downloadUrl: archive.downloadUrl,
      archiveStatus: ArchiveStatus.fromCode(archive.archiveStatusCode),
      cancelToken: CancelToken(),
      speedComputer: SpeedComputer(
        updateCallback: () => update(['$archiveSpeedComputerId::${archive.gid}::${archive.isOriginal}']),
      ),
      sortOrder: archive.sortOrder,
      group: archive.groupName,
    );

    if (archive.downloadUrl != null) {
      JDownloadTask downloadTask = archiveDownloadInfos[archive.gid]!.downloadTask = _generateDownloadTask(archive.downloadUrl!, archive);
      archiveDownloadInfos[archive.gid]!.speedComputer.resetDownloadedBytes(downloadTask.currentBytes);
    }

    if (sort) {
      _sortArchives();
    }
    update([galleryCountChangedId, '$archiveStatusId::${archive.gid}']);
  }

  Future<void> _deleteArchiveInMemory(int gid) async {
    archives.removeWhere((a) => a.gid == gid);
    ArchiveDownloadInfo? archiveDownloadInfo = archiveDownloadInfos.remove(gid);

    archiveDownloadInfo?.cancelToken.cancel();
    archiveDownloadInfo?.speedComputer.dispose();
    await archiveDownloadInfo?.downloadTask?.dispose();

    update([galleryCountChangedId]);
  }

  // DISK

  Future<void> _saveArchiveInfoInDisk(ArchiveDownloadedData archive) async {
    File file = File(join(computeArchiveUnpackingPath(archive.title, archive.gid), metadataFileName));
    if (!await file.exists()) {
      await file.create(recursive: true);
    }

    await file.writeAsString(jsonEncode(archive.toJson()));
  }

  Future<void> _deletePackingFileInDisk(ArchiveDownloadedData archive) async {
    File file = File(computePackingFileDownloadPath(archive));
    if (await file.exists()) {
      await file.delete();
    }
    return;
  }

  Future<void> _deleteArchiveInDisk(ArchiveDownloadedData archive) async {
    await _deletePackingFileInDisk(archive);

    Directory directory = Directory(computeArchiveUnpackingPath(archive.title, archive.gid));
    if (directory.existsSync()) {
      directory.deleteSync(recursive: true);
    }
  }

  Future<void> _ensureDownloadDirExists() async {
    try {
      await Directory(DownloadSetting.downloadPath.value).create(recursive: true);
    } on Exception catch (e) {
      Log.error('Create download directory failed', e);
    }
  }
}

class ArchiveDownloadInfo {
  /// Archive true size is different from which displayed in detail page
  int size;

  String? downloadPageUrl;

  String? downloadUrl;

  ArchiveStatus archiveStatus;

  CancelToken cancelToken;

  JDownloadTask? downloadTask;

  Completer? downloadCompleter;

  SpeedComputer speedComputer;

  int sortOrder;

  String group;

  ArchiveDownloadInfo({
    required this.size,
    this.downloadPageUrl,
    this.downloadUrl,
    required this.archiveStatus,
    required this.cancelToken,
    this.downloadTask,
    this.downloadCompleter,
    required this.speedComputer,
    required this.sortOrder,
    required this.group,
  });

  @override
  String toString() {
    return 'ArchiveDownloadInfo{size: $size, downloadPageUrl: $downloadPageUrl, downloadUrl: $downloadUrl, archiveStatus: $archiveStatus, cancelToken: $cancelToken, speedComputer: $speedComputer, sortOrder: $sortOrder, group: $group}';
  }
}

enum ArchiveStatus {
  needReUnlock(10),
  paused(20),
  unlocking(30),
  unlocked(35),
  parsingDownloadPageUrl(40),
  parsedDownloadPageUrl(45),
  parsingDownloadUrl(50),
  parsedDownloadUrl(55),
  waitingIsolate(58),
  downloading(60),
  downloaded(70),
  unpacking(80),
  completed(90),
  ;

  final int code;

  const ArchiveStatus(this.code);

  factory ArchiveStatus.fromCode(int code) {
    return ArchiveStatus.values.firstWhere((s) => s.code == code);
  }
}

enum OldArchiveStatus {
  none,
  needReUnlock,
  paused,
  unlocking,
  parsingDownloadPageUrl,
  parsingDownloadUrl,
  downloading,
  downloaded,
  unpacking,
  completed,
}
