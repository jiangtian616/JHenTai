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
import 'package:jhentai/src/setting/path_setting.dart';
import 'package:jhentai/src/utils/speed_computer.dart';
import 'package:jhentai/src/utils/eh_spider_parser.dart';
import 'package:path/path.dart';
import 'package:retry/retry.dart';

import '../database/dao/archive_dao.dart';
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

  final Completer<bool> _completer = Completer();

  Future<bool> get completed => _completer.future;

  List<String> allGroups = [];
  List<ArchiveDownloadedData> archives = <ArchiveDownloadedData>[];
  Map<int, ArchiveDownloadInfo> archiveDownloadInfos = {};

  static const int isolateCount = 4;

  List<ArchiveDownloadedData> archivesWithGroup(String group) => archives.where((g) => archiveDownloadInfos[g.gid]!.group == group).toList();

  static void init() {
    Get.put(ArchiveDownloadService(), permanent: true);
  }

  @override
  Future<void> onInit() async {
    await _instantiateFromDB();

    Log.debug('init ArchiveDownloadService success. Tasks count: ${archives.length}');

    for (ArchiveDownloadedData archive in archives) {
      if (archive.archiveStatusIndex > ArchiveStatus.paused.index && archive.archiveStatusIndex < ArchiveStatus.completed.index) {
        downloadArchive(archive, resume: true);
      }
    }

    _completer.complete(true);

    if (DownloadSetting.restoreTasksAutomatically.isTrue) {
      await restoreTasks();
    }

    super.onInit();
  }

  bool containArchive(int gid) {
    return archiveDownloadInfos.containsKey(gid);
  }

  Future<void> downloadArchive(ArchiveDownloadedData archive, {bool resume = false}) async {
    if (!resume && archiveDownloadInfos.containsKey(archive.gid)) {
      return;
    }

    _ensureDownloadDirExists();

    Log.info('Begin to handle archive: ${archive.title}, original: ${archive.isOriginal}');

    if (!resume && !await _initArchiveInfo(archive)) {
      return;
    }

    ArchiveDownloadInfo archiveDownloadInfo = archiveDownloadInfos[archive.gid]!;

    /// step 1: request to unlock archive: if we have unlocked before or unlock has completed,
    /// we can get [downloadPageUrl] immediately, otherwise we must wait for a second
    if (archiveDownloadInfo.downloadPageUrl == null && !_taskHasBeenPausedOrRemoved(archive)) {
      await _requestUnlock(archive);
    }

    /// step 2: circularly check if unlock has completed so that we can get [downloadPageUrl]
    if (archiveDownloadInfo.downloadPageUrl == null && !_taskHasBeenPausedOrRemoved(archive)) {
      await _getDownloadPageUrl(archive);
    }

    /// step 3: parse download url
    if (archiveDownloadInfo.downloadUrl == null && !_taskHasBeenPausedOrRemoved(archive)) {
      await _getDownloadUrl(archive);
    }

    /// step 4: do download, check status in case of a resume
    if (archiveDownloadInfo.archiveStatus.index <= ArchiveStatus.downloading.index && !_taskHasBeenPausedOrRemoved(archive)) {
      await _doDownloadArchiveViaMultiIsolate(archive);
    }

    /// step 5: unpacking files
    if (archiveDownloadInfos[archive.gid]!.archiveStatus.index <= ArchiveStatus.unpacking.index && !_taskHasBeenPausedOrRemoved(archive)) {
      await _unpackingArchive(archive);
    }

    _saveArchiveInfoInDisk(archive);
  }

  Future<void> deleteArchiveByGid(int gid) async {
    ArchiveDownloadedData? archive = archives.firstWhereOrNull((archive) => archive.gid == gid);
    if (archive != null) {
      return deleteArchive(archive);
    }
  }

  Future<void> deleteArchive(ArchiveDownloadedData archive) async {
    Log.info('Delete archive: ${archive.title}, original: ${archive.isOriginal}');

    await pauseDownloadArchive(archive);

    await Get.find<SuperResolutionService>().deleteSuperResolve(archive.gid, SuperResolutionType.archive);

    await _deleteArchiveInfoInDatabase(archive.gid, archive.isOriginal);

    await _deleteArchiveInDisk(archive);

    _deleteArchiveInMemory(archive.gid, archive.isOriginal);

    update(['$archiveStatusId::${archive.gid}']);
  }

  Future<void> pauseAllDownloadArchive() async {
    await Future.wait(archives.map(pauseDownloadArchive).toList());
  }

  Future<void> pauseDownloadArchiveByGid(int gid) async {
    ArchiveDownloadedData? archive = archives.firstWhereOrNull((archive) => archive.gid == gid);
    if (archive != null) {
      return pauseDownloadArchive(archive);
    }
  }

  Future<void> pauseDownloadArchive(ArchiveDownloadedData archive, {bool needReUnlock = false}) async {
    ArchiveDownloadInfo archiveDownloadInfo = archiveDownloadInfos[archive.gid]!;

    archiveDownloadInfo.cancelToken.cancel();
    await archiveDownloadInfo.downloadTask?.pause();
    archiveDownloadInfo.speedComputer.pause();
    if (archiveDownloadInfo.archiveStatus.index <= ArchiveStatus.paused.index || archiveDownloadInfo.archiveStatus.index >= ArchiveStatus.downloaded.index) {
      return;
    }

    Log.info('Pause archive: ${archive.title}, original: ${archive.isOriginal}');

    archiveDownloadInfo.archiveStatus = needReUnlock ? ArchiveStatus.needReUnlock : ArchiveStatus.paused;
    await _updateArchiveInDatabase(archive);

    update(['$archiveStatusId::${archive.gid}']);
  }

  Future<void> resumeAllDownloadArchive() async {
    await Future.wait(archives.map(resumeDownloadArchive).toList());
  }

  Future<void> resumeDownloadArchiveByGid(int gid) async {
    ArchiveDownloadedData? archive = archives.firstWhereOrNull((archive) => archive.gid == gid);
    if (archive != null) {
      return resumeDownloadArchive(archive);
    }
  }

  Future<void> resumeDownloadArchive(ArchiveDownloadedData archive) async {
    ArchiveDownloadInfo archiveDownloadInfo = archiveDownloadInfos[archive.gid]!;

    if (archiveDownloadInfo.archiveStatus.index == ArchiveStatus.completed.index) {
      return;
    }

    Log.info('Resume archive: ${archive.title}, original: ${archive.isOriginal}');

    archiveDownloadInfo.cancelToken = CancelToken();

    archiveDownloadInfo.archiveStatus = ArchiveStatus.downloading;
    await _updateArchiveInDatabase(archive);

    update(['$archiveStatusId::${archive.gid}']);

    downloadArchive(archive, resume: true);
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
    );
    List<GalleryImage> images = await getUnpackedImages(gid);

    if (images.length != archive.pageCount) {
      Log.error('Unpacked images count not equal to page count: ${images.length} != ${archive.pageCount}');
      return;
    }

    return Get.find<GalleryDownloadService>().importGallery(galleryDownloadedData, images);
  }

  /// deal with 410
  Future<void> cancelUnlockArchiveAndDownload(ArchiveDownloadedData archive) async {
    Log.download('Re-Unlock archive: ${archive.title}, original: ${archive.isOriginal}');

    ArchiveDownloadInfo archiveDownloadInfo = archiveDownloadInfos[archive.gid]!;
    archiveDownloadInfo.archiveStatus = ArchiveStatus.unlocking;
    archiveDownloadInfo.downloadPageUrl = null;
    archiveDownloadInfo.downloadUrl = null;
    archiveDownloadInfo.cancelToken = CancelToken();
    archiveDownloadInfo.downloadTask?.pause();
    archiveDownloadInfo.downloadTask = null;
    await _updateArchiveInDatabase(archive);
    update(['$archiveStatusId::${archive.gid}']);

    try {
      await retry(
        () => EHRequest.requestCancelUnlockArchive(url: archive.archivePageUrl.replaceFirst('--', '-')),
        retryIf: (e) => e is DioException && e.type != DioExceptionType.cancel,
        onRetry: (e) => Log.download('Request re-unlock archive: ${archive.title} failed, retry. Reason: ${(e as DioException).message}'),
        maxAttempts: _retryTimes,
      );
    } on Exception catch (e) {
      Log.download('Re-Unlock archive error, reason: ${e.toString()}');
      return;
    }

    downloadArchive(archive, resume: true);
  }

  Future<bool> updateArchiveGroupByGid(int gid, String group) async {
    ArchiveDownloadedData? archive = archives.firstWhereOrNull((archive) => archive.gid == gid);
    if (archive != null) {
      return updateArchiveGroup(archive, group);
    }
    return false;
  }

  Future<bool> updateArchiveGroup(ArchiveDownloadedData archive, String group) async {
    archiveDownloadInfos[archive.gid]?.group = group;

    if (!allGroups.contains(group) && !await _addGroup(group)) {
      return false;
    }
    _sortArchives();

    return _updateArchiveInDatabase(archive);
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
        await _updateArchiveInDatabase(a);
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

  Future<void> updateArchiveOrder(List<ArchiveDownloadedData> archives) async {
    await appDb.transaction(() async {
      for (ArchiveDownloadedData archive in archives) {
        await _updateArchiveInDatabase(archive);
      }
    });

    _sortArchives();
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

  /// Use meta in each archive folder to restore download tasks, then sync to database.
  /// this is used after re-install app, or share download folder to another user.
  Future<int> restoreTasks() async {
    await completed;

    Directory downloadDir = Directory(DownloadSetting.downloadPath.value);
    if (!downloadDir.existsSync()) {
      return 0;
    }

    int restoredCount = 0;
    for (FileSystemEntity galleryDir in downloadDir.listSync()) {
      File metadataFile = File(join(galleryDir.path, metadataFileName));

      /// metadata file does not exist
      if (!metadataFile.existsSync()) {
        continue;
      }

      Map metadata = jsonDecode(metadataFile.readAsStringSync());

      /// compatible with new field
      metadata.putIfAbsent('sortOrder', () => 0);
      if (metadata['groupName'] == null) {
        metadata['groupName'] = 'default'.tr;
      }

      ArchiveDownloadedData archive = ArchiveDownloadedData.fromJson(metadata as Map<String, dynamic>);

      /// skip if exists
      if (archiveDownloadInfos.containsKey(archive.gid)) {
        continue;
      }

      archive = archive.copyWith(archiveStatusIndex: ArchiveStatus.completed.index);

      if (!await _saveArchiveAndGroupInDatabase(archive)) {
        Log.error('Restore archive failed: $archive');
        deleteArchive(archive);
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
    Directory directory = Directory(computeArchiveUnpackingPath(archive));

    return directory.list().toList().then((files) {
      List<File> imageFiles = files.whereType<File>().where((file) => FileUtil.isImageExtension(file.path)).toList();
      imageFiles.sort(FileUtil.compareComicImagesOrderSimple);
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

    return join(DownloadSetting.downloadPath.value, 'Archive - v2 - ${archive.gid} - $title.zip');
  }

  String computeArchiveUnpackingPath(ArchiveDownloadedData archive) {
    String title = _computeArchiveTitle(archive.title);

    return join(DownloadSetting.downloadPath.value, 'Archive - ${archive.gid} - $title');
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
      isolateCount: isolateCount,
      deleteWhenUrlMismatch: false,
      onProgress: (current, total) {
        archiveDownloadInfos[archive.gid]!.speedComputer.downloadedBytes = current;
      },
      onDone: () async {
        archiveDownloadInfos[archive.gid]!.downloadCompleter!.complete();
      },
      onError: (String? message) async {
        Log.download('Download archive failed: ${archive.title}, original: ${archive.isOriginal}, reason: $message');
        snack('archiveError'.tr, message ?? '', longDuration: true);

        await pauseDownloadArchive(archive);
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

      if (e.response!.data is String && e.response!.data.contains('You have clocked too many downloaded bytes on this gallery')) {
        Log.download('${'410Hints'.tr} Archive: ${archive.title}');
        snack('archiveError'.tr, '${'410Hints'.tr} : ${archive.title}', longDuration: true);

        return await pauseDownloadArchive(archive, needReUnlock: true);
      } else if (e.response!.data is String && e.response!.data.contains('IP quota exhausted')) {
        Log.download('IP quota exhausted! Archive: ${archive.title}');
        snack('archiveError'.tr, 'IP quota exhausted!', longDuration: true);

        return await pauseDownloadArchive(archive, needReUnlock: true);
      } else if (e.response!.data is String && e.response!.data.contains('Expired or invalid session')) {
        Log.download('Expired or invalid session! Archive: ${archive.title}');
        snack('archiveError'.tr, 'Expired or invalid session!', longDuration: true);

        return await pauseDownloadArchive(archive);
      } else {
        Log.download('Download archive 410, try re-parse. Archive: ${archive.title}');
        return await _reParseDownloadUrlAndDownload(archive);
      }
    }
  }

  Future<void> _reParseDownloadUrlAndDownload(ArchiveDownloadedData archive) async {
    ArchiveDownloadInfo archiveDownloadInfo = archiveDownloadInfos[archive.gid]!;
    archiveDownloadInfo.downloadUrl = null;
    _updateArchiveInDatabase(archive);

    await _getDownloadUrl(archive);
    await _doDownloadArchiveViaMultiIsolate(archive);
  }

  bool _invalidDownload(Headers headers) {
    if (headers['content-transfer-encoding']?.contains('binary') ?? false) {
      return false;
    }
    if (headers['accept-ranges']?.contains('bytes') ?? false) {
      return false;
    }
    if (headers['content-type']?.contains('application/zip') ?? false) {
      return false;
    }

    return true;
  }

  bool _taskHasBeenPausedOrRemoved(ArchiveDownloadedData archive) {
    return !archiveDownloadInfos.containsKey(archive.gid) || archiveDownloadInfos[archive.gid]!.archiveStatus.index <= ArchiveStatus.paused.index;
  }

  // TASKS

  Future<void> _requestUnlock(ArchiveDownloadedData archive) async {
    Log.download('Begin to unlock archive: ${archive.title}, original: ${archive.isOriginal}');

    ArchiveDownloadInfo archiveDownloadInfo = archiveDownloadInfos[archive.gid]!;

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

      return await _requestUnlock(archive);
    } on EHSiteException catch (e) {
      Log.download('Download error, reason: ${e.message}');
      snack('archiveError'.tr, e.message, longDuration: true);
      if (e.shouldPauseAllDownloadTasks) {
        pauseAllDownloadArchive();
      }
      return;
    }

    if (downloadPageUrl == null) {
      archiveDownloadInfo.archiveStatus = ArchiveStatus.parsingDownloadPageUrl;
    } else {
      Log.download('Get archive download page url success: ${archive.title}');
      archiveDownloadInfo.archiveStatus = ArchiveStatus.parsingDownloadUrl;
      archiveDownloadInfo.downloadPageUrl = downloadPageUrl;
    }

    await _updateArchiveInDatabase(archive);
    update(['$archiveStatusId::${archive.gid}']);
  }

  Future<void> _getDownloadPageUrl(ArchiveDownloadedData archive) async {
    Log.download('Begin to circularly fetch archive download page url: ${archive.title}, original: ${archive.isOriginal}');

    ArchiveDownloadInfo archiveDownloadInfo = archiveDownloadInfos[archive.gid]!;

    while (archiveDownloadInfo.downloadPageUrl == null && !_taskHasBeenPausedOrRemoved(archive)) {
      await _requestUnlock(archive);

      if (archiveDownloadInfo.downloadPageUrl == null) {
        await Future.delayed(const Duration(milliseconds: 1000));
      }
    }
  }

  Future<void> _getDownloadUrl(ArchiveDownloadedData archive) async {
    ArchiveDownloadInfo archiveDownloadInfo = archiveDownloadInfos[archive.gid]!;

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
        pauseAllDownloadArchive();
      }
      return;
    }

    /// sometimes the download url is invalid(the same as [downloadPageUrl]), retry
    if (!downloadPath.endsWith('start=1')) {
      Log.warning('Failed to parse download url, retry: $downloadPath');
      Log.uploadError(Exception('Failed to parse download url!'), extraInfos: {
        'downloadPath': downloadPath,
        'archive': archiveDownloadInfo.toString(),
      });
      return _getDownloadUrl(archive);
    }

    Log.download('Parse archive download url success: ${archive.title}, original: ${archive.isOriginal}');

    archiveDownloadInfo.archiveStatus = ArchiveStatus.downloading;
    archiveDownloadInfo.downloadUrl = 'https://' + Uri.parse(archiveDownloadInfo.downloadPageUrl!).host + downloadPath;
    Log.verbose('Archive download url: ${archiveDownloadInfo.downloadUrl}');

    await _updateArchiveInDatabase(archive);
    update(['$archiveStatusId::${archive.gid}']);
  }

  Future<void> _doDownloadArchiveViaMultiIsolate(ArchiveDownloadedData archive) async {
    Log.download('Begin to download archive: ${archive.title}, original: ${archive.isOriginal}');

    ArchiveDownloadInfo archiveDownloadInfo = archiveDownloadInfos[archive.gid]!;
    archiveDownloadInfo.speedComputer.start();

    /// multi-isolate download task
    JDownloadTask task = archiveDownloadInfo.downloadTask ??= _generateDownloadTask(archiveDownloadInfo.downloadUrl!, archive);
    archiveDownloadInfo.speedComputer.resetDownloadedBytes(task.currentBytes);
    Log.download('${archive.title} downloaded bytes: ${task.currentBytes}');

    archiveDownloadInfo.downloadCompleter = Completer();
    if (task.status == TaskStatus.completed) {
      archiveDownloadInfo.downloadCompleter!.complete();
    } else {
      /// check if archive link is invalid
      Response response;
      try {
        response = await EHRequest.head(
          url: archiveDownloadInfo.downloadUrl!,
          cancelToken: archiveDownloadInfo.cancelToken,
        );
      } on DioException catch (e) {
        if (e.type == DioExceptionType.cancel) {
          return;
        }

        /// download too many bytes will cause 410
        if (e.response?.statusCode == 410) {
          return await _check410Reason(archiveDownloadInfo.downloadUrl!, archive);
        }

        await Future.delayed(const Duration(milliseconds: 1000));
        return _doDownloadArchiveViaMultiIsolate(archive);
      }

      if (_invalidDownload(response.headers)) {
        Log.error('Invalid archive!');
        await _deletePackingFileInDisk(archive);
        await Future.delayed(const Duration(milliseconds: 5000));
        return _doDownloadArchiveViaMultiIsolate(archive);
      }

      Log.download('${archive.title} size: ${response.headers.value('content-length')}');

      try {
        await task.start();
      } on Exception catch (e) {
        Log.download('Download archive ${archive.title} failed, retry. Reason: $e');
        snack('archiveError'.tr, 'internalError'.tr, longDuration: true);

        return await pauseDownloadArchive(archive);
      }
    }

    await archiveDownloadInfo.downloadCompleter!.future;

    Log.download('Download archive success: ${archive.title}, original: ${archive.isOriginal}');
    archiveDownloadInfo.speedComputer.dispose();
    archiveDownloadInfo.archiveStatus = ArchiveStatus.downloaded;
    await _updateArchiveInDatabase(archive);
    update(['$archiveStatusId::${archive.gid}']);
  }

  Future<void> _unpackingArchive(ArchiveDownloadedData archive) async {
    ArchiveDownloadInfo archiveDownloadInfo = archiveDownloadInfos[archive.gid]!;
    Log.info('Unpacking archive: ${archive.title}, original: ${archive.isOriginal}');

    bool success = await extractZipArchive(
      computePackingFileDownloadPath(archive),
      computeArchiveUnpackingPath(archive),
    );

    if (!success) {
      Log.error('Unpacking error!');
      Log.uploadError(Exception('Unpacking error!'), extraInfos: {'archive': archive});
      snack('error'.tr, '${'failedToDealWith'.tr}:${archive.title}', longDuration: true);
      archiveDownloadInfo.archiveStatus = ArchiveStatus.downloading;
      await _deletePackingFileInDisk(archive);
      return pauseDownloadArchive(archive);
    }

    if (DownloadSetting.deleteArchiveFileAfterDownload.isTrue) {
      _deletePackingFileInDisk(archive);
    }

    archiveDownloadInfo.archiveStatus = ArchiveStatus.completed;
    await _updateArchiveInDatabase(archive);

    update(['$archiveStatusId::${archive.gid}']);
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
            ArchiveDownloadedData(
              gid: archive.gid,
              token: archive.token,
              title: archive.title,
              category: archive.category,
              pageCount: archive.pageCount,
              galleryUrl: archive.galleryUrl,
              coverUrl: archive.coverUrl,
              uploader: archive.uploader,
              size: archive.size,
              publishTime: archive.publishTime,
              archiveStatusIndex: archive.archiveStatusIndex,
              archivePageUrl: archive.archivePageUrl,
              downloadPageUrl: null,
              downloadUrl: null,
              sortOrder: archive.sortOrder,
              groupName: archive.groupName,
              isOriginal: archive.isOriginal,
              insertTime: archive.insertTime,
            ),
          ) >
          0;
    });
  }

  Future<bool> _updateArchiveInDatabase(ArchiveDownloadedData archive) async {
    ArchiveDownloadInfo archiveDownloadInfo = archiveDownloadInfos[archive.gid]!;

    return await ArchiveDao.updateArchive(
          ArchiveDownloadedCompanion(
            gid: Value(archive.gid),
            archiveStatusIndex: Value(archiveDownloadInfo.archiveStatus.index),
            downloadPageUrl: archiveDownloadInfo.downloadPageUrl == null ? const Value.absent() : Value(archiveDownloadInfo.downloadPageUrl),
            downloadUrl: archiveDownloadInfo.downloadUrl == null ? const Value.absent() : Value(archiveDownloadInfo.downloadUrl),
            sortOrder: Value(archiveDownloadInfo.sortOrder),
            groupName: Value(archiveDownloadInfo.group),
          ),
        ) >
        0;
  }

  Future<bool> _deleteArchiveInfoInDatabase(int gid, bool isOriginal) async {
    return await ArchiveDao.deleteArchive(gid) > 0;
  }

  // MEMORY

  void _initArchiveInMemory(ArchiveDownloadedData archive, {bool sort = true}) {
    if (!allGroups.contains(archive.groupName)) {
      allGroups.add(archive.groupName);
    }
    archives.add(archive);

    archiveDownloadInfos[archive.gid] = ArchiveDownloadInfo(
      downloadPageUrl: archive.downloadPageUrl,
      downloadUrl: archive.downloadUrl,
      archiveStatus: ArchiveStatus.values[archive.archiveStatusIndex],
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

  void _deleteArchiveInMemory(int gid, bool isOriginal) {
    archives.removeWhere((a) => a.gid == gid && a.isOriginal == isOriginal);
    ArchiveDownloadInfo? archiveDownloadInfo = archiveDownloadInfos.remove(gid);

    archiveDownloadInfo?.cancelToken.cancel();
    archiveDownloadInfo?.speedComputer.dispose();

    update([galleryCountChangedId]);
  }

  // DISK

  void _saveArchiveInfoInDisk(ArchiveDownloadedData archive) {
    File file = File(join(computeArchiveUnpackingPath(archive), metadataFileName));
    if (!file.existsSync()) {
      file.createSync(recursive: true);
    }

    file.writeAsStringSync(jsonEncode(archive.toJson()));
  }

  Future<void> _deletePackingFileInDisk(ArchiveDownloadedData archive) async {
    File file = File(computePackingFileDownloadPath(archive));
    if (file.existsSync()) {
      await file.delete();
    }
    return;
  }

  Future<void> _deleteArchiveInDisk(ArchiveDownloadedData archive) async {
    await _deletePackingFileInDisk(archive);

    Directory directory = Directory(computeArchiveUnpackingPath(archive));
    if (directory.existsSync()) {
      directory.deleteSync(recursive: true);
    }
  }

  void _ensureDownloadDirExists() {
    try {
      Directory(DownloadSetting.downloadPath.value).createSync(recursive: true);
    } on Exception catch (e) {
      Log.error(e);
      Log.uploadError(e);
    }
  }
}

class ArchiveDownloadInfo {
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
    return 'ArchiveDownloadInfo{downloadPageUrl: $downloadPageUrl, downloadUrl: $downloadUrl, archiveStatus: $archiveStatus, cancelToken: $cancelToken, speedComputer: $speedComputer, sortOrder: $sortOrder, group: $group}';
  }
}

enum ArchiveStatus {
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
