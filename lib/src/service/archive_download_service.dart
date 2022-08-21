import 'dart:convert';
import 'dart:io' as io;
import 'package:archive/archive_io.dart';
import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:image_size_getter/file_input.dart';
import 'package:image_size_getter/image_size_getter.dart';
import 'package:jhentai/src/database/database.dart';
import 'package:jhentai/src/exception/eh_exception.dart';
import 'package:jhentai/src/model/gallery_image.dart';
import 'package:jhentai/src/network/eh_request.dart';
import 'package:jhentai/src/setting/download_setting.dart';
import 'package:jhentai/src/utils/speed_computer.dart';
import 'package:jhentai/src/utils/eh_spider_parser.dart';
import 'package:path/path.dart';
import 'package:retry/retry.dart';

import '../exception/retry_exception.dart';
import '../model/gallery_archive.dart';
import '../utils/log.dart';
import '../utils/table.dart';

const String downloadArchivesId = 'downloadArchivesId';
const String archiveDownloadStatusId = 'archiveDownloadStatusId';
const String archiveDownloadSpeedComputerId = 'archiveDownloadSpeedComputerId';

class ArchiveDownloadService extends GetxController {
  static const int retryTimes = 3;
  static const int waitTimes = 6;
  static const String _metadata = '.archive.metadata';
  static const int _maxTitleLength = 100;

  List<ArchiveDownloadedData> archives = <ArchiveDownloadedData>[];
  Table<int, bool, ArchiveStatus> archiveStatuses = Table();
  Table<int, bool, CancelToken> cancelTokens = Table();
  Table<int, bool, SpeedComputer> speedComputers = Table();

  static Future<void> init() async {
    ensureDownloadDirExists();
    Get.put(ArchiveDownloadService(), permanent: true);
  }

  @override
  onInit() async {
    /// get download info from database
    List<ArchiveDownloadedData> archives = await appDb.selectArchives().get();

    for (ArchiveDownloadedData archive in archives) {
      _initArchiveDownloadInfoInMemory(archive, insertAtFirst: false);
      if (archive.archiveStatusIndex != ArchiveStatus.paused.index && archive.archiveStatusIndex != ArchiveStatus.completed.index) {
        downloadArchive(archive, isFirstDownload: false);
      }
    }

    Log.verbose('init ArchiveDownloadService success. Tasks count: ${archives.length}');
    super.onInit();
  }

  /// step 1: request to unlock archive
  /// step 2: circularly check if archive is prepared
  /// step 3: parse download url
  /// step 4: download
  Future<void> downloadArchive(ArchiveDownloadedData archive, {bool isFirstDownload = true}) async {
    if (isFirstDownload && archiveStatuses.get(archive.gid, archive.isOriginal) != null) {
      return;
    }
    Log.info('Begin to handle archive');

    ensureDownloadDirExists();

    if (isFirstDownload) {
      int success = await _saveNewArchiveDownloadInfoInDatabase(archive);
      if (success < 0) {
        return;
      }
      _initArchiveDownloadInfoInMemory(archive);
    }

    String downloadPageUrl = archive.downloadPageUrl ?? await _requestUnlock(archive) ?? await _getDownloadPageUrl(archive);

    String downloadUrl = archive.downloadUrl ?? await _getDownloadUrl(archive, downloadPageUrl);

    if (archive.archiveStatusIndex <= ArchiveStatus.downloading.index) {
      await _doDownloadArchive(archive, downloadUrl);
    }

    if (_taskHasBeenPausedOrRemoved(archive)) {
      return;
    }

    if (archive.archiveStatusIndex <= ArchiveStatus.unpacking.index) {
      _unpackingArchive(archive);
    }
  }

  Future<void> deleteAllArchive() async {
    await Future.wait(archives.map((archive) => deleteArchive(archive)).toList());
  }

  Future<void> deleteArchive(ArchiveDownloadedData archive) async {
    await pauseDownloadArchive(archive.gid, archive.isOriginal);
    await _clearArchiveDownloadInfoInDatabase(archive.gid, archive.isOriginal);
    _clearDownloadedItemsInDisk(archive);
    _clearArchiveDownloadInfoInMemory(archive.gid, archive.isOriginal);
    Log.info('delete download archive: ${archive.gid}');
  }

  Future<void> pauseAllDownloadArchive() async {
    await Future.wait(archives.map((a) => pauseDownloadArchive(a.gid, a.isOriginal)).toList());
  }

  Future<void> pauseDownloadArchive(int gid, bool isOriginal) async {
    ArchiveDownloadedData archive = archives.firstWhere((element) => element.gid == gid && element.isOriginal == isOriginal);
    if (archive.archiveStatusIndex >= ArchiveStatus.downloaded.index) {
      return;
    }

    await _updateArchive(archive.copyWith(archiveStatusIndex: ArchiveStatus.paused.index));

    cancelTokens.get(gid, isOriginal)!.cancel();
    speedComputers.get(gid, isOriginal)!.pause();
    update(['$archiveDownloadStatusId::$gid::$isOriginal']);
  }

  Future<void> resumeAllDownloadArchive() async {
    await Future.wait(archives.map((a) => resumeDownloadArchive(a.gid, a.isOriginal)).toList());
  }

  Future<void> resumeDownloadArchive(int gid, bool isOriginal) async {
    cancelTokens.put(gid, isOriginal, CancelToken());
    speedComputers.get(gid, isOriginal)!.start();

    ArchiveDownloadedData archive = archives.firstWhere((element) => element.gid == gid && element.isOriginal == isOriginal);
    if (archive.archiveStatusIndex == ArchiveStatus.paused.index) {
      return;
    }

    archive = archive.copyWith(
      archiveStatusIndex: archive.downloadPageUrl == null
          ? ArchiveStatus.waitingForDownloadPageUrl.index
          : archive.downloadUrl == null
              ? ArchiveStatus.waitingForDownloadPageUrl.index
              : ArchiveStatus.downloading.index,
    );
    _updateArchive(archive);

    update(['$archiveDownloadStatusId::${archive.gid}::${archive.isOriginal}']);
    downloadArchive(archive, isFirstDownload: false);
  }

  List<GalleryImage> getUnpackedImages(ArchiveDownloadedData archive) {
    io.Directory directory = io.Directory(_computeArchiveUnpackingPath(archive));
    List<io.FileSystemEntity> files = directory.listSync();
    files.sort((a, b) => basename(a.path).compareTo(basename(b.path)));
    files = files.where((image) => RegExp('.jpg|.png|.gif|.png').firstMatch(extension(image.path)) != null).toList();

    List<GalleryImage?> images = List.generate(files.length, (index) => null);
    files.forEachIndexed((index, file) {
      Size size;
      try {
        size = ImageSizeGetter.getSize(FileInput(file as io.File));
      } on Exception catch (e) {
        Log.error("Parse archive images failed!", e);
        Log.upload(e, extraInfos: {'file': file.path});
        return;
      }

      images[index] = GalleryImage(
        url: 'archive',
        path: file.path,
        height: size.height.toDouble(),
        width: size.width.toDouble(),
        downloadStatus: DownloadStatus.downloaded,
      );
    });

    return images.cast<GalleryImage>();
  }

  /// use meta in each gallery folder to restore download status, then sync to database.
  /// this is used after re-install app, or share download folder to another user.
  Future<int> restore() async {
    io.Directory downloadDir = io.Directory(DownloadSetting.downloadPath.value);
    if (!downloadDir.existsSync()) {
      return 0;
    }

    int restoredCount = 0;
    List<io.FileSystemEntity> galleryDirs = downloadDir.listSync();
    for (io.FileSystemEntity galleryDir in galleryDirs) {
      io.File metadataFile = io.File(join(galleryDir.path, _metadata));
      if (!metadataFile.existsSync()) {
        continue;
      }

      Map metadata = jsonDecode(metadataFile.readAsStringSync());
      ArchiveDownloadedData archive = ArchiveDownloadedData.fromJson(metadata as Map<String, dynamic>);

      /// skip if exists
      if (archiveStatuses.containsKey(archive.gid, archive.isOriginal)) {
        continue;
      }

      if (archive.archiveStatusIndex == ArchiveStatus.downloading.index) {
        archive = archive.copyWith(archiveStatusIndex: ArchiveStatus.paused.index);
      }

      int success = await _saveNewArchiveDownloadInfoInDatabase(archive);
      if (success < 0) {
        Log.error('restore download failed. Gallery: ${archive.title}');
        deleteArchive(archive);
        continue;
      }
      _initArchiveDownloadInfoInMemory(archive);

      restoredCount++;
    }

    return restoredCount;
  }

  /// If unlocked before, request will return [DownloadPageUrl] immediately.
  /// Otherwise return null.
  Future<String?> _requestUnlock(ArchiveDownloadedData archive) async {
    if (_taskHasBeenPausedOrRemoved(archive)) {
      return null;
    }

    Log.info('Begin to unlock archive: ${archive.gid}');

    String? downloadPageUrl;
    try {
      downloadPageUrl = await retry(
        () => EHRequest.requestUnlockArchive(
          url: archive.archivePageUrl.replaceFirst('--', '-'),
          gid: archive.gid,
          token: archive.token,
          or: RegExp(r'or=([\w-]+)').firstMatch(archive.archivePageUrl)!.group(1)!.replaceFirst('--', '-'),
          isOriginal: archive.isOriginal,
          cancelToken: cancelTokens.get(archive.gid, archive.isOriginal),
          parser: EHSpiderParser.unlockArchivePage2DownloadArchivePageUrl,
        ),
        retryIf: (e) => e is DioError && e.type != DioErrorType.cancel && e.error is! EHException,
        onRetry: (e) => Log.download('request unlock archive failed, retry. Reason: ${(e as DioError).message}'),
        maxAttempts: retryTimes,
      );
    } on DioError catch (e) {
      if (e.type == DioErrorType.cancel) {
        return null;
      }
      return await _requestUnlock(archive);
    }

    if (downloadPageUrl == null) {
      _updateArchive(archive.copyWith(archiveStatusIndex: ArchiveStatus.waitingForDownloadPageUrl.index));
    } else {
      Log.info('Unlock archive success: ${archive.gid}');
      _updateArchive(archive.copyWith(archiveStatusIndex: ArchiveStatus.waitingForDownloadUrl.index, downloadPageUrl: downloadPageUrl));
    }
    return downloadPageUrl;
  }

  /// Circularly check if archive is prepared
  Future<String> _getDownloadPageUrl(ArchiveDownloadedData archive) async {
    if (_taskHasBeenPausedOrRemoved(archive)) {
      return '';
    }

    Log.info('Begin to fetch archive page: ${archive.gid}');

    String downloadPageUrl;
    try {
      downloadPageUrl = await retry(
        () async {
          String? url = await _requestUnlock(archive);
          if (url != null) {
            return url;
          }
          throw RetryException();
        },
        onRetry: (e) => Log.download('Wait for download page url.'),
        maxAttempts: waitTimes,
      );
    } on RetryException catch (e) {
      return await _getDownloadPageUrl(archive);
    }

    Log.info('Fetch archive page success: ${archive.gid}');
    _updateArchive(archive.copyWith(downloadPageUrl: downloadPageUrl));
    return downloadPageUrl;
  }

  Future<String> _getDownloadUrl(ArchiveDownloadedData archive, String downloadPageUrl) async {
    if (_taskHasBeenPausedOrRemoved(archive)) {
      return '';
    }

    archive = archive.copyWith(archiveStatusIndex: ArchiveStatus.waitingForDownloadUrl.index);
    _updateArchive(archive);

    Log.info('Begin to parse archive url: ${archive.gid}');

    String downloadPath;
    try {
      downloadPath = await retry(
        () => EHRequest.request(
          url: downloadPageUrl,
          cancelToken: cancelTokens.get(archive.gid, archive.isOriginal),
          parser: EHSpiderParser.downloadArchivePage2DownloadUrl,
          useCacheIfAvailable: false,
        ),
        retryIf: (e) => e is DioError && e.type != DioErrorType.cancel,
        onRetry: (e) => Log.download('parse download url failed, retry. Reason: ${(e as DioError).message}'),
        maxAttempts: retryTimes,
      );
    } on DioError catch (e) {
      if (e.type == DioErrorType.cancel) {
        return '';
      }
      return await _getDownloadUrl(archive, downloadPageUrl);
    }

    Log.info('Parse archive url success: ${archive.gid}');
    String downloadUrl = 'https://' + Uri.parse(downloadPageUrl).host + downloadPath;
    _updateArchive(archive.copyWith(downloadUrl: downloadUrl));
    return downloadUrl;
  }

  Future<void> _doDownloadArchive(ArchiveDownloadedData archive, String downloadUrl) async {
    if (_taskHasBeenPausedOrRemoved(archive)) {
      return;
    }

    Log.download('Begin to download archive: ${archive.gid}');
    archive = archive.copyWith(archiveStatusIndex: ArchiveStatus.downloading.index);
    _updateArchive(archive);

    speedComputers.get(archive.gid, archive.isOriginal)!.start();
    try {
      await retry(
        () => EHRequest.download(
          url: downloadUrl,
          path: _computeArchiveDownloadPath(archive),
          receiveTimeout: 0,
          cancelToken: cancelTokens.get(archive.gid, archive.isOriginal),
          onReceiveProgress: (count, total) => speedComputers.get(archive.gid, archive.isOriginal)!.downloadedBytes = count,
        ),
        maxAttempts: retryTimes,
        retryIf: (e) => e is DioError && e.type != DioErrorType.cancel && (e.response == null || e.response!.statusCode != 410),
        onRetry: (e) {
          Log.download('Download archive failed, retry. Reason: ${(e as DioError).message}, url:$downloadUrl');
          speedComputers.get(archive.gid, archive.isOriginal)!.downloadedBytes = 0;
        },
      );
    } on DioError catch (e) {
      if (e.type == DioErrorType.cancel) {
        return;
      }
      if (e.response?.statusCode == 410) {
        Log.download('download archive 410, try re-parse. Archive: ${archive.gid}');
        await _reParseDownloadUrlAndDownload(archive);
      }
      await _doDownloadArchive(archive, downloadUrl);
      return;
    }

    Log.download('Download archive success: ${archive.gid}');
    speedComputers.get(archive.gid, archive.isOriginal)!.dispose();
    _updateArchive(archive.copyWith(archiveStatusIndex: ArchiveStatus.downloaded.index));
  }

  Future<void> _reParseDownloadUrlAndDownload(ArchiveDownloadedData archive) async {
    archive = archive.copyWith(downloadUrl: null);
    _updateArchive(archive);

    String downloadUrl = await _getDownloadUrl(archive, archive.downloadPageUrl!);
    await _doDownloadArchive(archive, downloadUrl);
  }

  void _unpackingArchive(ArchiveDownloadedData archive) {
    _updateArchive(archive.copyWith(archiveStatusIndex: ArchiveStatus.unpacking.index));

    InputFileStream inputStream = InputFileStream(_computeArchiveDownloadPath(archive));
    Archive unpackedDir = ZipDecoder().decodeBuffer(inputStream);
    extractArchiveToDisk(unpackedDir, _computeArchiveUnpackingPath(archive));
    inputStream.close();
    _clearDownloadedArchiveInDisk(archive);

    archive = archive.copyWith(archiveStatusIndex: ArchiveStatus.completed.index);
    _updateArchive(archive);

    if (DownloadSetting.enableStoreMetadataForRestore.isTrue) {
      _saveGalleryDownloadInfoInDisk(archive);
    }
  }

  String _computeArchiveDownloadPath(ArchiveDownloadedData archive) {
    String title = archive.title.replaceAll(RegExp(r'[/|?,:*"<>]'), ' ');
    if (title.length > _maxTitleLength) {
      title = title.substring(0, _maxTitleLength);
    }

    return join(
      DownloadSetting.downloadPath.value,
      'Archive - ${archive.gid} - $title.zip',
    );
  }

  String _computeArchiveUnpackingPath(ArchiveDownloadedData archive) {
    String title = archive.title.replaceAll(RegExp(r'[/|?,:*"<>]'), ' ');
    if (title.length > _maxTitleLength) {
      title = title.substring(0, _maxTitleLength);
    }

    return join(
      DownloadSetting.downloadPath.value,
      'Archive - ${archive.gid} - $title',
    );
  }

  /// record a new download task
  Future<int> _saveNewArchiveDownloadInfoInDatabase(ArchiveDownloadedData archive) async {
    return await appDb.insertArchive(
      archive.gid,
      archive.token,
      archive.title,
      archive.category,
      archive.pageCount,
      archive.galleryUrl,
      archive.coverUrl,
      archive.coverHeight,
      archive.coverWidth,
      archive.uploader,
      archive.size,
      archive.publishTime,
      archive.archiveStatusIndex,
      archive.archivePageUrl,
      null,
      null,
      archive.isOriginal,
      DateTime.now().toString(),
    );
  }

  /// init memory info
  void _initArchiveDownloadInfoInMemory(ArchiveDownloadedData archive, {bool insertAtFirst = true}) {
    if (insertAtFirst) {
      archives.insert(0, archive);
    } else {
      archives.add(archive);
    }
    cancelTokens.put(archive.gid, archive.isOriginal, CancelToken());
    archiveStatuses.put(archive.gid, archive.isOriginal, ArchiveStatus.values[archive.archiveStatusIndex]);
    speedComputers.put(
      archive.gid,
      archive.isOriginal,
      SpeedComputer(updateCallback: () => update(['$archiveDownloadSpeedComputerId::${archive.gid}::${archive.isOriginal}'])),
    );

    update([downloadArchivesId, '$archiveDownloadStatusId::${archive.gid}::${archive.isOriginal}']);
  }

  Future<void> _updateArchive(ArchiveDownloadedData archive) async {
    await _updateArchiveInDatabase(archive);
    _updateArchiveInMemory(archive);
    archiveStatuses.put(archive.gid, archive.isOriginal, ArchiveStatus.values[archive.archiveStatusIndex]);
  }

  Future<int> _updateArchiveInDatabase(ArchiveDownloadedData archive) {
    return appDb.updateArchive(
      archive.archiveStatusIndex,
      archive.downloadPageUrl,
      archive.downloadUrl,
      archive.gid,
      archive.isOriginal,
    );
  }

  void _updateArchiveInMemory(ArchiveDownloadedData archive) {
    int index = archives.indexWhere((element) => element.gid == archive.gid && element.isOriginal == archive.isOriginal);
    archives[index] = archive;
    update(['$archiveDownloadStatusId::${archive.gid}::${archive.isOriginal}']);
  }

  Future<int> _clearArchiveDownloadInfoInDatabase(int gid, bool isOriginal) async {
    return await appDb.deleteArchive(gid, isOriginal);
  }

  void _clearArchiveDownloadInfoInMemory(int gid, bool isOriginal) {
    archives.removeWhere((element) => element.gid == gid && element.isOriginal == isOriginal);
    cancelTokens.remove(gid, isOriginal);
    speedComputers.get(gid, isOriginal)!.dispose();
    speedComputers.remove(gid, isOriginal);
    archiveStatuses.remove(gid, isOriginal);
    update([downloadArchivesId]);
  }

  void _clearDownloadedArchiveInDisk(ArchiveDownloadedData archive) {
    io.File file = io.File(_computeArchiveDownloadPath(archive));
    if (file.existsSync()) {
      file.deleteSync();
    }
  }

  void _clearDownloadedItemsInDisk(ArchiveDownloadedData archive) {
    _clearDownloadedArchiveInDisk(archive);

    io.Directory directory = io.Directory(_computeArchiveUnpackingPath(archive));
    if (directory.existsSync()) {
      directory.deleteSync(recursive: true);
    }
  }

  bool _taskHasBeenPausedOrRemoved(ArchiveDownloadedData archive) {
    return archiveStatuses.get(archive.gid, archive.isOriginal) == null ||
        archiveStatuses.get(archive.gid, archive.isOriginal) == ArchiveStatus.paused;
  }

  void _saveGalleryDownloadInfoInDisk(ArchiveDownloadedData archive) {
    io.File file = io.File(join(_computeArchiveUnpackingPath(archive), _metadata));
    if (!file.existsSync()) {
      file.createSync(recursive: true);
    }

    file.writeAsStringSync(jsonEncode(archive.toJson()));
  }

  static void ensureDownloadDirExists() {
    io.Directory(DownloadSetting.downloadPath.value).createSync(recursive: true);
  }
}
