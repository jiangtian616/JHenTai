import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/extension/get_logic_extension.dart';
import 'package:jhentai/src/network/eh_request.dart';
import 'package:jhentai/src/setting/super_resolution_setting.dart';
import 'package:jhentai/src/widget/eh_alert_dialog.dart';
import 'package:path/path.dart';
import 'package:retry/retry.dart';

import '../database/database.dart';
import '../model/gallery_image.dart';
import '../setting/path_setting.dart';
import '../utils/archive_util.dart';
import '../utils/log.dart';
import '../utils/string_uril.dart';
import '../utils/toast_util.dart';
import '../widget/loading_state_indicator.dart';
import 'archive_download_service.dart';
import 'gallery_download_service.dart';

class SuperResolutionService extends GetxController {
  static const String downloadId = 'downloadId';
  static const String superResolutionId = 'superResolutionId';

  final String modelDownloadPath = join(PathSetting.getVisibleDir().path, 'realesrgan.zip');
  final String modelSavePath = join(PathSetting.getVisibleDir().path, 'realesrgan');
  LoadingState downloadState = LoadingState.idle;
  String downloadProgress = '';

  Map<int, SuperResolutionInfo> gid2SuperResolutionInfo = {};

  final GalleryDownloadService galleryDownloadService = Get.find();
  final ArchiveDownloadService archiveDownloadService = Get.find();

  static const String imageDirName = 'super_resolution';
  static const String metadataFileName = 'super_resolution.metadata';

  static void init() {
    Get.put(SuperResolutionService());
    Log.debug('init SuperResolutionService success', false);
  }

  @override
  void onInit() async {
    resumeAllSuperResolve();
    super.onInit();
  }

  Future<void> startSuperResolveGallery(GalleryDownloadedData gallery) async {
    GalleryDownloadInfo? galleryDownloadInfo = galleryDownloadService.galleryDownloadInfos[gallery.gid];
    if (galleryDownloadInfo?.downloadProgress.downloadStatus != DownloadStatus.downloaded) {
      toast('requireDownloadComplete'.tr);
      return;
    }

    SuperResolutionInfo? superResolutionInfo = gid2SuperResolutionInfo[gallery.gid];
    if (superResolutionInfo?.status == SuperResolutionStatus.success) {
      toast('operationHasCompleted'.tr);
      return;
    }
    if (superResolutionInfo?.status == SuperResolutionStatus.running || superResolutionInfo?.status == SuperResolutionStatus.success) {
      toast('operationInProgress'.tr);
      return;
    }

    gid2SuperResolutionInfo[gallery.gid] ??= SuperResolutionInfo(galleryDownloadInfo!.images.cast<GalleryImage>());

    return _doSuperResolve(gallery.gid);
  }

  Future<void> startSuperResolveArchive(ArchiveDownloadedData archive) async {
    ArchiveDownloadInfo? archiveDownloadInfo = archiveDownloadService.archiveDownloadInfos[archive.gid];
    if (archiveDownloadInfo?.archiveStatus != ArchiveStatus.completed) {
      toast('requireDownloadComplete'.tr);
      return;
    }

    SuperResolutionInfo? superResolutionInfo = gid2SuperResolutionInfo[archive.gid];
    if (superResolutionInfo?.status == SuperResolutionStatus.running || superResolutionInfo?.status == SuperResolutionStatus.success) {
      toast('operationInProgress'.tr);
      return;
    }

    if (superResolutionInfo?.status == SuperResolutionStatus.paused) {
      return resumeSuperResolve(archive.gid);
    }

    gid2SuperResolutionInfo[archive.gid] ??= SuperResolutionInfo(archiveDownloadService.getUnpackedImages(archive));

    return _doSuperResolve(archive.gid);
  }

  Future<void> resumeAllSuperResolve() {
    return Future.wait(gid2SuperResolutionInfo.keys.map((gid) => resumeSuperResolve(gid)));
  }

  Future<void> resumeSuperResolve(int gid) {
    SuperResolutionInfo? superResolutionInfo = gid2SuperResolutionInfo[gid];

    if (superResolutionInfo == null || superResolutionInfo.status == SuperResolutionStatus.success || superResolutionInfo.status == SuperResolutionStatus.running) {
      return Future.value();
    }

    return _doSuperResolve(gid);
  }

  Future<void> pauseAllSuperResolve() {
    return Future.wait(gid2SuperResolutionInfo.keys.map((gid) => pauseSuperResolve(gid)));
  }

  Future<void> pauseSuperResolve(int gid) async {
    SuperResolutionInfo? superResolutionInfo = gid2SuperResolutionInfo[gid];

    if (superResolutionInfo == null || superResolutionInfo.status == SuperResolutionStatus.success || superResolutionInfo.status == SuperResolutionStatus.paused) {
      return;
    }

    superResolutionInfo.status = SuperResolutionStatus.paused;
    for (SuperResolutionStatus status in superResolutionInfo.imageStatuses) {
      if (status == SuperResolutionStatus.running) {
        superResolutionInfo.status = SuperResolutionStatus.paused;
        _saveSuperResolutionInfoInDisk(superResolutionInfo);
      }
    }

    updateSafely(['$superResolutionId::$gid']);
  }

  Future<void> cancelSuperResolve(int gid) async {
    SuperResolutionInfo? superResolutionInfo = gid2SuperResolutionInfo[gid];

    if (superResolutionInfo == null || superResolutionInfo.status == SuperResolutionStatus.success) {
      return;
    }

    gid2SuperResolutionInfo.remove(gid);
  }

  Future<void> downloadModelFile() async {
    String downloadUrl;

    if (GetPlatform.isWindows) {
      downloadUrl = 'https://github.com/xinntao/Real-ESRGAN/releases/download/v0.2.5.0/realesrgan-ncnn-vulkan-20220424-windows.zip';
    } else if (GetPlatform.isMacOS) {
      downloadUrl = 'https://github.com/xinntao/Real-ESRGAN/releases/download/v0.2.5.0/realesrgan-ncnn-vulkan-20220424-macos.zip';
    } else if (GetPlatform.isLinux) {
      downloadUrl = 'https://github.com/xinntao/Real-ESRGAN/releases/download/v0.2.5.0/realesrgan-ncnn-vulkan-20220424-ubuntu.zip';
    } else {
      toast('error'.tr);
      return;
    }

    downloadProgress = '';
    downloadState = LoadingState.loading;
    updateSafely([downloadId]);

    try {
      await retry(
        () => EHRequest.download(
          url: downloadUrl,
          path: modelDownloadPath,
          receiveTimeout: 3 * 60 * 1000,
          onReceiveProgress: (count, total) {
            downloadProgress = (count / total * 100).toStringAsFixed(2) + '%';
            updateSafely([downloadId]);
          },
        ),
        maxAttempts: 5,
        onRetry: (error) => Log.warning('Download super-resolution model failed, retry.'),
      );
    } on DioError catch (e) {
      Log.error('Download super-resolution model failed after 5 times', e.message);
      downloadState = LoadingState.error;
      updateSafely([downloadId]);
      return;
    }

    Log.info('Super-resolution model downloaded');

    bool success = await extractArchive(modelDownloadPath, modelSavePath);

    if (!success) {
      Log.error('Unpacking Super-resolution model error!');
      Log.upload(Exception('Unpacking Super-resolution model error!'));
      toast('internalError'.tr);
      downloadState = LoadingState.error;
      updateSafely([downloadId]);
      return;
    }

    File(modelDownloadPath).delete();

    SuperResolutionSetting.saveModelDirectoryPath(modelSavePath);

    downloadState = LoadingState.success;
    updateSafely([downloadId]);
  }

  Future<void> deleteModelFile() async {
    bool? result = await Get.dialog(EHAlertDialog(title: 'delete'.tr + '?'));
    if (result == true) {
      downloadState = LoadingState.idle;
      Directory(modelSavePath).delete(recursive: true);
      SuperResolutionSetting.saveModelDirectoryPath(null);
    }
  }

  Future<void> _doSuperResolve(int gid) async {
    toast('${'startProcess'.tr}: $gid');

    SuperResolutionInfo superResolutionInfo = gid2SuperResolutionInfo[gid]!;

    superResolutionInfo.status = SuperResolutionStatus.running;
    _saveSuperResolutionInfoInDisk(superResolutionInfo);
    updateSafely(['$superResolutionId::$gid']);

    for (int i = 0; i < superResolutionInfo.rawImages.length; i++) {
      /// cancelled
      if (gid2SuperResolutionInfo[gid] == null) {
        return;
      }

      if (superResolutionInfo.status == SuperResolutionStatus.paused) {
        return;
      }

      if (superResolutionInfo.imageStatuses[i] == SuperResolutionStatus.success && superResolutionInfo.images[i] != null) {
        continue;
      }

      GalleryImage rawImage = superResolutionInfo.rawImages[i];
      GalleryImage image = GalleryImage(url: rawImage.url, path: join(dirname(rawImage.path!), imageDirName, basename(rawImage.path!)));
      superResolutionInfo.images[i] = image;

      if (SuperResolutionSetting.modelDirectoryPath.value == null) {
        return;
      }

      superResolutionInfo.imageStatuses[i] = SuperResolutionStatus.running;
      _saveSuperResolutionInfoInDisk(superResolutionInfo);
      updateSafely(['$superResolutionId::$gid']);

      await _callProcess(rawImage, image).catchError((e) {
        toast('internalError'.tr + e.toString(), isShort: false);
        pauseSuperResolve(gid);

        Log.error(e);
        Log.upload(e, extraInfos: {'rawImage': rawImage, 'image': image});
      }).then((result) {
        if (result is! ProcessResult) {
          return;
        }

        if (result.exitCode != 0) {
          toast('${'internalError'.tr} exitCode:${result.exitCode} stderr:${result.stderr.toString().trim()}', isShort: false);
          pauseSuperResolve(gid);

          Log.error('${'internalError'.tr} exitCode:${result.exitCode} stderr:${result.stderr.toString().trim()}');
          Log.upload(
            Exception('Process Error'),
            extraInfos: {
              'rawImage': rawImage,
              'image': image,
              'exitCode': result.exitCode,
              'stderr': result.stderr,
            },
          );
          return;
        }

        if (!isEmptyOrNull(result.stdout)) {
          Log.download(result.stdout);
        }

        superResolutionInfo.imageStatuses[i] = SuperResolutionStatus.success;
        if (superResolutionInfo.imageStatuses.every((status) => status == SuperResolutionStatus.success)) {
          superResolutionInfo.status = SuperResolutionStatus.success;
          Log.info('super resolve success, gid:$gid');
        }
        _saveSuperResolutionInfoInDisk(superResolutionInfo);
        updateSafely(['$superResolutionId::$gid']);
      });
    }
  }

  Future _callProcess(GalleryImage rawImage, GalleryImage image) {
    Log.download('start to super resolve image ${rawImage.path}');

    if (extension(rawImage.path!) == '.gif') {
      return File(rawImage.path!).copy(image.path!);
    }

    return Process.run(
      join(SuperResolutionSetting.modelDirectoryPath.value!, GetPlatform.isWindows ? 'realesrgan-ncnn-vulkan.exe' : 'realesrgan-ncnn-vulkan'),
      [
        '-i',
        rawImage.path!,
        '-o',
        image.path!,
        '-n',
        'realesrgan-x4plus-anime',
        '-f',
        extension(rawImage.path!) == '.png' ? 'png' : 'jpg',
        '-m',
        join(SuperResolutionSetting.modelDirectoryPath.value!, 'models'),
      ],
      workingDirectory: PathSetting.getVisibleDir().path,
      runInShell: true,
    );
  }

  /// db

  /// disk
  void _saveSuperResolutionInfoInDisk(SuperResolutionInfo superResolutionInfo) {
    File file = File(join(dirname(superResolutionInfo.rawImages[0].path!), metadataFileName));
    if (!file.existsSync()) {
      file.createSync(recursive: true);
    }

    file.writeAsStringSync(jsonEncode(superResolutionInfo.toJson()));
  }
}

class SuperResolutionInfo {
  List<GalleryImage> rawImages;

  List<GalleryImage?> images;

  SuperResolutionStatus status;

  List<SuperResolutionStatus> imageStatuses;

  SuperResolutionInfo(this.rawImages)
      : images = List.generate(rawImages.length, (_) => null),
        status = SuperResolutionStatus.none,
        imageStatuses = List.generate(rawImages.length, (_) => SuperResolutionStatus.none);

  SuperResolutionInfo._({required this.rawImages, required this.images, required this.status, required this.imageStatuses});

  Map<String, dynamic> toJson() {
    return {
      "rawImages": jsonEncode(rawImages),
      "images": jsonEncode(images),
      "status": status.index,
      "imageStatuses": imageStatuses.map((status) => status.index).toList(),
    };
  }

  factory SuperResolutionInfo.fromJson(Map<String, dynamic> json) {
    return SuperResolutionInfo._(
      rawImages: jsonDecode(json['rawImages']),
      images: jsonDecode(json['images']),
      status: SuperResolutionStatus.values[json["status"]],
      imageStatuses: (jsonDecode(json["imageStatuses"]) as List).map((index) => SuperResolutionStatus.values[index]).toList(),
    );
  }
}

enum SuperResolutionStatus { none, failed, paused, running, success }
