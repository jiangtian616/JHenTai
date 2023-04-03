import 'dart:io';

import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/extension/get_logic_extension.dart';
import 'package:jhentai/src/network/eh_request.dart';
import 'package:jhentai/src/setting/super_resolution_setting.dart';
import 'package:path/path.dart';
import 'package:retry/retry.dart';

import '../model/gallery_image.dart';
import '../setting/path_setting.dart';
import '../utils/archive_util.dart';
import '../utils/log.dart';
import '../utils/toast_util.dart';
import '../widget/loading_state_indicator.dart';

class SuperResolutionService extends GetxController {
  static const String downloadId = 'downloadId';
  static const String superResolutionId = 'superResolutionId';
  
  final String modelDownloadPath = join(PathSetting.getVisibleDir().path, 'realesrgan.zip');
  final String modelSavePath = join(PathSetting.getVisibleDir().path, 'realesrgan');
  LoadingState downloadState = LoadingState.idle;
  String downloadProgress = '0 MB';

  Map<int, SuperResolutionInfo> gid2SuperResolutionInfo = {};

  static const String metadataFileName = 'super_resolution.metadata';

  Future<void> startSuperResolve() async {}

  Future<void> pauseSuperResolve() async {}

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

    downloadProgress = '0 MB';
    try {
      await retry(
        () => EHRequest.download(
          url: downloadUrl,
          path: modelDownloadPath,
          receiveTimeout: 3 * 60 * 1000,
          onReceiveProgress: (count, total) => print('$count / $total'),
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
    
    String executableFilePath = join(modelSavePath, 'realesrgan-ncnn-vulkan');
    SuperResolutionSetting.saveExecutableFilePath(executableFilePath);

    downloadState = LoadingState.success;
    updateSafely([downloadId]);
  }

  Future<void> deleteModelFile() async {
    Directory(modelSavePath).delete(recursive: true);
    SuperResolutionSetting.saveExecutableFilePath(null);
  }
}

class SuperResolutionInfo {
  List<GalleryImage?> images;

  List<SuperResolutionStatus> statuses;

  SuperResolutionInfo(this.images, this.statuses);
}

enum SuperResolutionStatus { none, failed, running, success }
