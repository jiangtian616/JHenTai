import 'dart:io';

import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/database/database.dart';
import 'package:jhentai/src/extension/get_logic_extension.dart';
import 'package:jhentai/src/network/eh_request.dart';
import 'package:jhentai/src/setting/super_resolution_setting.dart';
import 'package:jhentai/src/utils/table.dart';
import 'package:jhentai/src/widget/eh_alert_dialog.dart';
import 'package:path/path.dart';
import 'package:retry/retry.dart';

import '../model/gallery_image.dart';
import '../setting/path_setting.dart';
import '../utils/archive_util.dart';
import '../utils/eh_executor.dart';
import '../utils/log.dart';
import '../utils/toast_util.dart';
import '../widget/loading_state_indicator.dart';
import 'archive_download_service.dart';
import 'gallery_download_service.dart';

class SuperResolutionService extends GetxController {
  static const String downloadId = 'downloadId';
  static const String superResolutionId = 'superResolutionId';
  static const String superResolutionImageId = 'superResolutionImageId';

  final String modelDownloadPath = join(PathSetting.getVisibleDir().path, 'realesrgan.zip');
  final String modelSavePath = join(PathSetting.getVisibleDir().path, 'realesrgan');
  LoadingState downloadState = LoadingState.idle;
  String downloadProgress = '0%';

  EHExecutor executor = EHExecutor(concurrency: 1);

  Table<int, SuperResolutionType, SuperResolutionInfo> superResolutionInfoTable = Table();

  static const String imageDirName = 'super_resolution';

  static void init() {
    Get.put(SuperResolutionService(), permanent: true);
    Log.debug('init SuperResolutionService success', false);
  }

  @override
  void onInit() async {
    List<SuperResolutionInfoData> superResolutionInfoDatas = await _selectAllSuperResolutionInfo();
    for (SuperResolutionInfoData data in superResolutionInfoDatas) {
      superResolutionInfoTable.put(
        data.gid,
        SuperResolutionType.values[data.type],
        SuperResolutionInfo(
          SuperResolutionType.values[data.type],
          SuperResolutionStatus.values[data.status],
          data.imageStatuses.split(SuperResolutionInfo.imageStatusesSeparator).map((e) => int.parse(e)).map((index) => SuperResolutionStatus.values[index]).toList(),
        ),
      );
    }
    Future.wait(superResolutionInfoTable.entries().where((e) => e.value.status == SuperResolutionStatus.running).map((e) => executor.scheduleTask(0, () => _doSuperResolve(e.key1, e.key2))).toList());
    super.onInit();
  }

  SuperResolutionInfo? get(int gid, SuperResolutionType type) => superResolutionInfoTable.get(gid, type);

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

    downloadProgress = '0%';
    downloadState = LoadingState.loading;
    updateSafely([downloadId]);

    try {
      await retry(
        () => EHRequest.download(
          url: downloadUrl,
          path: modelDownloadPath,
          receiveTimeout: 10 * 60 * 1000,
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

  Future<bool> superResolve(int gid, SuperResolutionType type) async {
    if (type == SuperResolutionType.gallery) {
      GalleryDownloadInfo? galleryDownloadInfo = Get.find<GalleryDownloadService>().galleryDownloadInfos[gid];
      if (galleryDownloadInfo?.downloadProgress.downloadStatus != DownloadStatus.downloaded) {
        toast('requireDownloadComplete'.tr);
        return false;
      }
    } else {
      ArchiveDownloadInfo? archiveDownloadInfo = Get.find<ArchiveDownloadService>().archiveDownloadInfos[gid];
      if (archiveDownloadInfo?.archiveStatus != ArchiveStatus.completed) {
        toast('requireDownloadComplete'.tr);
        return true;
      }
    }

    SuperResolutionInfo? superResolutionInfo = get(gid, type);
    if (superResolutionInfo?.status == SuperResolutionStatus.success) {
      return true;
    }
    if (superResolutionInfo?.status == SuperResolutionStatus.running) {
      return true;
    }

    if (superResolutionInfo == null) {
      List<GalleryImage> rawImages;
      if (type == SuperResolutionType.gallery) {
        rawImages = Get.find<GalleryDownloadService>().galleryDownloadInfos[gid]!.images.cast();
      } else {
        rawImages = Get.find<ArchiveDownloadService>().getUnpackedImages(gid);
      }

      superResolutionInfo = SuperResolutionInfo(
        type,
        SuperResolutionStatus.running,
        List.generate(rawImages.length, (_) => SuperResolutionStatus.running),
      );
      superResolutionInfoTable.put(gid, type, superResolutionInfo);
      await _insertSuperResolutionInfo(gid, superResolutionInfo);
      updateSafely(['$superResolutionId::$gid']);
    }

    toast('${'startProcess'.tr}: $gid');
    executor.scheduleTask(0, () => _doSuperResolve(gid, type));
    return true;
  }

  Future<void> pauseSuperResolve(int gid, SuperResolutionType type) async {
    SuperResolutionInfo? superResolutionInfo = get(gid, type);

    if (superResolutionInfo == null || superResolutionInfo.status == SuperResolutionStatus.success || superResolutionInfo.status == SuperResolutionStatus.paused) {
      return;
    }

    Log.info('pause super resolution: $gid');
    toast('cancel'.tr);

    superResolutionInfo.currentProcess?.kill();

    superResolutionInfo.status = SuperResolutionStatus.paused;
    for (SuperResolutionStatus status in superResolutionInfo.imageStatuses) {
      if (status == SuperResolutionStatus.running) {
        status = SuperResolutionStatus.paused;
      }
    }
    await _updateSuperResolutionInfoStatus(gid, superResolutionInfo);
    updateSafely(['$superResolutionId::$gid']);
  }

  Future<void> _doSuperResolve(int gid, SuperResolutionType type) async {
    List<GalleryImage> rawImages;
    if (type == SuperResolutionType.gallery) {
      rawImages = Get.find<GalleryDownloadService>().galleryDownloadInfos[gid]!.images.cast();
    } else {
      rawImages = Get.find<ArchiveDownloadService>().getUnpackedImages(gid);
    }

    SuperResolutionInfo superResolutionInfo = get(gid, type)!;
    if (superResolutionInfo.status != SuperResolutionStatus.running) {
      superResolutionInfo.status = SuperResolutionStatus.running;
      await _updateSuperResolutionInfoStatus(gid, superResolutionInfo);
      updateSafely(['$superResolutionId::$gid']);
    }

    for (int i = 0; i < rawImages.length; i++) {
      /// cancelled
      if (get(gid, type) == null) {
        return;
      }

      if (superResolutionInfo.status == SuperResolutionStatus.paused) {
        return;
      }

      if (superResolutionInfo.imageStatuses[i] == SuperResolutionStatus.success) {
        continue;
      }

      if (SuperResolutionSetting.modelDirectoryPath.value == null) {
        return;
      }

      superResolutionInfo.imageStatuses[i] = SuperResolutionStatus.running;
      await _updateSuperResolutionInfoStatus(gid, superResolutionInfo);
      updateSafely(['$superResolutionId::$gid']);

      Process? process;
      try {
        process = await _callProcess(rawImages[i]);
      } on Exception catch (e) {
        toast('internalError'.tr + e.toString(), isShort: false);
        Log.error(e);
        Log.upload(e, extraInfos: {'rawImage': rawImages[i]});

        pauseSuperResolve(gid, type);
        return;
      } on Error catch (e) {
        toast('internalError'.tr + e.toString(), isShort: false);
        Log.error(e);
        Log.upload(e, extraInfos: {'rawImage': rawImages[i]});

        pauseSuperResolve(gid, type);
        return;
      }

      if (process == null) {
        return;
      }

      superResolutionInfo.currentProcess = process;

      process.stderr.listen((event) {
        Log.verbose(String.fromCharCodes(event).trim());
      });

      int exitCode = await process.exitCode;

      /// pause and kill the process
      if (exitCode == -1 || exitCode == -15 || exitCode == 15) {
        return;
      }

      if (exitCode != 0) {
        toast('${'internalError'.tr} exitCode:$exitCode}', isShort: false);
        Log.error('${'internalError'.tr} exitCode:$exitCode}');
        Log.upload(
          Exception('Process Error'),
          extraInfos: {'rawImage': rawImages[i], 'exitCode': exitCode},
        );

        pauseSuperResolve(gid, type);
        return;
      }

      superResolutionInfo.imageStatuses[i] = SuperResolutionStatus.success;
      Log.download('super resolve image ${rawImages[i].path} success');
      if (superResolutionInfo.imageStatuses.every((status) => status == SuperResolutionStatus.success)) {
        superResolutionInfo.status = SuperResolutionStatus.success;
        Log.info('super resolve success, gid:$gid');
      }
      await _updateSuperResolutionInfoStatus(gid, superResolutionInfo);
      updateSafely(['$superResolutionId::$gid', '$superResolutionImageId::$i']);
    }
  }

  Future<Process?> _callProcess(GalleryImage rawImage) {
    Log.download('start to super resolve image ${rawImage.path}');

    String outputPath = computeImageOutputPath(rawImage.path!);

    if (extension(rawImage.path!) == '.gif') {
      File(rawImage.path!).copySync(outputPath);
      return Future.value(null);
    }

    return Process.start(
      join(SuperResolutionSetting.modelDirectoryPath.value!, GetPlatform.isWindows ? 'realesrgan-ncnn-vulkan.exe' : 'realesrgan-ncnn-vulkan'),
      [
        '-i',
        rawImage.path!,
        '-o',
        outputPath,
        '-n',
        SuperResolutionSetting.modelType.value,
        '-f',
        'png',
        '-m',
        join(SuperResolutionSetting.modelDirectoryPath.value!, 'models'),
      ],
      workingDirectory: PathSetting.getVisibleDir().path,
      runInShell: true,
    );
  }

  String computeImageOutputPath(String rawImagePath) {
    return join(dirname(rawImagePath), imageDirName, basenameWithoutExtension(rawImagePath) + '.png');
  }

  /// db
  Future<List<SuperResolutionInfoData>> _selectAllSuperResolutionInfo() async {
    return appDb.selectAllSuperResolutionInfo().get();
  }

  Future<bool> _insertSuperResolutionInfo(int gid, SuperResolutionInfo superResolutionInfo) async {
    return await appDb.insertSuperResolutionInfo(
          gid,
          superResolutionInfo.type.index,
          superResolutionInfo.status.index,
          superResolutionInfo.imageStatuses.map((status) => status.index).join(SuperResolutionInfo.imageStatusesSeparator),
        ) >
        0;
  }

  Future<bool> _updateSuperResolutionInfoStatus(int gid, SuperResolutionInfo superResolutionInfo) async {
    return await appDb.updateSuperResolutionInfoStatus(
          superResolutionInfo.status.index,
          superResolutionInfo.imageStatuses.map((status) => status.index).join(SuperResolutionInfo.imageStatusesSeparator),
          gid,
        ) >
        0;
  }

  Future<bool> deleteSuperResolutionInfo(int gid, SuperResolutionType type) async {
    Log.info('delete super resolution: $gid');

    superResolutionInfoTable.remove(gid, type);
    updateSafely(['$superResolutionId::$gid']);
    toast('success'.tr);

    return await appDb.deleteSuperResolutionInfo(gid) > 0;
  }
}

class SuperResolutionInfo {
  Process? currentProcess;

  SuperResolutionType type;

  SuperResolutionStatus status;

  List<SuperResolutionStatus> imageStatuses;

  static const imageStatusesSeparator = ',';

  SuperResolutionInfo(this.type, this.status, this.imageStatuses);
}

enum SuperResolutionType { gallery, archive }

enum SuperResolutionStatus { paused, running, success }
