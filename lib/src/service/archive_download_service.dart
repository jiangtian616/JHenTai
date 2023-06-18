import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:get/get_instance/get_instance.dart';
import 'package:get/get_utils/get_utils.dart';
import 'package:get/state_manager.dart';
import 'package:intl/intl.dart';
import 'package:jhentai/src/database/database.dart';
import 'package:jhentai/src/exception/eh_exception.dart';
import 'package:jhentai/src/exception/upload_exception.dart';
import 'package:jhentai/src/network/eh_request.dart';
import 'package:jhentai/src/service/super_resolution_service.dart';
import 'package:jhentai/src/setting/download_setting.dart';
import 'package:jhentai/src/utils/speed_computer.dart';
import 'package:jhentai/src/utils/eh_spider_parser.dart';
import 'package:jhentai/src/utils/toast_util.dart';
import 'package:path/path.dart';
import 'package:retry/retry.dart';

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

  final Completer<bool> completer = Completer();

  List<String> allGroups = [];
  List<ArchiveDownloadedData> archives = <ArchiveDownloadedData>[];
  Map<int, ArchiveDownloadInfo> archiveDownloadInfos = {};

  List<ArchiveDownloadedData> archivesWithGroup(String group) => archives.where((g) => archiveDownloadInfos[g.gid]!.group == group).toList();

  static void init() {
    Get.put(ArchiveDownloadService(), permanent: true);
  }

  @override
  onInit() async {
    await _instantiateFromDB();

    Log.debug('init ArchiveDownloadService success. Tasks count: ${archives.length}');

    for (ArchiveDownloadedData archive in archives) {
      if (archive.archiveStatusIndex > ArchiveStatus.paused.index && archive.archiveStatusIndex < ArchiveStatus.completed.index) {
        downloadArchive(archive, resume: true);
      }
    }

    completer.complete(true);

    super.onInit();
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
    if (archive.archiveStatusIndex <= ArchiveStatus.downloading.index && !_taskHasBeenPausedOrRemoved(archive)) {
      await _doDownloadArchive(archive);
    }

    /// step 5: unpacking files, check status in case of a resume
    if (archive.archiveStatusIndex <= ArchiveStatus.unpacking.index && !_taskHasBeenPausedOrRemoved(archive)) {
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

    await _deleteArchiveInfoInDatabase(archive.gid, archive.isOriginal);

    await _deleteArchiveInDisk(archive);

    _deleteArchiveInMemory(archive.gid, archive.isOriginal);

    Get.find<SuperResolutionService>().deleteSuperResolutionInfo(archive.gid, SuperResolutionType.archive);

    update(['$archiveStatusId::${archive.gid}']);
  }

  Future<void> pauseAllDownloadArchive() async {
    await Future.wait(archives.map((a) => pauseDownloadArchive(a)).toList());
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
    archiveDownloadInfo.speedComputer.pause();
    if (archiveDownloadInfo.archiveStatus.index <= ArchiveStatus.paused.index ||
        archiveDownloadInfo.archiveStatus.index >= ArchiveStatus.downloaded.index) {
      return;
    }

    Log.info('Pause archive: ${archive.title}, original: ${archive.isOriginal}');

    archiveDownloadInfo.archiveStatus = needReUnlock ? ArchiveStatus.needReUnlock : ArchiveStatus.paused;
    await _updateArchiveInDatabase(archive);

    update(['$archiveStatusId::${archive.gid}']);
  }

  Future<void> resumeAllDownloadArchive() async {
    await Future.wait(archives.map((a) => resumeDownloadArchive(a)).toList());
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

  /// deal with 410
  Future<void> cancelUnlockArchiveAndDownload(ArchiveDownloadedData archive) async {
    Log.download('Re-Unlock archive: ${archive.title}, original: ${archive.isOriginal}');

    ArchiveDownloadInfo archiveDownloadInfo = archiveDownloadInfos[archive.gid]!;
    archiveDownloadInfo.archiveStatus = ArchiveStatus.unlocking;
    archiveDownloadInfo.downloadPageUrl = null;
    archiveDownloadInfo.downloadUrl = null;
    archiveDownloadInfo.cancelToken = CancelToken();
    await _updateArchiveInDatabase(archive);
    update(['$archiveStatusId::${archive.gid}']);

    try {
      await retry(
        () => EHRequest.requestCancelUnlockArchive(url: archive.archivePageUrl.replaceFirst('--', '-')),
        retryIf: (e) => e is DioError && e.type != DioErrorType.cancel,
        onRetry: (e) => Log.download('Request re-unlock archive: ${archive.title} failed, retry. Reason: ${(e as DioError).message}'),
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
        await appDb.insertArchiveGroup(newGroup);
        await appDb.updateArchiveGroupOrder(index, newGroup);
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
      return (await appDb.deleteArchiveGroup(group) > 0);
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
        try {
          await appDb.insertArchiveGroup(allGroups[i]);
        } on SqliteException catch (_) {}
        await appDb.updateArchiveGroupOrder(i, allGroups[i]);
      }
    });
  }

  /// Use meta in each archive folder to restore download tasks, then sync to database.
  /// this is used after re-install app, or share download folder to another user.
  Future<int> restoreTasks() async {
    io.Directory downloadDir = io.Directory(DownloadSetting.downloadPath.value);
    if (!downloadDir.existsSync()) {
      return 0;
    }

    int restoredCount = 0;
    for (io.FileSystemEntity galleryDir in downloadDir.listSync()) {
      io.File metadataFile = io.File(join(galleryDir.path, metadataFileName));

      /// metadata file does not exist
      if (!metadataFile.existsSync()) {
        continue;
      }

      Map metadata = jsonDecode(metadataFile.readAsStringSync());

      /// compatible with new field
      metadata.putIfAbsent('sortOrder', () => 0);

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

      _initArchiveInMemory(archive);

      restoredCount++;
    }

    return restoredCount;
  }

  List<GalleryImage> getUnpackedImages(int gid) {
    ArchiveDownloadedData archive = archives.firstWhere((a) => a.gid == gid);
    io.Directory directory = io.Directory(computeArchiveUnpackingPath(archive));

    List<io.File> imageFiles;
    try {
      imageFiles = directory.listSync().whereType<io.File>().where((image) => FileUtil.isImageExtension(image.path)).toList()
        ..sort((a, b) => basename(a.path).compareTo(basename(b.path)));
    } on Exception catch (e) {
      toast('getUnpackedImagesFailedMsg'.tr, isShort: false);
      Log.upload(e, extraInfos: {'dirs': directory.parent.listSync()});
      throw NotUploadException(e);
    }

    return imageFiles
        .map(
          (file) => GalleryImage(
            url: 'archive',
            path: file.path,
            downloadStatus: DownloadStatus.downloaded,
          ),
        )
        .toList();
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

    return join(DownloadSetting.downloadPath.value, 'Archive - ${archive.gid} - $title.zip');
  }

  String computeArchiveUnpackingPath(ArchiveDownloadedData archive) {
    String title = _computeArchiveTitle(archive.title);

    return join(DownloadSetting.downloadPath.value, 'Archive - ${archive.gid} - $title');
  }

  /// if we have downloaded parts of this archive, return downloaded bytes length, otherwise null
  int? _computeDownloadedPackingFileBytes(ArchiveDownloadedData archive) {
    String packingFilePath = computePackingFileDownloadPath(archive);
    io.File packingFile = io.File(packingFilePath);
    if (packingFile.existsSync()) {
      return packingFile.lengthSync();
    }

    return null;
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

      DateTime aTime = a.insertTime == null ? DateTime.now() : DateFormat('yyyy-MM-dd HH:mm:ss').parse(a.insertTime!);
      DateTime bTime = b.insertTime == null ? DateTime.now() : DateFormat('yyyy-MM-dd HH:mm:ss').parse(b.insertTime!);

      return bTime.difference(aTime).inMilliseconds;
    });
  }

  bool _taskHasBeenPausedOrRemoved(ArchiveDownloadedData archive) {
    return !archiveDownloadInfos.containsKey(archive.gid) || archiveDownloadInfos[archive.gid]!.archiveStatus.index <= ArchiveStatus.paused.index;
  }

  bool _invalidDownload(Response response) {
    Headers headers = response.headers;

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
        retryIf: (e) => e is DioError && e.type != DioErrorType.cancel,
        onRetry: (e) => Log.download('Request unlock archive: ${archive.title} failed, retry. Reason: ${(e as DioError).message}'),
        maxAttempts: _retryTimes,
      );
    } on DioError catch (e) {
      if (e.type == DioErrorType.cancel) {
        return;
      }

      return await _requestUnlock(archive);
    } on EHException catch (e) {
      Log.download('Download error, reason: ${e.message}');
      snack('error'.tr, e.message, longDuration: true);
      pauseAllDownloadArchive();
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
        () => EHRequest.request(
          url: archiveDownloadInfo.downloadPageUrl!,
          cancelToken: archiveDownloadInfo.cancelToken,
          parser: EHSpiderParser.downloadArchivePage2DownloadUrl,
          useCacheIfAvailable: false,
        ),
        retryIf: (e) => e is DioError && e.type != DioErrorType.cancel,
        onRetry: (e) => Log.download('Parse archive download url: ${archive.title} failed, retry. Reason: ${(e as DioError).message}'),
        maxAttempts: _retryTimes,
      );
    } on DioError catch (e) {
      if (e.type == DioErrorType.cancel) {
        return;
      }
      return await _getDownloadUrl(archive);
    } on EHException catch (e) {
      Log.download('Download error, reason: ${e.message}');
      snack('error'.tr, e.message, longDuration: true);
      pauseAllDownloadArchive();
      return;
    }

    /// sometimes the download url is invalid(the same as [downloadPageUrl]), retry
    if (!downloadPath.endsWith('start=1')) {
      Log.warning('Failed to parse download url, retry: $downloadPath');
      Log.upload(Exception('Failed to parse download url!'), extraInfos: {
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

  Future<void> _doDownloadArchive(ArchiveDownloadedData archive) async {
    Log.download('Begin to download archive: ${archive.title}, original: ${archive.isOriginal}');

    ArchiveDownloadInfo archiveDownloadInfo = archiveDownloadInfos[archive.gid]!;

    int latestDownloadedBytes = _computeDownloadedPackingFileBytes(archive) ?? 0;
    archiveDownloadInfo.downloadedBytesBeforeDownload = latestDownloadedBytes;
    SpeedComputer speedComputer = archiveDownloadInfo.speedComputer
      ..downloadedBytes = latestDownloadedBytes
      ..start();

    Log.download('${archive.title} downloaded bytes: $latestDownloadedBytes');

    Response response;
    try {
      response = await EHRequest.download(
        url: archiveDownloadInfo.downloadUrl!,
        path: computePackingFileDownloadPath(archive),
        receiveTimeout: 0,
        appendMode: true,
        caseInsensitiveHeader: false,
        deleteOnError: false,
        range: latestDownloadedBytes <= 0 ? null : '$latestDownloadedBytes-',
        cancelToken: archiveDownloadInfo.cancelToken,
        onReceiveProgress: (count, _) {
          speedComputer.downloadedBytes = latestDownloadedBytes + count;
        },
      );
    } on DioError catch (e) {
      if (e.type == DioErrorType.cancel) {
        return;
      }

      /// download too many bytes will cause 410
      if (e.response?.statusCode == 410) {
        if (e.response!.data is String && e.response!.data.contains('You have clocked too many downloaded bytes on this gallery')) {
          Log.download('${'410Hints'.tr} Archive: ${archive.title}');
          snack('error'.tr, '${'410Hints'.tr} : ${archive.title}', longDuration: true);

          return await pauseDownloadArchive(archive, needReUnlock: true);
        } else if (e.response!.data is String && e.response!.data.contains('IP quota exhausted')) {
          Log.download('IP quota exhausted! Archive: ${archive.title}');
          snack('error'.tr, 'IP quota exhausted!', longDuration: true);

          return await pauseDownloadArchive(archive, needReUnlock: true);
        } else {
          Log.download('Download archive 410, try re-parse. Archive: ${archive.title}');
          return await _reParseDownloadUrlAndDownload(archive);
        }
      }

      Log.download('Download archive ${archive.title} failed, retry. Reason: ${e.message}, url:${archiveDownloadInfo.downloadUrl!}');

      await Future.delayed(const Duration(milliseconds: 1000));
      return await _doDownloadArchive(archive);
    }

    Log.download('Download archive success: ${archive.title}, original: ${archive.isOriginal}');

    if (_invalidDownload(response)) {
      Log.error('Invalid archive!');
      Log.upload(Exception('Invalid archive!'), extraInfos: {
        'code': response.statusCode,
        'headers': response.headers,
        'body': response.data.toString(),
        'archive': archiveDownloadInfo.toString(),
      });
      await _deletePackingFileInDisk(archive);
      await Future.delayed(const Duration(milliseconds: 5000));
      return _doDownloadArchive(archive);
    }

    Log.download('${archive.title} size: ${response.headers.value('content-length')}');

    speedComputer.dispose();
    archiveDownloadInfo.archiveStatus = ArchiveStatus.downloaded;
    await _updateArchiveInDatabase(archive);
    update(['$archiveStatusId::${archive.gid}']);
  }

  Future<void> _reParseDownloadUrlAndDownload(ArchiveDownloadedData archive) async {
    ArchiveDownloadInfo archiveDownloadInfo = archiveDownloadInfos[archive.gid]!;
    archiveDownloadInfo.downloadUrl = null;
    _updateArchiveInDatabase(archive);

    await _getDownloadUrl(archive);
    await _doDownloadArchive(archive);
  }

  Future<void> _unpackingArchive(ArchiveDownloadedData archive) async {
    ArchiveDownloadInfo archiveDownloadInfo = archiveDownloadInfos[archive.gid]!;
    Log.info('Unpacking archive: ${archive.title}, original: ${archive.isOriginal}');

    bool success = await extractArchive(
      computePackingFileDownloadPath(archive),
      computeArchiveUnpackingPath(archive),
    );

    if (!success) {
      Log.error('Unpacking error!');
      Log.upload(Exception('Unpacking error!'), extraInfos: {'archive': archive});
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
    allGroups = (await appDb.selectArchiveGroups().get()).map((e) => e.groupName).toList();
    Log.debug('init Archive groups: $allGroups');

    List<ArchiveDownloadedData> archives = await appDb.selectArchives().get();

    for (ArchiveDownloadedData archive in archives) {
      _initArchiveInMemory(archive);
    }
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

    try {
      return (await appDb.insertArchiveGroup(group) > 0);
    } on SqliteException catch (e) {
      Log.debug(e);
      return false;
    }
  }

  // DB

  Future<bool> _saveArchiveAndGroupInDatabase(ArchiveDownloadedData archive) async {
    return appDb.transaction(() async {
      try {
        await appDb.insertArchiveGroup(archive.groupName ?? 'default'.tr);
      } on SqliteException catch (e) {
        Log.debug(e);
      }

      return await appDb.insertArchive(
            archive.gid,
            archive.token,
            archive.title,
            archive.category,
            archive.pageCount,
            archive.galleryUrl,
            archive.coverUrl,
            archive.uploader,
            archive.size,
            archive.publishTime,
            archive.archiveStatusIndex,
            archive.archivePageUrl,
            null,
            null,
            archive.isOriginal,
            archive.insertTime ?? DateTime.now().toString(),
            archive.groupName,
          ) >
          0;
    });
  }

  Future<bool> _updateArchiveInDatabase(ArchiveDownloadedData archive) async {
    ArchiveDownloadInfo archiveDownloadInfo = archiveDownloadInfos[archive.gid]!;

    return await appDb.updateArchive(
          archiveDownloadInfo.archiveStatus.index,
          archiveDownloadInfo.downloadPageUrl,
          archiveDownloadInfo.downloadUrl,
          archiveDownloadInfo.sortOrder,
          archiveDownloadInfo.group,
          archive.gid,
          archive.isOriginal,
        ) >
        0;
  }

  Future<bool> _deleteArchiveInfoInDatabase(int gid, bool isOriginal) async {
    return await appDb.deleteArchive(gid, isOriginal) > 0;
  }

  // MEMORY

  void _initArchiveInMemory(ArchiveDownloadedData archive) {
    if (!allGroups.contains(archive.groupName ?? 'default'.tr)) {
      allGroups.add(archive.groupName ?? 'default'.tr);
    }
    archives.add(archive);

    archiveDownloadInfos[archive.gid] = ArchiveDownloadInfo(
      downloadPageUrl: archive.downloadPageUrl,
      downloadUrl: archive.downloadUrl,
      archiveStatus: ArchiveStatus.values[archive.archiveStatusIndex],
      cancelToken: CancelToken(),
      speedComputer: SpeedComputer(
        updateCallback: () => update(['$archiveSpeedComputerId::${archive.gid}::${archive.isOriginal}']),
      )..downloadedBytes = _computeDownloadedPackingFileBytes(archive) ?? 0,
      downloadedBytesBeforeDownload: _computeDownloadedPackingFileBytes(archive) ?? 0,
      sortOrder: archive.sortOrder,
      group: archive.groupName ?? 'default'.tr,
    );

    _sortArchives();
    update([galleryCountChangedId, '$archiveStatusId::::${archive.gid}']);
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
    io.File file = io.File(join(computeArchiveUnpackingPath(archive), metadataFileName));
    if (!file.existsSync()) {
      file.createSync(recursive: true);
    }

    file.writeAsStringSync(jsonEncode(archive.toJson()));
  }

  Future<void> _deletePackingFileInDisk(ArchiveDownloadedData archive) async {
    io.File file = io.File(computePackingFileDownloadPath(archive));
    if (file.existsSync()) {
      await file.delete();
    }
    return;
  }

  Future<void> _deleteArchiveInDisk(ArchiveDownloadedData archive) async {
    await _deletePackingFileInDisk(archive);

    io.Directory directory = io.Directory(computeArchiveUnpackingPath(archive));
    if (directory.existsSync()) {
      directory.deleteSync(recursive: true);
    }
  }

  void _ensureDownloadDirExists() {
    try {
      io.Directory(DownloadSetting.downloadPath.value).createSync(recursive: true);
    } on Exception catch (e) {
      Log.error(e);
      Log.upload(e);
    }
  }
}

class ArchiveDownloadInfo {
  String? downloadPageUrl;

  String? downloadUrl;

  ArchiveStatus archiveStatus;

  CancelToken cancelToken;

  SpeedComputer speedComputer;

  int downloadedBytesBeforeDownload;

  int sortOrder;

  String group;

  ArchiveDownloadInfo({
    this.downloadPageUrl,
    this.downloadUrl,
    required this.archiveStatus,
    required this.cancelToken,
    required this.speedComputer,
    required this.downloadedBytesBeforeDownload,
    required this.sortOrder,
    required this.group,
  });

  @override
  String toString() {
    return 'ArchiveDownloadInfo{downloadPageUrl: $downloadPageUrl, downloadUrl: $downloadUrl, archiveStatus: $archiveStatus, cancelToken: $cancelToken, speedComputer: $speedComputer, downloadedBytesBeforeDownload: $downloadedBytesBeforeDownload, group: $group}';
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
